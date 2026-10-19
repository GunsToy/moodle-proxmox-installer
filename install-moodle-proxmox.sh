#!/usr/bin/env bash
#
# install-moodle-proxmox.sh
# Installs Moodle 5.3 LTS into a new Proxmox LXC container (Ubuntu 24.04).
#
# Requirements:
# - Run as root on a Proxmox VE host
# - Internet access
# - Storage pool available (default: Storage_pool)
#
# Usage:
#   chmod +x install-moodle-proxmox.sh
#   ./install-moodle-proxmox.sh
#
# The script will prompt for:
# - Static IP, CIDR, and gateway
# - Container root password

set -euo pipefail

# ======================== CONFIGURATION ========================
CTID=106
HOSTNAME="moodle"
CORES=2
MEMORY=4096
SWAP=512
DISK="Storage_pool:20"
BRIDGE="vmbr0"
TEMPLATE="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"

# Moodle / DB settings (passwords generated randomly)
DB_NAME="moodle"
DB_USER="moodleuser"
DB_PASS="$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 12 | tr -d '/+=' | head -c 12)"
ADMIN_EMAIL="admin@example.com"
SITE_FULLNAME="My Moodle Site"
SITE_SHORTNAME="Moodle"
# ===============================================================

echo "=== Moodle Proxmox LXC Installer ==="
echo "Target: Moodle 5.3 LTS (PHP 8.3+, MariaDB 11.4+)"
echo "Container ID: $CTID"
echo

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

if pct status "$CTID" &>/dev/null; then
  echo "Container $CTID already exists. Choose a different CTID." >&2
  exit 1
fi

# Network
echo ">>> Network configuration (static IP)"
read -rp "Enter static IP address for the container (e.g. 192.168.1.50): " STATIC_IP
read -rp "Enter netmask in CIDR notation (e.g. 24): " CIDR
read -rp "Enter gateway IP (e.g. 192.168.1.1): " GATEWAY

# Root password
echo
read -rsp "Enter root password for the container: " ROOT_PASSWORD
echo
read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
echo

