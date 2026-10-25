#!/usr/bin/env bash
#
# install-moodle-proxmox.sh
# Installs the latest Moodle release into a new Proxmox LXC container (Ubuntu 24.04),
# with menus in the style of the Proxmox VE community scripts.
#
# Run as root on a Proxmox VE host with internet access:
#   bash install-moodle-proxmox.sh
#
# "Default settings" asks only for the site details (admin email, optional public address);
# "Advanced settings" also lets you choose the container ID, size, storage, network and root password.
# The Moodle version is the newest release on Moodle's GitHub; PHP is the newest version that
# release supports (from Moodle's release notes) and MariaDB its minimum (from Moodle's environment.xml).

set -euo pipefail

# ======================== DEFAULTS ========================
# Used when Moodle's GitHub or release notes cannot be read
MOODLE_FALLBACK="5.3"
PHP_FALLBACK="8.4"
MARIADB_FALLBACK="11.4"
HOSTNAME="moodle"
CORES=2
MEMORY=4096
SWAP=512
DISK_GB=20
BRIDGE="vmbr0"
SITE_FULLNAME="My Moodle Site"
SITE_SHORTNAME="Moodle"

DB_NAME="moodle"
DB_USER="moodleuser"
DB_PASS="$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 12 | tr -d '/+=' | head -c 12)"
# ==========================================================

BACKTITLE="Moodle installer for Proxmox VE"
LOG="/var/log/moodle-install-$(date +%Y%m%d-%H%M%S).log"
GN=$'\e[1;92m' RD=$'\e[01;31m' YW=$'\e[33m' BL=$'\e[36m' CL=$'\e[m'

msg_info()  { printf ' %s⏳%s %s...' "$YW" "$CL" "$1"; }
msg_ok()    { printf '\r\e[K %s✔%s %s\n' "$GN" "$CL" "$1"; }
msg_error() { printf '\r\e[K %s✖%s %s\n' "$RD" "$CL" "$1"; }

# Runs a step with its output in the log; on failure shows the end of the log and stops.
step() {
  local msg="$1"
  shift
  msg_info "$msg"
  if "$@" >>"$LOG" 2>&1; then
    msg_ok "$msg"
  else
    msg_error "$msg"
    echo
    tail -n 25 "$LOG"
    echo
    echo "Full log: $LOG"
    if [[ -n "${CTID:-}" ]] && pct status "$CTID" &>/dev/null; then
      echo "The half-built container is $CTID; remove it with: pct stop $CTID; pct destroy $CTID"
    fi
    exit 1
  fi
}

# Runs the script on stdin inside the container.
ct() { pct exec "$CTID" -- env DEBIAN_FRONTEND=noninteractive PHP_V="$PHP_V" bash -euo pipefail -s; }

exit_script() {
  clear
  echo "Cancelled, nothing was changed."
  exit 0
}

input()    { whiptail --backtitle "$BACKTITLE" --title "$1" --inputbox "\n$2" 12 76 "$3" 3>&1 1>&2 2>&3 || exit_script; }
password() { whiptail --backtitle "$BACKTITLE" --title "$1" --passwordbox "\n$2" 10 76 3>&1 1>&2 2>&3 || exit_script; }
oops()     { whiptail --backtitle "$BACKTITLE" --title "Check this" --msgbox "\n$1" 10 76; }

valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  for o in ${ip//./ }; do ((10#$o <= 255)) || return 1; done
}

# ---------------------------------------------------------------- checks
if [[ $EUID -ne 0 ]]; then
  echo "Run this as root on the Proxmox VE host." >&2
  exit 1
fi
for cmd in pct qm pveam pvesh pvesm whiptail curl openssl; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd: run this on a Proxmox VE host." >&2; exit 1; }
done

clear
cat <<BANNER
${BL}
   __  ___              ____
  /  |/  /__  ___  ___/ / /__
 / /|_/ / _ \/ _ \/ _  / / -_)
/_/  /_/\___/\___/\_,_/_/\__/   for Proxmox VE
${CL}
BANNER

# The newest Moodle release (tags like v5.3.0) whose download package exists yet
msg_info "Finding the latest Moodle release"
MOODLE_RELEASE=""
MOODLE_VERSION=""
while read -r v; do
  branch="$(printf '%d%02d' "${v%%.*}" "$(cut -d. -f2 <<<"$v")")"
  if curl -fsI --max-time 15 "https://packaging.moodle.org/stable$branch/moodle-${v%.*}.tgz" >/dev/null 2>&1; then
    MOODLE_RELEASE="$v"
    MOODLE_VERSION="${v%.*}"
    break
  fi
