#!/usr/bin/env bash
#
# moodle-update.sh
# Checks for and installs updates in a Moodle container made by install-moodle-proxmox.sh:
# Ubuntu packages (Apache, PHP and MariaDB patches), Composer, Moodle itself, and reports add-on plugin updates.
#
# Run inside the container as root (the installer adds an "update" command that fetches the newest copy of this script):
#   update            check, show what is new, ask, then update
#   update --check    only show what is new
#
# Minor Moodle updates (5.3.0 -> 5.3.1) are part of the normal update. A new major Moodle version (5.3 -> 5.4)
# or a newer PHP is only installed after a separate yes. Before Moodle changes, the database and the Moodle
# code are backed up to /var/backups/moodle (the newest 3 are kept); if the Moodle upgrade fails, both are put back.

set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:$PATH"   # Composer lives in /usr/local/bin; pct exec gives a short PATH

MOODLE_DIR="/var/www/moodle"
BACKUP_DIR="/var/backups/moodle"
KEEP_BACKUPS=3
WORK="/tmp/moodle-update"
PHP_EXTENSIONS="curl gd intl mbstring mysql xml zip soap bcmath ldap opcache"
LOG="/var/log/moodle-update-$(date +%Y%m%d-%H%M%S).log"
GN=$'\e[1;92m' RD=$'\e[01;31m' YW=$'\e[33m' BL=$'\e[36m' CL=$'\e[m'
CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

msg_info()  { printf ' %s⏳%s %s...' "$YW" "$CL" "$1"; }
msg_ok()    { printf '\r\e[K %s✔%s %s\n' "$GN" "$CL" "$1"; }
msg_warn()  { printf '\r\e[K %s!%s %s\n' "$YW" "$CL" "$1"; }
msg_error() { printf '\r\e[K %s✖%s %s\n' "$RD" "$CL" "$1"; }

# Runs a step with its output in the log; on failure shows the end of the log and returns 1.
# The step runs in a subshell with errexit on (bash ignores errexit inside an "if"), so its first failing command stops it.
step() {
  local msg="$1" rc
  shift
  msg_info "$msg"
  set +e
  (
    set -e
    "$@"
  ) >>"$LOG" 2>&1
  rc=$?
  set -e
  if ((rc == 0)); then
    msg_ok "$msg"
  else
    msg_error "$msg"
    echo
    tail -n 25 "$LOG"
    echo
    echo "Full log: $LOG"
    return 1
  fi
}

ask() {
  if command -v whiptail >/dev/null && [[ -t 0 ]]; then
    whiptail --backtitle "Moodle updates" --title "$1" --yesno "\n$2" 18 76
  else
    local answer
    printf '%b\n' "$2"
    read -rp "[y/N] " answer
    [[ "$answer" =~ ^[Yy] ]]
  fi
}

newer() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }   # decimal Moodle versions like 2026100500.02
version_of_branch() { printf '%d.%d' "${1:0:${#1}-2}" "$((10#${1: -2}))"; }   # 503 -> 5.3
branch_of_version() { printf '%d%02d' "${1%%.*}" "${1#*.}"; }                  # 5.3 -> 503

moodle_php() { runuser -u www-data -- php "$@"; }

# Moodle's version and its add-on plugins, from Moodle itself
moodle_info() {
  moodle_php -r '
    define("CLI_SCRIPT", true);
    require("'"$MOODLE_DIR"'/config.php");
    echo "core\t{$CFG->version}\t{$CFG->release}\t{$CFG->branch}\n";
    echo "db\t{$CFG->dbname}\n";
    try { \core\update\checker::instance()->fetch(); } catch (Throwable $e) { }
    foreach (core_plugin_manager::instance()->get_plugins() as $plugins) {
      foreach ($plugins as $p) {
        if ($p->is_standard()) { continue; }
        $updates = $p->available_updates() ?: [];
        $newest = end($updates);
        echo "plugin\t{$p->component}\t{$p->rootdir}\t", $newest ? $newest->release : "-", "\n";
      }
    }'
}

