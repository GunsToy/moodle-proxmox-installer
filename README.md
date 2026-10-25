# moodle-proxmox-installer

Installs the **latest Moodle release** in a new Proxmox LXC container (Ubuntu 24.04), with menus like the Proxmox VE community scripts.

## Run

In the Proxmox web UI open your node > **Shell** and paste:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/GunsToy/moodle-proxmox-installer/main/install-moodle-proxmox.sh)"
```

- **Default settings**: next free container ID, 2 cores, 4 GB RAM, 20 GB disk, DHCP on `vmbr0`. You only enter the admin email, the public address and the site name.
- **Advanced settings**: also choose the container ID, hostname, disk, cores, RAM, storage, bridge, static IP and a root password.

A summary screen shows everything before anything is created; Exit at any step changes nothing.

## What it installs

Everything is looked up when the script runs, before the menus:

- **Moodle**: the newest release tagged on Moodle's GitHub whose download package is out (5.3.0 today).
- **PHP**: the newest version that release supports, from Moodle's release notes (8.4 for 5.3). Versions newer than Ubuntu's own 8.3 come from the ondrej/php PPA.
- **MariaDB**: that release's minimum, from its `environment.xml` (11.4 for 5.3), from MariaDB's repository.
- Without internet access to those sites it uses Moodle 5.3, PHP 8.4 and MariaDB 11.4.

It also installs Apache and the Moodle cron job.
- The admin and database passwords are random and saved in the container: `pct exec <id> -- cat /root/moodle-credentials.txt`.
- The install log is on the Proxmox host in `/var/log/moodle-install-<date>.log`.

## Behind Nginx Proxy Manager

Enter the public address (e.g. `https://training.example.com`) when asked. The script sets it as Moodle's address and adds `$CFG->sslproxy = true;`. In Nginx Proxy Manager, add a proxy host for that domain pointing at `http://<container IP>:80` with an SSL certificate.

## Updates

Inside the container (from the Proxmox host: `pct enter <id>`), run:

```bash
update            # check, show what is new, ask, then install
update --check    # only show what is new
```

`update` downloads the newest `moodle-update.sh` from this repository and checks:

- **Moodle**: a newer build of the installed version (e.g. 5.3.0 → 5.3.1) is part of the normal update. A new major version (e.g. 5.3 → 5.4) is only installed after a separate yes, together with the PHP and MariaDB versions it needs.
- **PHP**: when the installed Moodle supports a newer PHP, it offers to switch (and switches back if Moodle's checks fail).
- **Ubuntu packages**, including Apache and PHP/MariaDB security patches, and **Composer**.
- **Add-on plugins**: lists available updates; install them in Moodle under *Site administration > Plugins > Plugins overview*.

Before Moodle itself changes, the site goes into maintenance mode and the database and Moodle code are backed up to `/var/backups/moodle` (the newest 3 are kept). `config.php` and add-on plugins are carried over to the new code. If the Moodle upgrade fails, the previous code and database are put back. Course files in `/var/moodledata` are not part of that backup; keep the container in your Proxmox backups.

For a container installed before the `update` command existed, add it with:

```bash
curl -fsSL https://raw.githubusercontent.com/GunsToy/moodle-proxmox-installer/main/moodle-update.sh -o /usr/local/sbin/moodle-update.sh && chmod 755 /usr/local/sbin/moodle-update.sh
```

and run `moodle-update.sh` (or `moodle-update.sh --check`).