done < <(curl -fsSL --max-time 20 https://api.github.com/repos/moodle/moodle/git/matching-refs/tags/v 2>/dev/null |
  grep -oE '"refs/tags/v[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' |
  sort -rV | awk -F. '!seen[$1 "." $2]++' | head -n 3 || true)
if [[ -n "$MOODLE_VERSION" ]]; then
  msg_ok "Latest Moodle release is $MOODLE_RELEASE"
else
  MOODLE_VERSION="$MOODLE_FALLBACK"
  MOODLE_RELEASE="$MOODLE_FALLBACK"
  msg_ok "Could not reach Moodle's GitHub, using Moodle $MOODLE_VERSION"
fi
MOODLE_BRANCH="$(printf '%d%02d' "${MOODLE_VERSION%%.*}" "${MOODLE_VERSION#*.}")"   # 5.3 -> 503

# The newest PHP that Moodle's release notes list for this version
# ("- PHP version: minimum PHP 8.3.0. PHP 8.4.x is supported too.").
msg_info "Checking which PHP versions Moodle ${MOODLE_VERSION} supports"
PHP_V="$(curl -fsSL --max-time 15 "https://raw.githubusercontent.com/moodle/devdocs/main/general/releases/${MOODLE_VERSION}.md" 2>/dev/null |
  awk '/^- PHP version:/ && !done {print; done = 1}' | grep -oE 'PHP 8\.[0-9]+' | awk '{print $2}' | sort -V | tail -1 || true)"
if [[ -n "$PHP_V" ]]; then
  msg_ok "Moodle ${MOODLE_VERSION} supports up to PHP ${PHP_V}"
else
  PHP_V="$PHP_FALLBACK"
  msg_ok "Could not read Moodle's release notes, using PHP ${PHP_V}"
fi

# The minimum MariaDB for this version, from <VENDOR name="mariadb" version="11.4.0" /> in its environment.xml
msg_info "Checking which MariaDB Moodle ${MOODLE_VERSION} needs"
MARIADB_V=""
for path in public/admin admin; do
  MARIADB_V="$(curl -fsSL --max-time 20 "https://raw.githubusercontent.com/moodle/moodle/MOODLE_${MOODLE_BRANCH}_STABLE/$path/environment.xml" 2>/dev/null |
    awk -v ver="$MOODLE_VERSION" '$0 ~ "<MOODLE version=\"" ver "\"" {f = 1} f && /<\/MOODLE>/ {f = 0} f' |
    grep -oE 'VENDOR name="mariadb" version="[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$' || true)"
  [[ -n "$MARIADB_V" ]] && break
done
if [[ -n "$MARIADB_V" ]]; then
  msg_ok "Moodle ${MOODLE_VERSION} needs MariaDB ${MARIADB_V}"
else
  MARIADB_V="$MARIADB_FALLBACK"
  msg_ok "Could not read Moodle's requirements, using MariaDB ${MARIADB_V}"
fi