# The newest PHP in Moodle's release notes for a version ("minimum PHP 8.3.0. PHP 8.4.x is supported too.")
php_range() {
  curl -fsSL --max-time 15 "https://raw.githubusercontent.com/moodle/devdocs/main/general/releases/$1.md" 2>/dev/null |
    awk '/^- PHP version:/ && !done {print; done = 1}' | grep -oE 'PHP 8\.[0-9]+' | awk '{print $2}' | sort -V | sed -n '1p;$p' | paste -sd' ' || true
}

# The minimum MariaDB in Moodle's environment.xml for a version
mariadb_min() {
  local branch path
  branch="$(branch_of_version "$1")"
  for path in public/admin admin; do
    curl -fsSL --max-time 20 "https://raw.githubusercontent.com/moodle/moodle/MOODLE_${branch}_STABLE/$path/environment.xml" 2>/dev/null |
      awk -v ver="$1" '$0 ~ "<MOODLE version=\"" ver "\"" {f = 1} f && /<\/MOODLE>/ {f = 0} f' |
      grep -oE 'VENDOR name="mariadb" version="[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$' && return 0
  done
  return 0
}

# ---------------------------------------------------------------- checks
if [[ $EUID -ne 0 ]]; then
  echo "Run this as root inside the Moodle container." >&2
  exit 1
fi
if [[ ! -f "$MOODLE_DIR/config.php" ]]; then
  echo "No Moodle found in $MOODLE_DIR." >&2
  exit 1
fi
exec 9>/run/moodle-update.lock
flock -n 9 || { echo "An update is already running." >&2; exit 1; }

clear 2>/dev/null || true
echo "${BL}Moodle updates${CL}  (details go to $LOG)"
echo

msg_info "Reading the installed Moodle"
INFO="$(moodle_info 2>>"$LOG")" || { msg_error "Could not read Moodle's version (see $LOG)"; exit 1; }
CORE_RELEASE="$(grep -P '^core\t' <<<"$INFO" | cut -f3)"
CORE_BRANCH="$(grep -P '^core\t' <<<"$INFO" | cut -f4)"
CORE_VERSION="$(grep -P '^core\t' <<<"$INFO" | cut -f2)"
DB_NAME="$(grep -P '^db\t' <<<"$INFO" | cut -f2)"
mapfile -t PLUGINS < <(grep -P '^plugin\t' <<<"$INFO" | cut -f2-)
CORE_SERIES="$(version_of_branch "$CORE_BRANCH")"
msg_ok "Installed: Moodle $CORE_RELEASE, ${#PLUGINS[@]} add-on plugin(s)"

# Newer build of the installed version (5.3.0 -> 5.3.1, or a newer weekly 5.3+ build)
msg_info "Checking for a newer Moodle $CORE_SERIES build"
MINOR_VERSION="" MINOR_RELEASE=""
for path in public/version.php version.php; do
  src="$(curl -fsSL --max-time 20 "https://raw.githubusercontent.com/moodle/moodle/MOODLE_${CORE_BRANCH}_STABLE/$path" 2>/dev/null || true)"
  [[ -n "$src" ]] || continue
  MINOR_VERSION="$(grep -oP '^\$version\s*=\s*\K[0-9.]+' <<<"$src" || true)"
  MINOR_RELEASE="$(grep -oP "^\\\$release\s*=\s*'\K[^']+" <<<"$src" || true)"
  break
done
if [[ -n "$MINOR_VERSION" ]] && newer "$MINOR_VERSION" "$CORE_VERSION"; then
  msg_ok "Moodle $MINOR_RELEASE is available"
else
  [[ -n "$MINOR_VERSION" ]] && msg_ok "Moodle $CORE_SERIES is up to date" || msg_warn "Could not check Moodle's GitHub for $CORE_SERIES updates"
  MINOR_VERSION=""
fi

