# PRD-6.2 Gap Register — Baseline 2026-10-13

## Scope and evidence

This register records the current container baseline from `bash test/run_all.sh` and the focused `bash test/test_install.sh` run. Full raw output is preserved in `evidence/baseline-20261013/`. The supplied ZIP snapshot does not include `.git` metadata, so branch and working-tree status could not be established; no destructive Git operations were run. The normative PRD was retrieved from the user's Library copy, `PRD-6.2(20261001-000718).md`.

## Baseline failures and remediation status

| Failure | PRD requirement | Evidence | Classification | Priority |
|---|---|---|---|---|
| Clean sandbox installation exits 2 | PRD-30.2-001; §30 installation sequence steps 7–8; §30.5 manifest integrity | Baseline: `evidence/baseline-20261013/test_install.txt`; fix: `install.sh::_copy_files()` enumerates concrete staged files | **Fixed** — manifest validation no longer checks literal wildcard strings; active install includes `install.sh` | Resolved in container tests; Android acceptance pending |
| Clean installation does not create active `SHA256SUMS` | PRD-30.2-001; §30.2 requires installed manifest verification for installer, entry point, all 14 modules and data files | Baseline focused test; post-fix `test_install.sh` | **Fixed** — fresh install creates the active manifest and verifies all staged runtime files | Resolved in container tests; Android acceptance pending |
| `install.sh --verify` fails immediately after a clean install | PRD-30.2-001; §30.5 | Baseline focused test; post-fix immediate verification assertion | **Fixed** — immediate post-install verification exits 0 | Resolved in container tests; Android acceptance pending |

## Baseline reconciliation

The checked-in `data/reports/report.md` initially claimed 13 failed assertions across `test_core.sh`, `test_system_info.sh`, and `test_integration.sh`. The current harness run reproduced a different state: those files pass; `test_install.sh` has 3 failed assertions. The canonical report generator ran as part of `test/run_all.sh` and refreshed `data/reports/report.md` from current test output. Historical evidence under `evidence/` was preserved and not treated as current proof.

## Environment and verification limits

- Baseline `bash test/run_all.sh`: FAIL, exit 1; 18/19 mandatory test files passed, `test_install.sh` failed (3 assertions).
- Post-fix `bash test/test_install.sh`: PASS, exit 0; 30/30 assertions passed.
- Post-fix `bash test/run_all.sh`: PASS, exit 0; 19/19 mandatory files passed, 891/891 assertions passed.
- Bash 5.2.37 was available.
- ShellCheck was not found in the environment; ShellCheck verification is NOT RUN.
- Android/Termux hardware acceptance was NOT RUN in this container.
- Git status/branch inspection is NOT AVAILABLE because the supplied archive lacks `.git` metadata.

## Next action

Continue TASK-003's runtime/CLI/recovery review, then proceed through TASK-010. Container tests now cover the reproduced installer failure; real Termux acceptance remains outstanding.


## Current release blockers after remediation

- The current automated container suite passes, but the existing Android evidence from 2026-10-03 records a suite exit status of 1. Its generated manual checklist was not completed, so it does not establish MA-01…MA-11 acceptance.
- `PRD-20-001` remains **Not Verified**: the prescribed physical-device performance measurements have not been recorded.
- Traceability now has 240 unique requirement IDs with 13-column rows (197 Verified, 42 Partial, 1 Not Verified). This is improved section coverage, not proof that every normative sentence in PRD-6.2 has been mapped; the second consistency audit is still required.
- ShellCheck, actionlint, hosted GitHub Actions, aarch64/x86_64 release-matrix runs, release tarball/ZIP creation, and current-device manual acceptance remain NOT RUN.
