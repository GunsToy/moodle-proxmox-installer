# Graph Report - moodle-proxmox-installer  (2026-11-06)

## Corpus Check
- 10 files · ~8,068 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 100 nodes · 141 edges · 13 communities (6 shown, 7 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.81)
- Token cost: 65,354 input · 0 output

## Community Hubs (Navigation)
- Container Installer Flow (0)
- Update Command Steps
- Container Installer Flow (2)
- Moodle Stack and Add-user Plugin (3)
- Moodle Stack and Add-user Plugin (4)
- moodle-versions.sh
- Add-user Form
- Add-user Redirect Hook
- Add-user Privacy Provider

## God Nodes (most connected - your core abstractions)
1. `moodle-update.sh script` - 10 edges
2. `install-moodle-proxmox.sh script` - 9 edges
3. `Copying a Test Moodle Container into a Live One` - 9 edges
4. `upgrade_moodle()` - 6 edges
5. `Runtime Version Lookup` - 6 edges
6. `step()` - 5 edges
7. `step()` - 5 edges
8. `moodle_php()` - 5 edges
9. `local/adduser Plugin` - 5 edges
10. `exit_script()` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Separate MariaDB Encryption Key Folder` --conceptually_related_to--> `MariaDB 11.4`  [INFERRED]
  docs/clone-to-live.md → README.md
- `moodle-proxmox-installer` --references--> `Copying a Test Moodle Container into a Live One`  [EXTRACTED]
  README.md → docs/clone-to-live.md
- `mdl_enrol.enrolperiod` --references--> `MariaDB 11.4`  [INFERRED]
  docs/course-durations.md → README.md
- `Live Site Verification Checks` --references--> `Moodle Cron Job`  [INFERRED]
  docs/clone-to-live.md → README.md
- `Proxmox Backup Job` --conceptually_related_to--> `/var/moodledata`  [INFERRED]
  docs/clone-to-live.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Test-to-live clone flow** — docs_clone_to_live_pct_clone_full, docs_clone_to_live_mariadb_encryption_key_folder, docs_clone_to_live_network_static_ip, docs_clone_to_live_wwwroot, docs_clone_to_live_divertallemailsto, docs_clone_to_live_proxmox_backup_job, docs_clone_to_live_verification_checks [EXTRACTED 1.00]
- **Enrolment end-date determination** — readme_local_adduser_plugin, readme_enrolment_ends, docs_course_durations_default_enrolment_duration, docs_course_durations_mdl_enrol_enrolperiod, readme_manual_enrolment [INFERRED 0.85]
- **Moodle stack version resolution** — readme_runtime_version_lookup, readme_moodle, readme_php, readme_mariadb, moodle_update [INFERRED 0.85]

## Communities (13 total, 7 thin omitted)

### Community 0 - "Container Installer Flow (0)"
Cohesion: 0.15
Nodes (16): exit_script(), input(), msg_error(), msg_info(), msg_ok(), oops(), password(), install-moodle-proxmox.sh script (+8 more)

### Community 1 - "Update Command Steps"
Cohesion: 0.18
Nodes (18): ask(), backup(), moodle_checks(), moodle_info(), moodle_php(), msg_error(), msg_info(), msg_ok() (+10 more)

### Community 2 - "Container Installer Flow (2)"
Cohesion: 0.18
Nodes (12): $CFG->divertallemailsto on Test Site, Separate MariaDB Encryption Key Folder, mp0 Encryption Key Bind Mount, Live Container Network / Static IP, pct clone --full, Copying a Test Moodle Container into a Live One, Proxmox Backup Job, Moodle Site Re-registration (+4 more)

### Community 3 - "Moodle Stack and Add-user Plugin (3)"
Cohesion: 0.20
Nodes (10): purge_caches.php, $CFG->wwwroot Live Address, mdl_enrol.enrolperiod, Moodle environment.xml, MariaDB 11.4, Moodle (5.3.0), Nginx Proxy Manager, ondrej/php PPA (+2 more)

### Community 4 - "Moodle Stack and Add-user Plugin (4)"
Cohesion: 0.25
Nodes (8): Class of Business Courses (COB*, 90 days), Course Enrolment Durations (Live Site), CPD and Other Courses (30 days), Default Enrolment Duration, Enrolment Ends Option, local/adduser Plugin, Manual Enrolment, Welcome Email (local_adduser welcomeemail string)

### Community 5 - "moodle-versions.sh"
Cohesion: 0.47
Nodes (4): branch_of_version(), mariadb_min(), moodle_newest_release(), moodle-versions.sh script

## Knowledge Gaps
- **15 isolated node(s):** `PATH`, `Proxmox LXC Container (Ubuntu 24.04)`, `Default Settings (2 cores, 4 GB RAM, 20 GB disk, DHCP vmbr0)`, `Advanced Settings`, `ondrej/php PPA` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 39 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Runtime Version Lookup` connect `Moodle Stack and Add-user Plugin (3)` to `Container Installer Flow (0)`, `Update Command Steps`?**
  _High betweenness centrality (0.211) - this node is a cross-community bridge._
- **What connects `PATH`, `Proxmox LXC Container (Ubuntu 24.04)`, `Default Settings (2 cores, 4 GB RAM, 20 GB disk, DHCP vmbr0)` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Container Installer Flow (0)` be split into smaller, more focused modules?**
  _Cohesion score 0.1471861471861472 - nodes in this community are weakly interconnected._
- **Why does `Copying a Test Moodle Container into a Live One` connect `Container Installer Flow (2)` to `Container Installer Flow (0)`, `Moodle Stack and Add-user Plugin (3)`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Why does `MariaDB 11.4` connect `Moodle Stack and Add-user Plugin (3)` to `Update Command Steps`, `Container Installer Flow (2)`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._