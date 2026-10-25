# Graph Report - moodle-proxmox-installer  (2026-10-25)

## Corpus Check
- Corpus is ~5,559 words - fits in a single context window. You may not need a graph.

## Summary
- 71 nodes · 118 edges · 11 communities (8 shown, 3 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.85)
- Token cost: 41,349 input · 0 output

## Community Hubs (Navigation)
- Installer Container Steps
- Moodle Upgrade and Rollback
- Installer Overview and Stack
- Update Script Package Steps
- Update Version Helpers
- Updater Step Output
- PHP and MariaDB Choice
- PHP Switch with Checks
- Version Discovery
- Update Command
- Reverse Proxy Setup

## God Nodes (most connected - your core abstractions)
1. `moodle-proxmox-installer` - 15 edges
2. `moodle-update.sh script` - 12 edges
3. `install-moodle-proxmox.sh script` - 9 edges
4. `upgrade_moodle()` - 7 edges
5. `step()` - 5 edges
6. `step()` - 5 edges
7. `moodle_php()` - 5 edges
8. `exit_script()` - 4 edges
9. `moodle_checks()` - 4 edges
10. `rollback()` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Major Version Upgrade` --references--> `upgrade_moodle()`  [INFERRED]
  README.md → moodle-update.sh
- `Composer` --references--> `composer_update()`  [INFERRED]
  README.md → moodle-update.sh
- `PHP Version Switch` --references--> `moodle_checks()`  [INFERRED]
  README.md → moodle-update.sh
- `PHP Version Switch` --references--> `switch_php()`  [INFERRED]
  README.md → moodle-update.sh
- `Backup to /var/backups/moodle` --references--> `backup()`  [INFERRED]
  README.md → moodle-update.sh

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Safe Moodle upgrade flow (maintenance, backup, upgrade, rollback)** — readme_maintenance_mode, readme_moodle_backup, readme_major_version_upgrade, readme_upgrade_rollback [EXTRACTED 1.00]
- **Runtime version resolution of Moodle stack** — readme_moodle, readme_php, readme_mariadb, readme_environment_xml, readme_offline_fallback_versions [EXTRACTED 1.00]

## Communities (11 total, 3 thin omitted)

### Community 0 - "Installer Container Steps"
Cohesion: 0.23
Nodes (10): exit_script(), input(), msg_error(), msg_info(), msg_ok(), oops(), password(), install-moodle-proxmox.sh script (+2 more)

### Community 1 - "Moodle Upgrade and Rollback"
Cohesion: 0.22
Nodes (9): backup(), moodle_info(), moodle_php(), newer(), rollback(), upgrade_moodle(), version_of_branch(), /var/moodledata (+1 more)

### Community 2 - "Installer Overview and Stack"
Cohesion: 0.20
Nodes (10): Advanced Settings, Apache, Default Settings, Install Log, /root/moodle-credentials.txt, Moodle Cron Job, moodle-proxmox-installer, Proxmox LXC Container (+2 more)

### Community 3 - "Update Script Package Steps"
Cohesion: 0.22
Nodes (6): composer_update(), PATH, Add-on Plugins, Composer, Maintenance Mode, Ubuntu Package Updates

### Community 4 - "Update Version Helpers"
Cohesion: 0.50
Nodes (5): ask(), branch_of_version(), mariadb_min(), msg_warn(), moodle-update.sh script

### Community 5 - "Updater Step Output"
Cohesion: 0.50
Nodes (4): msg_error(), msg_info(), msg_ok(), step()

### Community 6 - "PHP and MariaDB Choice"
Cohesion: 0.50
Nodes (3): MariaDB, ondrej/php PPA, PHP

### Community 7 - "PHP Switch with Checks"
Cohesion: 1.00
Nodes (3): moodle_checks(), switch_php(), PHP Version Switch

## Knowledge Gaps
- **14 isolated node(s):** `PATH`, `Proxmox VE Community Scripts`, `Default Settings`, `Advanced Settings`, `ondrej/php PPA` (+9 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 24 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `moodle-proxmox-installer` connect `Installer Overview and Stack` to `Version Discovery`, `Update Command`, `Reverse Proxy Setup`, `PHP and MariaDB Choice`?**
  _High betweenness centrality (0.270) - this node is a cross-community bridge._
- **What connects `PATH`, `Proxmox VE Community Scripts`, `Default Settings` to the rest of the system?**
  _14 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `update Command` connect `Update Command` to `Installer Overview and Stack`, `Update Script Package Steps`?**
  _High betweenness centrality (0.208) - this node is a cross-community bridge._
- **Why does `Major Version Upgrade` connect `PHP and MariaDB Choice` to `Moodle Upgrade and Rollback`, `Update Script Package Steps`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._