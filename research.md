---
layout: page
title: Research
permalink: /research/
---

CVEs, vulnerability writeups, and tooling.

## CVEs

Reported vulnerabilities with published advisories.

| CVE | Target | Class | CVSS | Advisory |
|-----|--------|-------|------|----------|
| CVE-2026-48105 | Arc Enterprise (Basekick Labs) | Cluster FSM accepts arbitrary file paths → cluster-wide path-traversal worm primitive | Critical | [GHSA-f85q-mvg8-qf37](https://github.com/Basekick-Labs/arc/security/advisories/GHSA-f85q-mvg8-qf37) |
| CVE-2026-48106 | Arc Enterprise (Basekick Labs) | Cluster replication accepts unauthenticated `MsgReplicateSync` → cluster-wide data injection | High | [GHSA-wfgr-8x84-22q7](https://github.com/Basekick-Labs/arc/security/advisories/GHSA-wfgr-8x84-22q7) |
| CVE-2026-47735 | Arc (Basekick Labs) | Authenticated arbitrary local-file read via DuckDB I/O functions, bypasses RBAC | High | [GHSA-p2j4-c4g6-rpf5](https://github.com/Basekick-Labs/arc/security/advisories/GHSA-p2j4-c4g6-rpf5) |
| CVE-2026-48050 | Arc (Basekick Labs) | Unauthenticated `pprof` endpoints → runtime state leak + CPU-burn DoS | Moderate | [GHSA-j93g-rp6m-j32m](https://github.com/Basekick-Labs/arc/security/advisories/GHSA-j93g-rp6m-j32m) |
| CVE-2026-6959 | HashiCorp Nomad / Nomad Enterprise | Symlink attack → arbitrary file read/write on client host | 6.0 Medium | [HCSEC-2026-14](https://discuss.hashicorp.com/t/hcsec-2026-14-nomad-arbitrary-file-read-write-on-client-host-through-symlink-attack/77416) |
| CVE-2026-8052 | HashiCorp Nomad exec2 task driver | Symlink attack → arbitrary file read/write on client host | 6.0 Medium | [HCSEC-2026-13](https://discuss.hashicorp.com/t/hcsec-2026-13-nomads-exec2-task-driver-vulnerable-to-arbitrary-file-read-write-on-client-host-through-symlink-attack/77415) |
| CVE-2026-27965 | Vitess vtbackup | OS command injection → RCE | 8.4 High | [GHSA-8g8j-r87h-p36x](https://github.com/vitessio/vitess/security/advisories/GHSA-8g8j-r87h-p36x) |
| CVE-2026-27969 | Vitess vtbackup | Path traversal → arbitrary file write | 9.3 Critical | [GHSA-r492-hjgh-c9gw](https://github.com/vitessio/vitess/security/advisories/GHSA-r492-hjgh-c9gw) |
| CVE-2025-63701 | Advantech TP-3250 printer driver | Heap corruption via DocumentPropertiesW | 6.8 Medium | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2025-63701) |
| — | Advantech TP-3250 printer driver | Heap corruption via monochrome blit (DrvRender) | — | advisory pending |

Pending disclosure: DragonflyDB Issues (reported May 2026).

## Writeups

- [HashiCorp Nomad FIFO symlink attack (CVE-2026-6959, CVE-2026-8052)](/security/2026/05/18/HashiCorp-Nomad-FIFO-symlink-attack/)
- [RCE and arbitrary file write in Vitess vtbackup via untrusted MANIFEST fields](/security/2026/05/18/RCE-and-arbitrary-file-write-in-Vitess-vtbackup-via-untrusted-MANIFEST-fields/)
- [Heap Corruption in Advantech TP-3250 Printer Driver (CVE-2025-63701)](/security/2025/10/08/Heap-Corruption-in-Advantech-TP-3250-Printer-Driver/)
- [Advantech Printer Driver: Heap Corruption via Monochrome Blit Function](/security/2025/10/09/Multiple-Expliots-in-Advantech-Printer-Driver/)
- [The Hunt for POS Drivers Continues: Your Drivers Are in Another Castle](/security/2025/12/15/The-Hunt-for-POS-Drivers-Continues-Your-Drivers-Are-in-Another-Castle/)

## Tooling

Bug bounty and recon tooling, built around my bounty workflow.

- [bugbounty_image](https://github.com/NeuroWinter/bugbounty_image) — Docker image with my recon stack. Fork as you wish.
- [lab-scripts](https://github.com/NeuroWinter/lab-scripts) — Disk imaging and forensics scripts from the POS driver hunting work.
