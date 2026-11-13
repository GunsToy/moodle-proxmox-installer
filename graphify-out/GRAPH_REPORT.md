# Graph Report - moodle-proxmox-installer  (2026-11-13)

## Corpus Check
- 7 files · ~8,068 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 106 nodes · 150 edges · 17 communities (9 shown, 8 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Moodle Upgrade and Rollback
- Container Installer Flow
- Reverse Proxy & Enrolment
- Moodle Stack and Add-user Plugin
- Clone Test to Live
- Installer Menu Prompts
- Moodle Version Lookup
- Add-user Form
- Add-user Redirect Hook
- Add-user Privacy Provider
- Installer Output Helpers
- Project Docs & Container
- PHP Packages

## God Nodes (most connected - your core abstractions)
1. `moodle-update.sh script` - 10 edges
2. `install-moodle-proxmox.sh script` - 9 edges
3. `Copying a Test Moodle Container into a Live One` - 8 edges
4. `local/adduser Plugin` - 7 edges
5. `upgrade_moodle()` - 6 edges
6. `step()` - 5 edges
7. `step()` - 5 edges
8. `moodle_php()` - 5 edges
9. `MariaDB` - 5 edges
10. `$CFG->wwwroot Live Address` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Separate MariaDB Encryption Key Folder` --conceptually_related_to--> `MariaDB`  [INFERRED]
  docs/clone-to-live.md → README.md
- `mdl_enrol.enrolperiod` --references--> `MariaDB`  [INFERRED]
  docs/course-durations.md → README.md
- `$CFG->wwwroot Live Address` --references--> `Nginx Proxy Manager`  [EXTRACTED]
  docs/clone-to-live.md → README.md
- `$CFG->wwwroot Live Address` --references--> `$CFG->sslproxy`  [EXTRACTED]
  docs/clone-to-live.md → README.md
- `mdl_enrol.enrolperiod` --calls--> `purge_caches.php`  [EXTRACTED]
  docs/course-durations.md → docs/clone-to-live.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Test-to-live clone flow** — docs_clone_to_live_pct_clone_full, docs_clone_to_live_mariadb_encryption_key_folder, docs_clone_to_live_network_static_ip, docs_clone_to_live_wwwroot, docs_clone_to_live_divertallemailsto, docs_clone_to_live_proxmox_backup_job, docs_clone_to_live_verification_checks [EXTRACTED 1.00]
- **Enrolment end-date determination** — readme_local_adduser_plugin, docs_course_durations_default_enrolment_duration, docs_course_durations_mdl_enrol_enrolperiod [INFERRED 0.85]
- **Moodle Server Stack** — readme_moodle, readme_php, readme_mariadb, readme_apache, readme_proxmox_lxc_container [EXTRACTED 1.00]
- **Add User Flow** — readme_local_adduser_plugin, readme_required_id_number, readme_course_enrolment, readme_enrolment_end_date, readme_welcome_email [EXTRACTED 1.00]
- **Safe Update Flow** — readme_update_command, moodle_update, readme_maintenance_mode_backup, readme_config_php [EXTRACTED 1.00]

## Communities (17 total, 8 thin omitted)

### Community 0 - "Moodle Upgrade and Rollback"
Cohesion: 0.16
Nodes (19): ask(), backup(), moodle_checks(), moodle_info(), moodle_php(), msg_error(), msg_info(), msg_ok() (+11 more)

### Community 1 - "Container Installer Flow"
Cohesion: 0.13
Nodes (8): Advanced Settings, Apache, Default Settings, Install Log (/var/log/moodle-install-<date>.log), /root/moodle-credentials.txt, Moodle Cron Job, Proxmox VE Community Scripts, update Command

### Community 2 - "Reverse Proxy & Enrolment"
Cohesion: 0.22
Nodes (10): purge_caches.php, $CFG->wwwroot Live Address, Class of Business Courses (COB*, 90 days), Course Enrolment Durations (Live Site), CPD and Other Courses (30 days), Default Enrolment Duration, mdl_enrol.enrolperiod, config.php (+2 more)

### Community 3 - "Moodle Stack and Add-user Plugin"
Cohesion: 0.22
Nodes (9): Enrol in Courses (manual enrolment), Enrolment Ends, environment.xml, local/adduser Plugin, MariaDB, Moodle, Required Unique ID Number, admin/cli/upgrade.php (+1 more)

### Community 4 - "Clone Test to Live"
Cohesion: 0.28
Nodes (9): $CFG->divertallemailsto on Test Site, Separate MariaDB Encryption Key Folder, mp0 Encryption Key Bind Mount, Live Container Network / Static IP, pct clone --full, Copying a Test Moodle Container into a Live One, Proxmox Backup Job, Moodle Site Re-registration (+1 more)

### Community 5 - "Installer Menu Prompts"
Cohesion: 0.47
Nodes (6): exit_script(), input(), oops(), password(), install-moodle-proxmox.sh script, valid_ipv4()

### Community 6 - "Moodle Version Lookup"
Cohesion: 0.47
Nodes (4): branch_of_version(), mariadb_min(), moodle_newest_release(), moodle-versions.sh script

### Community 10 - "Installer Output Helpers"
Cohesion: 0.50
Nodes (4): msg_error(), msg_info(), msg_ok(), step()

### Community 11 - "Project Docs & Container"
Cohesion: 0.67
Nodes (3): docs/clone-to-live.md, moodle-proxmox-installer, Proxmox LXC Container (Ubuntu 24.04)

## Knowledge Gaps
- **18 isolated node(s):** `Live Container Network / Static IP`, `Proxmox Backup Job`, `Moodle Site Re-registration`, `Class of Business Courses (COB*, 90 days)`, `CPD and Other Courses (30 days)` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 42 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MariaDB` connect `Moodle Stack and Add-user Plugin` to `Moodle Upgrade and Rollback`, `Container Installer Flow`, `Reverse Proxy & Enrolment`, `Clone Test to Live`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **What connects `Live Container Network / Static IP`, `Proxmox Backup Job`, `Moodle Site Re-registration` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Container Installer Flow` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Why does `Copying a Test Moodle Container into a Live One` connect `Clone Test to Live` to `Container Installer Flow`, `Reverse Proxy & Enrolment`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `local/adduser Plugin` connect `Moodle Stack and Add-user Plugin` to `Container Installer Flow`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._