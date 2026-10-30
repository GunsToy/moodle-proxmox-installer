# Graph Report - moodle-proxmox-installer  (2026-10-30)

## Corpus Check
- Corpus is ~5,559 words - fits in a single context window. You may not need a graph.

## Summary
- 68 nodes · 111 edges · 10 communities (9 shown, 1 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- LXC Install Script
- Moodle Update Script
- Update Helpers
- Installer Input Prompts
- PHP Switch and Backups
- PHP Checks and Rollback
- Status Messages
- Moodle Upgrade Flow
- Reverse Proxy HTTPS
- Version Requirements

## God Nodes (most connected - your core abstractions)
1. `moodle-update.sh script` - 12 edges
2. `install-moodle-proxmox.sh script` - 9 edges
3. `upgrade_moodle()` - 6 edges
4. `step()` - 5 edges
5. `step()` - 5 edges
6. `moodle_php()` - 5 edges
7. `exit_script()` - 4 edges
8. `msg_info()` - 3 edges
9. `msg_ok()` - 3 edges
10. `input()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `install-moodle-proxmox.sh script` --calls--> `msg_info()`  [EXTRACTED]
  install-moodle-proxmox.sh → install-moodle-proxmox.sh  _Bridges community 3 → community 6_
- `moodle-update.sh script` --calls--> `moodle_info()`  [EXTRACTED]
  moodle-update.sh → moodle-update.sh  _Bridges community 2 → community 5_
- `moodle-update.sh script` --calls--> `newer()`  [EXTRACTED]
  moodle-update.sh → moodle-update.sh  _Bridges community 2 → community 7_
- `upgrade_moodle()` --calls--> `moodle_php()`  [EXTRACTED]
  moodle-update.sh → moodle-update.sh  _Bridges community 5 → community 7_

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Moodle LAMP stack installed in the container** — readme_moodle, readme_php, readme_mariadb, readme_apache, readme_moodle_cron [EXTRACTED 1.00]
- **Safe Moodle upgrade flow** — moodle_update, readme_maintenance_mode, readme_pre_upgrade_backup, readme_config_php, readme_addon_plugins [EXTRACTED 1.00]
- **Reverse proxy HTTPS setup** — readme_nginx_proxy_manager, readme_cfg_sslproxy, readme_proxmox_lxc_container [INFERRED 0.85]

## Communities (10 total, 1 thin omitted)

### Community 0 - "LXC Install Script"
Cohesion: 0.13
Nodes (9): Advanced Settings, Apache, Default Settings, Install Log (/var/log/moodle-install-<date>.log), /root/moodle-credentials.txt, Moodle Cron Job, moodle-proxmox-installer, Proxmox LXC Container (Ubuntu 24.04) (+1 more)

### Community 1 - "Moodle Update Script"
Cohesion: 0.17
Nodes (6): PATH, Add-on Plugins, Composer, Maintenance Mode, Moodle, update command

### Community 2 - "Update Helpers"
Cohesion: 0.33
Nodes (9): ask(), branch_of_version(), mariadb_min(), msg_error(), msg_info(), msg_ok(), msg_warn(), moodle-update.sh script (+1 more)

### Community 3 - "Installer Input Prompts"
Cohesion: 0.47
Nodes (6): exit_script(), input(), oops(), password(), install-moodle-proxmox.sh script, valid_ipv4()

### Community 4 - "PHP Switch and Backups"
Cohesion: 0.33
Nodes (4): /var/moodledata, ondrej/php PPA, PHP, Proxmox Backups

### Community 5 - "PHP Checks and Rollback"
Cohesion: 0.40
Nodes (5): moodle_checks(), moodle_info(), moodle_php(), rollback(), switch_php()

### Community 6 - "Status Messages"
Cohesion: 0.50
Nodes (4): msg_error(), msg_info(), msg_ok(), step()

### Community 7 - "Moodle Upgrade Flow"
Cohesion: 0.50
Nodes (4): backup(), newer(), upgrade_moodle(), version_of_branch()

### Community 8 - "Reverse Proxy HTTPS"
Cohesion: 0.67
Nodes (3): $CFG->sslproxy, config.php, Nginx Proxy Manager

## Knowledge Gaps
- **13 isolated node(s):** `PATH`, `update command`, `Proxmox VE Community Scripts`, `ondrej/php PPA`, `Default Settings` (+8 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 24 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `moodle-proxmox-installer` connect `LXC Install Script` to `Moodle Update Script`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **What connects `PATH`, `update command`, `Proxmox VE Community Scripts` to the rest of the system?**
  _13 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `LXC Install Script` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Why does `Moodle` connect `Moodle Update Script` to `LXC Install Script`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **Why does `Apache` connect `LXC Install Script` to `Moodle Update Script`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._