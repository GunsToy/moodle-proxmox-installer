# Copying a test Moodle container into a live one

Use this when a Moodle container made by `install-moodle-proxmox.sh` has been set up and tested, and you want a
separate live container with the same courses, users and settings. The test container keeps working afterwards.

Replace in the commands below:

| Placeholder | Meaning |
|---|---|
| `<TEST>` | ID of the existing (test) container, e.g. `106` |
| `<LIVE>` | ID for the new live container, e.g. `120` (`pvesh get /cluster/nextid`) |
| `<LIVE_IP>` | The live container's static IP, e.g. `192.168.0.22/24` |
| `<LIVE_URL>` | The live site's address, e.g. `https://training.example.com` |

Run everything on the Proxmox host as root, unless it says *inside the container*.

## 1. Clone

A snapshot-free full clone needs the test container stopped for the copy (a few minutes of downtime):

```bash
pct shutdown <TEST>
pct clone <TEST> <LIVE> --full --hostname moodle-live
```

If the test container has MariaDB encryption with its key folder mounted from the host (an `mp0: /root/...,mp=/etc/mysql/encryption` line
in `pct config <TEST>`), `pct clone` may refuse to copy that bind mount. Then remove it from the test container's config, clone, and put it back:

```bash
pct config <TEST> | grep ^mp0          # note the line
pct set <TEST> --delete mp0
pct clone <TEST> <LIVE> --full --hostname moodle-live
pct set <TEST> -mp0 <the same value as before>
```

## 2. Give the live container its own key folder (only with MariaDB encryption)

The cloned database is encrypted with the same key. Copy the key to a separate folder so the two containers are not tied together:

```bash
cp -a /root/moodle-db-key /root/moodle-live-db-key        # keeps the 100107:100110 owner and read-only modes
pct set <LIVE> -mp0 /root/moodle-live-db-key,mp=/etc/mysql/encryption,ro=1
```

There is nothing new to save in your password manager: it is the same key. Without this folder, MariaDB in the live container does not start.

## 3. Network

The clone copies the test container's IP. Give it its own before starting it:

```bash
pct set <LIVE> -net0 name=eth0,bridge=vmbr0,firewall=1,ip=<LIVE_IP>,gw=<your gateway>
pct start <TEST>
pct start <LIVE>
```

(Proxmox gives the clone a new MAC address automatically.)

## 4. Moodle's address

*Inside the live container* (`pct enter <LIVE>`), set the live address in `/var/www/moodle/config.php`:

```php
$CFG->wwwroot = '<LIVE_URL>';
$CFG->sslproxy = true;   // when it sits behind Nginx Proxy Manager with HTTPS
```

Then clear Moodle's caches:

```bash
runuser -u www-data -- php /var/www/moodle/admin/cli/purge_caches.php
```

If the live site takes over the test site's address, give the test container a new one the same way, and update Nginx Proxy Manager so each
domain points at the right container IP (port 80).

## 5. Stop the test site from emailing people

Both copies have the same users and the same outgoing mail settings. *Inside the test container*, add to `config.php` (above `require_once`):

```php
$CFG->divertallemailsto = 'you@example.com';   // or: $CFG->noemailever = true;
```

## 6. Backups

A Proxmox backup job that lists container IDs one by one does not include the new container. Add `<LIVE>` under
*Datacenter > Backup > (job) > Edit*, or select "All". Then run one backup of `<LIVE>` and check it finishes.

## 7. Check

- Open `<LIVE_URL>`, sign in as an admin, and open a course.
- *Site administration > Notifications* shows no errors.
- *Site administration > Server > Tasks > Task logs*: cron tasks run in the live container.
- Send a test email (Forgot password to your own account) from the live site, and confirm the test site sends to the divert address only.
- Optional: re-register the live site under *Site administration > Registration*, since both copies start with the same site identifier.
