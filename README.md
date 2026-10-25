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
