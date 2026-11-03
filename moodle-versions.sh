# moodle-versions.sh
# Looks up Moodle releases and the PHP and MariaDB they need. install-moodle-proxmox.sh and moodle-update.sh
# both download and source this file from GitHub, so each lookup lives in one place.
# Every function prints nothing when its source cannot be read; the caller decides the fallback.

branch_of_version() { printf '%d%02d' "${1%%.*}" "$(cut -d. -f2 <<<"$1")"; }   # 5.3 or 5.3.0 -> 503

# The newest release (e.g. 5.3.0) whose download package exists yet, from a series newer than branch $1 (default: any)
moodle_newest_release() {
  local after="${1:-0}" v b
  while read -r v; do
    b="$(branch_of_version "$v")"
    ((10#$b > 10#$after)) || return 0
    if curl -fsI --max-time 15 "https://packaging.moodle.org/stable$b/moodle-${v%.*}.tgz" >/dev/null 2>&1; then
      echo "$v"
      return 0
    fi
  done < <(curl -fsSL --max-time 20 https://api.github.com/repos/moodle/moodle/git/matching-refs/tags/v 2>/dev/null |
    grep -oE '"refs/tags/v[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' |
    sort -rV | awk -F. '!seen[$1 "." $2]++' | head -n 3 || true)
}

# "<oldest> <newest>" PHP in Moodle's release notes for a version ("minimum PHP 8.3.0. PHP 8.4.x is supported too.")
php_range() {
  curl -fsSL --max-time 15 "https://raw.githubusercontent.com/moodle/devdocs/main/general/releases/$1.md" 2>/dev/null |
    awk '/^- PHP version:/ && !done {print; done = 1}' | grep -oE 'PHP 8\.[0-9]+' | awk '{print $2}' | sort -V | sed -n '1p;$p' | paste -sd' ' || true
}

# The minimum MariaDB for a version, from <VENDOR name="mariadb" version="11.4.0" /> in its environment.xml
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