CTID="$(pvesh get /cluster/nextid)"
# Name and free space of each active storage that can hold containers, as menu pairs
mapfile -t STORAGES < <(pvesm status -content rootdir | awk 'NR > 1 && $3 == "active" {printf "%s\n%.0f GB free\n", $1, $6 / 1048576}')
if ((${#STORAGES[@]} == 0)); then
  echo "No active storage can hold containers (pvesm status -content rootdir)." >&2
  exit 1
fi
STORAGE="${STORAGES[0]}"
NET="dhcp"
GATEWAY=""
ROOT_PASSWORD=""

# ---------------------------------------------------------------- menus
MODE=$(whiptail --backtitle "$BACKTITLE" --title "SETTINGS" --ok-button "Select" --cancel-button "Exit" \
  --menu "\nThis creates a new container with Moodle ${MOODLE_RELEASE}, PHP ${PHP_V} and MariaDB ${MARIADB_V}.\n\nDefault: ID ${CTID}, ${CORES} cores, ${MEMORY} MB RAM, ${DISK_GB} GB on ${STORAGE}, DHCP on ${BRIDGE}." \
  16 76 2 \
  "1" "Default settings" \
  "2" "Advanced settings" \
  3>&1 1>&2 2>&3) || exit_script

if [[ "$MODE" == "2" ]]; then
  while :; do
    CTID=$(input "CONTAINER ID" "Container ID (the next free one is filled in):" "$CTID")
    if [[ ! "$CTID" =~ ^[0-9]+$ ]] || ((CTID < 100)); then
      oops "The container ID must be a number from 100 up."
    elif pct status "$CTID" &>/dev/null || qm status "$CTID" &>/dev/null; then
      oops "ID $CTID is already used by a container or VM."
    else
      break
    fi
  done
  while :; do
    HOSTNAME=$(input "HOSTNAME" "Container hostname:" "$HOSTNAME")
    [[ "$HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] && break
    oops "Use lowercase letters, digits and hyphens only (no hyphen at the start or end)."
  done
  while :; do
    DISK_GB=$(input "DISK SIZE" "Disk size in GB (20 is enough to start):" "$DISK_GB")
    [[ "$DISK_GB" =~ ^[0-9]+$ ]] && ((DISK_GB >= 10)) && break
    oops "Enter a whole number of GB, 10 or more."
  done
  while :; do
    CORES=$(input "CPU CORES" "Number of CPU cores:" "$CORES")
    [[ "$CORES" =~ ^[1-9][0-9]*$ ]] && break
    oops "Enter a whole number of cores, 1 or more."
  done
  while :; do
    MEMORY=$(input "RAM" "RAM in MB (4096 recommended):" "$MEMORY")
    [[ "$MEMORY" =~ ^[0-9]+$ ]] && ((MEMORY >= 1024)) && break
    oops "Enter RAM in MB, 1024 or more."
  done
  if ((${#STORAGES[@]} > 2)); then
    STORAGE=$(whiptail --backtitle "$BACKTITLE" --title "STORAGE" --ok-button "Select" --cancel-button "Exit" \
      --menu "\nWhere should the container's disk go?" 16 76 6 "${STORAGES[@]}" 3>&1 1>&2 2>&3) || exit_script
  fi
  while :; do
    BRIDGE=$(input "BRIDGE" "Network bridge:" "$BRIDGE")
    ip link show "$BRIDGE" &>/dev/null && break
    oops "Bridge $BRIDGE does not exist on this host."
  done
  while :; do
    NET=$(input "IP ADDRESS" "Static IPv4 address with prefix (e.g. 192.168.0.50/24), or dhcp:" "$NET")
    [[ "$NET" == "dhcp" ]] && break
    if [[ "$NET" =~ ^([0-9.]+)/([0-9]{1,2})$ ]] && valid_ipv4 "${BASH_REMATCH[1]}" && ((BASH_REMATCH[2] >= 8 && BASH_REMATCH[2] <= 32)); then
      while :; do
        GATEWAY=$(input "GATEWAY" "Gateway IP (e.g. 192.168.0.1):" "$GATEWAY")
        valid_ipv4 "$GATEWAY" && break
        oops "That is not an IPv4 address."
      done
      break
    fi
    oops "Write it like 192.168.0.50/24, or type dhcp."
  done
  while :; do
    ROOT_PASSWORD=$(password "ROOT PASSWORD" "Root password for the container (blank: none, open it with pct enter $CTID):")
    [[ -z "$ROOT_PASSWORD" ]] && break
    if ((${#ROOT_PASSWORD} < 8)); then
      oops "Use at least 8 characters, or leave it blank."
    elif [[ "$(password "ROOT PASSWORD" "Type the root password again:")" != "$ROOT_PASSWORD" ]]; then
      oops "The passwords do not match."
    else
      break
    fi
  done
fi

# Site details are asked in both modes.
ADMIN_EMAIL=""
PUBLIC_URL=""
while :; do
  ADMIN_EMAIL=$(input "ADMIN EMAIL" "Email address for the Moodle admin account:" "$ADMIN_EMAIL")
  [[ "$ADMIN_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] && break
  oops "That does not look like an email address."
done
while :; do
  PUBLIC_URL=$(input "PUBLIC ADDRESS" "Address people will use, behind a reverse proxy such as Nginx Proxy Manager\n(e.g. https://training.example.com). Leave blank to use http://<container IP>." "$PUBLIC_URL")
  PUBLIC_URL="${PUBLIC_URL%/}"
  [[ -z "$PUBLIC_URL" || "$PUBLIC_URL" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$ ]] && break
  oops "Write it like https://training.example.com"
done
SITE_FULLNAME=$(input "SITE NAME" "Full name of the Moodle site:" "$SITE_FULLNAME")
[[ -n "$SITE_FULLNAME" ]] || SITE_FULLNAME="My Moodle Site"

NET_SUMMARY="$NET"
[[ "$NET" != "dhcp" ]] && NET_SUMMARY="$NET via $GATEWAY"
ROOT_SUMMARY="none (pct enter $CTID)"
[[ -n "$ROOT_PASSWORD" ]] && ROOT_SUMMARY="password set"
whiptail --backtitle "$BACKTITLE" --title "READY TO INSTALL" --yes-button "Install" --no-button "Exit" --yesno "
Container ID : $CTID ($HOSTNAME)
Resources    : $CORES cores, $MEMORY MB RAM, $DISK_GB GB on $STORAGE
Network      : $NET_SUMMARY on $BRIDGE
Root login   : $ROOT_SUMMARY

Moodle       : $MOODLE_RELEASE, PHP $PHP_V, MariaDB $MARIADB_V
Site         : $SITE_FULLNAME
Address      : ${PUBLIC_URL:-http://<container IP>}
Admin        : $ADMIN_USER <$ADMIN_EMAIL>" 20 76 || exit_script
clear
echo "Installing Moodle in container $CTID. Details go to $LOG"
echo

# ---------------------------------------------------------------- container
# Newest Ubuntu 24.04 template, downloaded if missing
get_template() {
  pveam update || true
  TEMPLATE="$(pveam available --section system | awk '/ubuntu-24\.04-standard/ {print $2}' | sort -V | tail -1)"
  TEMPLATE="${TEMPLATE:-$(pveam list local | awk -F/ '/ubuntu-24\.04-standard/ {print $2}' | awk '{print $1}' | sort -V | tail -1)}"
  [[ -n "$TEMPLATE" ]] || { echo "No Ubuntu 24.04 template found (pveam available)."; return 1; }
  pveam list local | grep -q "$TEMPLATE" || pveam download local "$TEMPLATE"
}
step "Getting the Ubuntu 24.04 template" get_template

create_ct() {
  local ip="ip=dhcp"
  [[ "$NET" != "dhcp" ]] && ip="ip=$NET,gw=$GATEWAY"
  local args=(--hostname "$HOSTNAME" --cores "$CORES" --memory "$MEMORY" --swap "$SWAP"
    --rootfs "$STORAGE:$DISK_GB" --net0 "name=eth0,bridge=$BRIDGE,$ip,firewall=1"
    --unprivileged 1 --features nesting=1 --onboot 1 --start 1)
  [[ -n "$ROOT_PASSWORD" ]] && args+=(--password "$ROOT_PASSWORD")
  pct create "$CTID" "local:vztmpl/$TEMPLATE" "${args[@]}"
}
step "Creating container $CTID" create_ct

wait_for_network() {
  local i
  for i in {1..60}; do
    CT_IP="$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$CT_IP" ]] && pct exec "$CTID" -- getent hosts archive.ubuntu.com >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "The container got no network address or DNS within 2 minutes (tried $i times)."
  return 1
}
step "Waiting for the container's network" wait_for_network
MOODLE_WWWROOT="${PUBLIC_URL:-http://$CT_IP}"

# ---------------------------------------------------------------- inside the container
step "Updating Ubuntu" ct <<'EOF'
apt-get update
apt-get install -y locales software-properties-common ca-certificates curl wget unzip gnupg2
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
add-apt-repository -y universe
apt-get update
apt-get full-upgrade -y
EOF

# Ubuntu 24.04 itself ships PHP 8.3; newer versions come from the ondrej/php PPA.
step "Installing PHP $PHP_V" ct <<'EOF'
if ! apt-cache show "php$PHP_V-cli" >/dev/null 2>&1; then
  add-apt-repository -y ppa:ondrej/php
  apt-get update
fi
pkgs=("php$PHP_V" "php$PHP_V-cli" "php$PHP_V-common" "libapache2-mod-php$PHP_V")
for ext in curl gd intl mbstring mysql xml zip soap bcmath ldap opcache; do
  # opcache is built into PHP from 8.5, so its package may not exist
  if apt-cache show "php$PHP_V-$ext" >/dev/null 2>&1; then pkgs+=("php$PHP_V-$ext"); fi
done
apt-get install -y apache2 "${pkgs[@]}" graphviz aspell ghostscript
update-alternatives --set php "/usr/bin/php$PHP_V"
"php$PHP_V" -m | grep -qi '^sodium$' || { echo "PHP $PHP_V has no sodium extension, which Moodle requires."; exit 1; }
for ini in "/etc/php/$PHP_V/apache2/php.ini" "/etc/php/$PHP_V/cli/php.ini"; do
  [[ -f "$ini" ]] || continue
  sed -i 's/^;*memory_limit.*/memory_limit = 256M/' "$ini"
  sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 128M/' "$ini"
  sed -i 's/^;*post_max_size.*/post_max_size = 128M/' "$ini"
  sed -i 's/^;*max_execution_time.*/max_execution_time = 300/' "$ini"
  if grep -q '^;*max_input_vars' "$ini"; then
    sed -i 's/^;*max_input_vars.*/max_input_vars = 5000/' "$ini"
  else
    echo "max_input_vars = 5000" >>"$ini"
  fi
done
EOF

step "Installing MariaDB $MARIADB_V" pct exec "$CTID" -- env DEBIAN_FRONTEND=noninteractive MARIADB_V="$MARIADB_V" bash -euo pipefail -s <<'EOF'
curl -fsSL https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-$MARIADB_V"
apt-get update
apt-get install -y mariadb-server mariadb-client
systemctl enable --now mariadb
EOF

step "Creating the database" pct exec "$CTID" -- mariadb <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

step "Downloading Moodle $MOODLE_VERSION" pct exec "$CTID" -- env BRANCH="$MOODLE_BRANCH" VERSION="$MOODLE_VERSION" bash -euo pipefail -c '
cd /tmp
wget -q -O moodle.tgz "https://packaging.moodle.org/stable$BRANCH/moodle-$VERSION.tgz"
[[ $(stat -c%s moodle.tgz) -gt 50000000 ]] || { echo "The Moodle download is too small, it probably failed."; exit 1; }
tar -xzf moodle.tgz -C /var/www/
rm moodle.tgz
mkdir -p /var/moodledata
chown -R www-data:www-data /var/www/moodle /var/moodledata
chmod 770 /var/moodledata'

step "Setting up Apache and cron" ct <<'EOF'
cat > /etc/apache2/sites-available/moodle.conf <<'APACHE'
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/moodle/public
    <Directory /var/www/moodle/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/moodle_error.log
    CustomLog ${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>
APACHE
a2dissite 000-default.conf || true
a2ensite moodle.conf
a2enmod rewrite
systemctl enable apache2
systemctl restart apache2
echo "* * * * * www-data /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null" > /etc/cron.d/moodle
chmod 644 /etc/cron.d/moodle
EOF

step "Installing Moodle (takes a few minutes)" pct exec "$CTID" -- runuser -u www-data -- "php$PHP_V" /var/www/moodle/admin/cli/install.php \
  --non-interactive --agree-license --lang=en \
  --wwwroot="$MOODLE_WWWROOT" --dataroot=/var/moodledata \
  --dbtype=mariadb --dbhost=localhost --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" \
  --fullname="$SITE_FULLNAME" --shortname="$SITE_SHORTNAME" \
  --adminuser="$ADMIN_USER" --adminpass="$ADMIN_PASS" --adminemail="$ADMIN_EMAIL"

finish() {
  # Behind a reverse proxy that ends HTTPS, Moodle must trust it for https:// links and secure cookies.
  if [[ "$MOODLE_WWWROOT" == https://* ]]; then
    pct exec "$CTID" -- sed -i "s|^require_once(__DIR__ . '/lib/setup.php');|\$CFG->sslproxy = true;\n\n&|" /var/www/moodle/config.php
    pct exec "$CTID" -- grep -q 'sslproxy = true' /var/www/moodle/config.php || { echo "Could not add sslproxy to config.php"; return 1; }
  fi
  pct exec "$CTID" -- chmod 640 /var/www/moodle/config.php
  # Credentials stay in a root-only file inside the container instead of the terminal scrollback
  pct exec "$CTID" -- bash -c "umask 077 && cat > /root/moodle-credentials.txt" <<CREDS
Web URL     : $MOODLE_WWWROOT
Admin user  : $ADMIN_USER
Admin pass  : $ADMIN_PASS
Admin email : $ADMIN_EMAIL
DB name     : $DB_NAME
DB user     : $DB_USER
DB password : $DB_PASS
CREDS
}
step "Finishing the configuration" finish

echo
echo "${GN}Moodle ${MOODLE_RELEASE} is installed.${CL}"
echo
echo "  Container   : $CTID ($HOSTNAME), IP $CT_IP"
echo "  Web address : $MOODLE_WWWROOT"
echo "  Admin user  : $ADMIN_USER"
echo "  Passwords   : pct exec $CTID -- cat /root/moodle-credentials.txt"
echo
if [[ "$MOODLE_WWWROOT" == https://* ]]; then
  echo "  Next: in Nginx Proxy Manager, point ${MOODLE_WWWROOT#https://} at http://$CT_IP:80 with an SSL certificate."
else
  echo "  Next: to put it behind Nginx Proxy Manager later, set \$CFG->wwwroot to the https:// address"
  echo "        and add \$CFG->sslproxy = true; in /var/www/moodle/config.php."
fi
if [[ "$NET" == "dhcp" ]]; then
  echo "  The IP comes from DHCP: reserve it in your router so the address stays the same."
fi
echo "  Sign in and change the admin password."
