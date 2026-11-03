# Graph Report - moodle-proxmox-installer  (2026-11-03)

## Corpus Check
- 9 files · ~6,376 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 87 nodes · 119 edges · 16 communities (7 shown, 9 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Container Installer Flow
- Update Command Steps
- Moodle Stack and Add-user Plugin
- Update Script Helpers
- Moodle Upgrade and Rollback
- Installer Menu Prompts
- Add-user Form
- Add-user Redirect Hook
- Add-user Privacy Provider
- Installer Output Helpers
- Backups and Rollback
- Reverse Proxy Setup

## God Nodes (most connected - your core abstractions)
1. `moodle-update.sh script` - 12 edges
2. `install-moodle-proxmox.sh script` - 9 edges
3. `upgrade_moodle()` - 6 edges
4. `Runtime Version Lookup` - 6 edges
5. `step()` - 5 edges
6. `moodle_php()` - 5 edges
7. `step()` - 5 edges
8. `exit_script()` - 4 edges
9. `adduser_form` - 4 edges
10. `local/adduser plugin` - 4 edges

## Surprising Connections (you probably didn't know these)
- `moodle-update.sh script` --calls--> `moodle_info()`  [EXTRACTED]
  moodle-update.sh → moodle-update.sh  _Bridges community 3 → community 4_
- `moodle_checks()` --calls--> `moodle_php()`  [EXTRACTED]
  moodle-update.sh → moodle-update.sh  _Bridges community 1 → community 4_
- `install-moodle-proxmox.sh script` --calls--> `msg_info()`  [EXTRACTED]
  install-moodle-proxmox.sh → install-moodle-proxmox.sh  _Bridges community 5 → community 9_

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Installed Moodle LAMP stack** — readme_moodle, readme_php, readme_mariadb, readme_apache, readme_moodle_cron [EXTRACTED 1.00]
- **Safe Moodle upgrade flow** — readme_maintenance_mode, readme_backup_var_backups_moodle, readme_upgrade_rollback, readme_major_version_upgrade [EXTRACTED 1.00]

## Communities (16 total, 9 thin omitted)

### Community 0 - "Container Installer Flow"
Cohesion: 0.12
Nodes (9): Advanced Settings, Apache, Default Settings, Install log /var/log/moodle-install-<date>.log, /root/moodle-credentials.txt, Moodle cron job, moodle-proxmox-installer, Proxmox LXC Container (Ubuntu 24.04) (+1 more)

### Community 1 - "Update Command Steps"
Cohesion: 0.18
Nodes (7): moodle_checks(), PATH, switch_php(), Add-on plugin update listing, Composer, Maintenance mode during upgrade, update command

### Community 2 - "Moodle Stack and Add-user Plugin"
Cohesion: 0.20
Nodes (8): Moodle environment.xml, local/adduser plugin, MariaDB, Moodle, Enrol in multiple courses (manual enrolment, default role), ondrej/php PPA, PHP, Required unique ID number

### Community 3 - "Update Script Helpers"
Cohesion: 0.33
Nodes (9): ask(), branch_of_version(), mariadb_min(), msg_error(), msg_info(), msg_ok(), msg_warn(), moodle-update.sh script (+1 more)

### Community 4 - "Moodle Upgrade and Rollback"
Cohesion: 0.33
Nodes (7): backup(), moodle_info(), moodle_php(), newer(), rollback(), upgrade_moodle(), version_of_branch()

### Community 5 - "Installer Menu Prompts"
Cohesion: 0.47
Nodes (6): exit_script(), input(), oops(), password(), install-moodle-proxmox.sh script, valid_ipv4()

### Community 9 - "Installer Output Helpers"
Cohesion: 0.50
Nodes (4): msg_error(), msg_info(), msg_ok(), step()

## Knowledge Gaps
- **21 isolated node(s):** `PATH`, `moodle-proxmox-installer`, `Proxmox LXC Container (Ubuntu 24.04)`, `Proxmox VE Community Scripts style menus`, `Default Settings` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 44 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Runtime Version Lookup` connect `Moodle Stack and Add-user Plugin` to `Container Installer Flow`?**
  _High betweenness centrality (0.365) - this node is a cross-community bridge._
- **What connects `PATH`, `moodle-proxmox-installer`, `Proxmox LXC Container (Ubuntu 24.04)` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Container Installer Flow` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Why does `Major Moodle version upgrade (separate confirmation)` connect `Moodle Stack and Add-user Plugin` to `Update Command Steps`?**
  _High betweenness centrality (0.324) - this node is a cross-community bridge._
- **Why does `local/adduser plugin` connect `Moodle Stack and Add-user Plugin` to `Container Installer Flow`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._