if [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
  echo "Passwords do not match." >&2
  exit 1
fi

if [[ -z "$ROOT_PASSWORD" || -z "$STATIC_IP" || -z "$CIDR" || -z "$GATEWAY" ]]; then
  echo "IP, CIDR, gateway, and root password are required." >&2
  exit 1
fi

echo
echo "Container will use: ${STATIC_IP}/${CIDR} via gateway ${GATEWAY}"
echo

# Download template if missing
echo ">>> Checking / downloading Ubuntu 24.04 template..."
if ! pveam list local | grep -q "$TEMPLATE"; then
  pveam update || true
  pveam download local "$TEMPLATE"
fi

# Create container
echo ">>> Creating LXC container $CTID..."
pct create "$CTID" "local:vztmpl/$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --rootfs "$DISK" \
  --net0 "name=eth0,bridge=$BRIDGE,ip=${STATIC_IP}/${CIDR},gw=${GATEWAY},firewall=1" \
  --unprivileged 1 \
  --features nesting=1 \
  --password "$ROOT_PASSWORD" \
  --onboot 1 \
  --start 1

echo ">>> Waiting for container to start..."
sleep 15
for i in {1..30}; do
  if pct exec "$CTID" -- true 2>/dev/null; then
    break
  fi
  sleep 2
done

CT_IP="$STATIC_IP"
MOODLE_WWWROOT="http://$CT_IP"
echo "Container IP: $CT_IP"

echo ">>> Installing Moodle stack inside container..."

pct exec "$CTID" -- bash -s <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update || true
apt-get install -y locales software-properties-common ca-certificates apt-transport-https curl wget unzip gnupg2
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
export LANG=en_US.UTF-8

add-apt-repository -y universe || true
apt-get update
apt-get full-upgrade -y

apt-get install -y apache2 \
  php php-cli php-common libapache2-mod-php \
  php-curl php-gd php-intl php-mbstring php-mysql php-xml \
  php-zip php-soap php-bcmath php-opcache php-ldap \
  graphviz aspell ghostscript

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
for ini in /etc/php/${PHP_VER}/apache2/php.ini /etc/php/${PHP_VER}/cli/php.ini; do
  if [[ -f "$ini" ]]; then
    sed -i 's/^;*memory_limit.*/memory_limit = 256M/' "$ini"
    sed -i 's/^;*max_input_vars.*/max_input_vars = 5000/' "$ini" || echo "max_input_vars = 5000" >> "$ini"
    sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 128M/' "$ini"
    sed -i 's/^;*post_max_size.*/post_max_size = 128M/' "$ini"
    sed -i 's/^;*max_execution_time.*/max_execution_time = 300/' "$ini"
  fi
done

curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-11.4"
apt-get update
apt-get install -y mariadb-server mariadb-client

systemctl enable --now apache2 mariadb

cd /tmp
rm -f moodle.tgz
echo "Downloading Moodle 5.3..."
wget -q --show-progress -O moodle.tgz "https://packaging.moodle.org/stable503/moodle-5.3.tgz"

if [[ ! -s moodle.tgz ]] || [[ $(stat -c%s moodle.tgz) -lt 50000000 ]]; then
  echo "ERROR: Moodle download failed or file is too small." >&2
  exit 1
fi

tar -xzf moodle.tgz -C /var/www/
chown -R www-data:www-data /var/www/moodle

mkdir -p /var/moodledata
chown www-data:www-data /var/moodledata
chmod 770 /var/moodledata

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
systemctl reload apache2

echo "* * * * * www-data /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null" > /etc/cron.d/moodle
chmod 644 /etc/cron.d/moodle

echo "Base stack ready."
EOF

echo ">>> Creating Moodle database and user..."
pct exec "$CTID" -- mariadb <<SQL
CREATE DATABASE IF NOT EXISTS moodle CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">>> Running Moodle CLI installer..."
pct exec "$CTID" -- bash -c "chown -R www-data:www-data /var/www/moodle /var/moodledata && chmod -R 755 /var/www/moodle && chmod 770 /var/moodledata && cd /tmp && sudo -u www-data /usr/bin/php /var/www/moodle/admin/cli/install.php \
  --non-interactive \
  --agree-license \
  --lang=en \
  --wwwroot=\"$MOODLE_WWWROOT\" \
  --dataroot=/var/moodledata \
  --dbtype=mariadb \
  --dbhost=localhost \
  --dbname=\"$DB_NAME\" \
  --dbuser=\"$DB_USER\" \
  --dbpass=\"$DB_PASS\" \
  --fullname=\"$SITE_FULLNAME\" \
  --shortname=\"$SITE_SHORTNAME\" \
  --adminuser=\"$ADMIN_USER\" \
  --adminpass=\"$ADMIN_PASS\" \
  --adminemail=\"$ADMIN_EMAIL\""

pct exec "$CTID" -- chown -R www-data:www-data /var/www/moodle /var/moodledata
pct exec "$CTID" -- chmod 640 /var/www/moodle/config.php 2>/dev/null || true

echo
echo "=========================================="
echo "Moodle installation complete!"
echo "=========================================="
echo "Container ID : $CTID"
echo "Hostname     : $HOSTNAME"
echo "IP Address   : $CT_IP"
echo "Web URL      : $MOODLE_WWWROOT"
echo "Admin user   : $ADMIN_USER"
echo "Admin pass   : $ADMIN_PASS"
echo "DB password  : $DB_PASS"
echo
echo "Root password for container was set during prompts."
echo
echo "Next steps:"
echo "  - Access the site and complete any remaining setup."
echo "  - For production with Nginx Proxy Manager, set:"
echo "      \$CFG->wwwroot = 'https://yourdomain.com';"
echo "      \$CFG->sslproxy = true;"
echo "      \$CFG->reverseproxy = true;"
echo "  - Change default passwords if needed."
echo "=========================================="
