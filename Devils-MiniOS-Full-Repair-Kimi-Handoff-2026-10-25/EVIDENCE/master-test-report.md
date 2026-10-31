# Devil's Mini OS Launcher — PRD-6.2 Master Test Report

- Started (UTC): `20261025T052825Z`
- Source ZIP: `/data/data/com.termux/files/home/storage/downloads/devils-mini-os-launcher-PRD62-shellcheck-patch-2026-10-25.zip`
- Expected ZIP SHA-256: `3684d00b9d6d791bb7ee9bddc583c8e60784cfaacf94a1b07b3fa459470ef930`
- Extracted source: `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/source/devils-mini-os-launcher-Testing`
- Device architecture: `aarch64`
- ShellCheck install explicitly approved: `NO`
- ShellCheck install status: `not required`
- Overall automated result: **FAIL**

| # | Check | Status | Exit code | Log |
|---:|---|---|---:|---|
| 1 | Target device / Termux / Android API preflight | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/01.log` |
| 2 | Archive SHA-256 matches the verified ZIP | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/02.log` |
| 3 | ZIP internal structure integrity | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/03.log` |
| 4 | Archive paths are safe and have the expected single root | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/04.log` |
| 5 | Extract source to a new private workspace | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/05.log` |
| 6 | SHA256SUMS integrity and manifest completeness | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/06.log` |
| 7 | Bash syntax: every .sh file in the source tree | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/07.log` |
| 8 | ShellCheck: every .sh file in the source tree | **FAIL** | 1 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/08.log` |
| 9 | PRD structure: 14 modules, 19 tests, docs, no future_plans, line limits | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/09.log` |
| 10 | PRD §43.5 traceability schema, IDs, fields, owners, statuses and totals | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/10.log` |
| 11 | Catalog cardinality: desktops/proot apps/Termux apps | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/11.log` |
| 12 | Security scan: forbidden dynamic shell/pipeline constructs | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/12.log` |
| 13 | CLI smoke: --version and --help | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/13.log` |
| 14 | PRD §43.2: full mandatory test suite (19 files; bounded runtime) | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/14.log` |
| 15 | Post-suite SHA256SUMS integrity | **PASS** | 0 | `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs/15.log` |

## Release-gate limits of this run

- This run tests only the architecture of the current device; the PRD requires both `aarch64` and `x86_64` evidence before release.
- PRD-required manual Android acceptance and review of requirement-level traceability are not replaced by this automated run.
- A passing automated result is not a v1.0.0 FINAL/release approval.

## Evidence files

- Console log: `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/master-console.log`
- Individual check logs: `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/logs`
- Extracted test copy: `/data/data/com.termux/files/home/devils-minios-test-runs/run-20261025T052825Z-18029/source/devils-mini-os-launcher-Testing`