# Newer major version: the newest release tag whose download package exists
msg_info "Checking for a new major Moodle version"
MAJOR_SERIES=""
while read -r v; do
  series="${v%.*}"
  b="$(branch_of_version "$series")"
  ((10#$b > 10#$CORE_BRANCH)) || break
  if curl -fsI --max-time 15 "https://packaging.moodle.org/stable$b/moodle-$series.tgz" >/dev/null 2>&1; then
    MAJOR_SERIES="$series"
    MAJOR_RELEASE="$v"
    break
  fi
done < <(curl -fsSL --max-time 20 https://api.github.com/repos/moodle/moodle/git/matching-refs/tags/v 2>/dev/null |
  grep -oE '"refs/tags/v[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' |
  sort -rV | awk -F. '!seen[$1 "." $2]++' | head -n 3 || true)
if [[ -n "$MAJOR_SERIES" ]]; then
  msg_ok "Moodle $MAJOR_RELEASE is available (a major upgrade)"
else
  msg_ok "No newer major Moodle version"
fi

# PHP: newest version the installed (or, for a major upgrade, the new) Moodle supports
PHP_NOW="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
msg_info "Checking PHP $PHP_NOW against Moodle $CORE_SERIES"
read -r _ PHP_MAX < <(php_range "$CORE_SERIES"; echo) || true
PHP_UPGRADE=""
if [[ -n "${PHP_MAX:-}" ]] && [[ "$(printf '%s\n' "$PHP_NOW" "$PHP_MAX" | sort -V | tail -1)" != "$PHP_NOW" ]]; then
  PHP_UPGRADE="$PHP_MAX"
  msg_ok "PHP $PHP_MAX is supported by Moodle $CORE_SERIES (installed: $PHP_NOW)"
else
  msg_ok "PHP $PHP_NOW is the newest Moodle $CORE_SERIES supports"
fi

msg_info "Checking Ubuntu packages"
apt-get update -q >>"$LOG" 2>&1 || true
mapfile -t APT_UPGRADES < <(apt list --upgradable 2>/dev/null | tail -n +2 | cut -d/ -f1)
KEY_UPGRADES="$(printf '%s\n' "${APT_UPGRADES[@]}" | grep -E '^(php|libapache2-mod-php|apache2$|mariadb-server$)' | paste -sd' ' || true)"
msg_ok "${#APT_UPGRADES[@]} Ubuntu package update(s)${KEY_UPGRADES:+, including $KEY_UPGRADES}"

COMPOSER_NOW="$(composer --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
COMPOSER_LATEST="$(curl -fsSL --max-time 15 https://getcomposer.org/versions 2>/dev/null | tr -d ' \n' | grep -oP '"stable":\[\{[^}]*"version":"\K[0-9.]+' || true)"
COMPOSER_APT=0
# readlink: on merged-/usr systems "command -v" says /bin/composer, which dpkg only knows as /usr/bin/composer
dpkg -S "$(readlink -f "$(command -v composer 2>/dev/null || echo /nonexistent)")" >/dev/null 2>&1 && COMPOSER_APT=1
COMPOSER_UPDATE=0
if [[ -z "$COMPOSER_NOW" || "$COMPOSER_APT" == 1 ]] || { [[ -n "$COMPOSER_LATEST" ]] && [[ "$COMPOSER_NOW" != "$COMPOSER_LATEST" ]]; }; then
  COMPOSER_UPDATE=1
  msg_ok "Composer ${COMPOSER_NOW:-missing} -> ${COMPOSER_LATEST:-latest}$([[ "$COMPOSER_APT" == 1 ]] && echo " (replacing Ubuntu's old package)")"
else
  msg_ok "Composer $COMPOSER_NOW is up to date"
fi

PLUGIN_UPDATES=()
for p in "${PLUGINS[@]}"; do
  IFS=$'\t' read -r component _ release <<<"$p"
  [[ "$release" != "-" ]] && PLUGIN_UPDATES+=("$component -> $release")
done
if ((${#PLUGIN_UPDATES[@]})); then
  msg_warn "Add-on plugin updates: ${PLUGIN_UPDATES[*]}"
  echo "     Install them in Moodle: Site administration > Plugins > Plugins overview > Updates available."
else
  msg_ok "Add-on plugins are up to date"
fi

echo
if [[ -z "$MINOR_VERSION$MAJOR_SERIES$PHP_UPGRADE" ]] && ((${#APT_UPGRADES[@]} == 0 && COMPOSER_UPDATE == 0)); then
  echo "${GN}Everything is up to date.${CL}"
  exit 0
fi
if ((CHECK_ONLY)); then
  echo "Run update (without --check) to install these."
  exit 0
fi

# ---------------------------------------------------------------- questions
SUMMARY=""
((${#APT_UPGRADES[@]})) && SUMMARY+="- ${#APT_UPGRADES[@]} Ubuntu package update(s)\n"
((COMPOSER_UPDATE)) && SUMMARY+="- Composer ${COMPOSER_LATEST:-latest}\n"
[[ -n "$MINOR_VERSION" ]] && SUMMARY+="- Moodle $MINOR_RELEASE (site in maintenance mode for a few minutes)\n"
DO_BASE=0
if [[ -n "$SUMMARY" ]]; then
  ask "INSTALL UPDATES" "Install these updates?\n\n${SUMMARY}\nThe database and Moodle code are backed up first." && DO_BASE=1
fi
DO_MAJOR=0
if [[ -n "$MAJOR_SERIES" ]]; then
  ask "MAJOR UPGRADE" "Upgrade Moodle $CORE_SERIES to $MAJOR_RELEASE?\n\nA major upgrade can break add-on plugins and themes that do not support $MAJOR_SERIES yet:\n$(printf '  %s\n' "${PLUGINS[@]%%$'\t'*}")\nCheck them on moodle.org/plugins first. The database and code are backed up, and put back if the upgrade fails." && DO_MAJOR=1
fi
DO_PHP=0
if [[ -n "$PHP_UPGRADE" && "$DO_MAJOR" == 0 ]]; then
  ask "PHP UPGRADE" "Switch PHP $PHP_NOW to PHP $PHP_UPGRADE?\n\nMoodle $CORE_SERIES supports it. If Moodle's checks fail afterwards, PHP $PHP_NOW is switched back." && DO_PHP=1
fi
if ((DO_BASE + DO_MAJOR + DO_PHP == 0)); then
  echo "Nothing installed."
  exit 0
fi
clear 2>/dev/null || true
echo "${BL}Installing updates${CL}  (details go to $LOG)"
echo

# ---------------------------------------------------------------- update steps
apt_upgrade() {
  DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
  DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
}

composer_update() {
  if ((COMPOSER_APT)); then
    DEBIAN_FRONTEND=noninteractive apt-get -y purge composer
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
  fi
  if [[ -x /usr/local/bin/composer ]]; then
    COMPOSER_ALLOW_SUPERUSER=1 /usr/local/bin/composer self-update --no-interaction
  else
    cd /tmp
    curl -fsSL https://getcomposer.org/installer -o composer-setup.php
    [[ "$(curl -fsSL https://composer.github.io/installer.sig)" == "$(php -r 'echo hash_file("sha384", "composer-setup.php");')" ]] || { echo "Composer installer signature mismatch"; return 1; }
    php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
  fi
}

# Moodle's status checks: exit 0 OK, 1 warnings only (e.g. cron paused during maintenance), 2 errors.
moodle_checks() {
  local rc=0
  (cd "$MOODLE_DIR" && moodle_php admin/cli/checks.php) | sed 's/\x1b\[[0-9;]*m//g' || rc=${PIPESTATUS[0]}
  ((rc < 2))
}

# Installs PHP $1 next to the current one, moves Apache and the command line to it, removes the old one if Moodle is happy.
switch_php() {
  local new="$1" old="$PHP_NOW" ext pkgs ini
  if ! apt-cache show "php$new-cli" >/dev/null 2>&1; then
    add-apt-repository -y ppa:ondrej/php
    apt-get update
  fi
  pkgs=("php$new" "php$new-cli" "php$new-common" "libapache2-mod-php$new")
  for ext in $PHP_EXTENSIONS; do
    if apt-cache show "php$new-$ext" >/dev/null 2>&1; then pkgs+=("php$new-$ext"); fi
  done
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  for ini in "/etc/php/$new/apache2/php.ini" "/etc/php/$new/cli/php.ini"; do
    [[ -f "$ini" ]] || continue
    sed -i 's/^;*memory_limit.*/memory_limit = 256M/; s/^;*upload_max_filesize.*/upload_max_filesize = 128M/; s/^;*post_max_size.*/post_max_size = 128M/; s/^;*max_execution_time.*/max_execution_time = 300/' "$ini"
    if grep -q '^;*max_input_vars' "$ini"; then sed -i 's/^;*max_input_vars.*/max_input_vars = 5000/' "$ini"; else echo "max_input_vars = 5000" >>"$ini"; fi
  done
  a2dismod "php$old"
  a2enmod "php$new"
  update-alternatives --set php "/usr/bin/php$new"
  systemctl restart apache2
  if ! moodle_checks; then
    echo "Moodle's checks failed on PHP $new, switching back to PHP $old."
    a2dismod "php$new"
    a2enmod "php$old"
    update-alternatives --set php "/usr/bin/php$old"
    systemctl restart apache2
    return 1
  fi
  DEBIAN_FRONTEND=noninteractive apt-get -y purge "php$old*" "libapache2-mod-php$old"
  DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
}

switch_mariadb() {
  curl -fsSL https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-$1"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold install mariadb-server mariadb-client
  mariadb-upgrade
}

backup() {
  BACKUP="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)-$CORE_BRANCH"
  mkdir -p "$BACKUP"
  chmod 700 "$BACKUP_DIR"
  mariadb-dump --single-transaction --routines --triggers --databases "$DB_NAME" | gzip >"$BACKUP/database.sql.gz"
  tar -czf "$BACKUP/moodle-code.tgz" -C "$(dirname "$MOODLE_DIR")" "$(basename "$MOODLE_DIR")"
  echo "$CORE_RELEASE" >"$BACKUP/release.txt"
  # Keep the newest $KEEP_BACKUPS
  ls -1dt "$BACKUP_DIR"/*/ | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -rf
}

# Puts the previous code and database back after a failed upgrade
rollback() {
  echo "Upgrade failed: restoring Moodle $CORE_RELEASE from $BACKUP"
  if [[ -d "$MOODLE_DIR.old" ]]; then
    rm -rf "$MOODLE_DIR"
    mv "$MOODLE_DIR.old" "$MOODLE_DIR"
  fi
  mariadb -e "DROP DATABASE IF EXISTS \`$DB_NAME\`"
  gunzip -c "$BACKUP/database.sql.gz" | mariadb
  (cd "$MOODLE_DIR" && moodle_php admin/cli/purge_caches.php && moodle_php admin/cli/maintenance.php --disable) || true
}

# Replaces the Moodle code with the newest build of branch $1 (keeping config.php and add-on plugins) and upgrades the database.
upgrade_moodle() {
  local branch="$1" series new_version p component dir rel
  series="$(version_of_branch "$branch")"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  # moodle-latest-503.tgz is the newest weekly build (5.3+), the download moodle.org offers; moodle-5.3.tgz stays at 5.3.0
  wget -q -O "$WORK/moodle.tgz" "https://packaging.moodle.org/stable$branch/moodle-latest-$branch.tgz"
  tar -xzf "$WORK/moodle.tgz" -C "$WORK"
  new_version="$(cat "$WORK"/moodle/public/version.php "$WORK"/moodle/version.php 2>/dev/null | grep -oP '^\$version\s*=\s*\K[0-9.]+' | head -1 || true)"
  if [[ -z "$new_version" ]] || ! newer "$new_version" "$CORE_VERSION"; then
    echo "The download package is not newer than the installed Moodle yet ($new_version), nothing to do."
    rm -rf "$WORK"
    return 0
  fi

  cp -p "$MOODLE_DIR/config.php" "$WORK/moodle/config.php"
  for p in "${PLUGINS[@]}"; do
    IFS=$'\t' read -r component dir _ <<<"$p"
    rel="${dir#"$MOODLE_DIR"/}"
    if [[ -e "$WORK/moodle/$rel" ]]; then
      echo "$component is part of the new Moodle, not copying it"
    else
      mkdir -p "$(dirname "$WORK/moodle/$rel")"
      cp -a "$dir" "$WORK/moodle/$rel"
      echo "Kept add-on $component ($rel)"
    fi
  done
  mkdir -p "$WORK/composer-home"
  chown -R www-data:www-data "$WORK/moodle" "$WORK/composer-home"
  (cd "$WORK/moodle" && runuser -u www-data -- env HOME="$WORK/composer-home" COMPOSER_HOME="$WORK/composer-home" \
    composer install --no-dev --classmap-authoritative --no-interaction --no-progress)

  (cd "$MOODLE_DIR" && moodle_php admin/cli/maintenance.php --enable)
  backup
  rm -rf "$MOODLE_DIR.old"
  mv "$MOODLE_DIR" "$MOODLE_DIR.old"
  mv "$WORK/moodle" "$MOODLE_DIR"
  if ! (cd "$MOODLE_DIR" && moodle_php admin/cli/upgrade.php --non-interactive); then
    rollback
    return 1
  fi
  (cd "$MOODLE_DIR" && moodle_php admin/cli/purge_caches.php && moodle_php admin/cli/maintenance.php --disable)
  rm -rf "$MOODLE_DIR.old" "$WORK"
  echo "Backup of the previous version: $BACKUP"
}

FAILED=0
if ((DO_BASE)); then
  ((${#APT_UPGRADES[@]})) && { step "Updating Ubuntu packages" apt_upgrade || FAILED=1; }
  ((COMPOSER_UPDATE)) && { step "Updating Composer" composer_update || FAILED=1; }
fi
if ((DO_PHP)); then
  step "Switching to PHP $PHP_UPGRADE" switch_php "$PHP_UPGRADE" || FAILED=1
fi
PHP_NOW="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"   # steps run in subshells
if ((DO_MAJOR)); then
  # The new version's requirements first: its newest PHP, and MariaDB at least its minimum
  read -r _ NEW_PHP_MAX < <(php_range "$MAJOR_SERIES"; echo) || true
  NEW_MARIADB_MIN="$(mariadb_min "$MAJOR_SERIES")"
  MARIADB_NOW="$(mariadb --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-MariaDB' | grep -oE '^[0-9]+\.[0-9]+')"
  if [[ -n "${NEW_PHP_MAX:-}" && "$NEW_PHP_MAX" != "$PHP_NOW" ]] && [[ "$(printf '%s\n' "$PHP_NOW" "$NEW_PHP_MAX" | sort -V | tail -1)" == "$NEW_PHP_MAX" ]]; then
    step "Switching to PHP $NEW_PHP_MAX for Moodle $MAJOR_SERIES" switch_php "$NEW_PHP_MAX" || FAILED=1
  fi
  if ((FAILED == 0)) && [[ -n "$NEW_MARIADB_MIN" ]] && [[ "$(printf '%s\n' "$MARIADB_NOW" "$NEW_MARIADB_MIN" | sort -V | head -1)" != "$NEW_MARIADB_MIN" ]]; then
    step "Upgrading MariaDB $MARIADB_NOW to $NEW_MARIADB_MIN for Moodle $MAJOR_SERIES" switch_mariadb "$NEW_MARIADB_MIN" || FAILED=1
  fi
  if ((FAILED == 0)); then
    step "Upgrading Moodle to $MAJOR_RELEASE (maintenance mode, a few minutes)" upgrade_moodle "$(branch_of_version "$MAJOR_SERIES")" || FAILED=1
  else
    msg_warn "Moodle $MAJOR_RELEASE was not installed because an earlier step failed"
  fi
elif ((DO_BASE)) && [[ -n "$MINOR_VERSION" ]]; then
  step "Updating Moodle to $MINOR_RELEASE (maintenance mode, a few minutes)" upgrade_moodle "$CORE_BRANCH" || FAILED=1
fi

echo
if step "Running Moodle's checks" moodle_checks; then
  :
else
  FAILED=1
fi
echo
if ((FAILED)); then
  echo "${RD}Some updates failed.${CL} Details: $LOG"
  exit 1
fi
echo "${GN}Updates installed.${CL} Moodle: $(moodle_info 2>/dev/null | grep -P '^core\t' | cut -f3), PHP $(php -r 'echo PHP_VERSION;')"
[[ -f /var/run/reboot-required ]] && echo "Ubuntu asks for a restart of the container: from the Proxmox host run pct reboot <id>."
exit 0
