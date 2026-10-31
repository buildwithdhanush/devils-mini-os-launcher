# Baseline Source Fingerprint and Evidence Lineage

## Current source candidate in this kit

- File: `INPUTS/devils-mini-os-launcher-PRD62-repaired-2026-10-25.zip`
- SHA-256: `7153aa696970676b354ffea17a00cb039bd6931bed02d595701e9a66f60d5635`
- Archive integrity: verified during kit preparation (`unzip -tq` returned success).
- Important: these facts establish only input identity and ZIP integrity, not full test or ShellCheck success.

## Separate historical Android runs

| Run | Archive SHA-256 | Observed result | Correct interpretation |
|---|---|---|---|
| `run-20261025T103830Z-1872` | `cccfbc701540f6351c39e2fbcde02e0abd17b141143ad440aa44fcc5b802456e` | Failed check 6, manifest completeness; every listed manifest hash was OK; `data/reports/report.md` was extra. | Later tests did not execute in that run. |
| `run-20261025T052825Z-18029` | `3684d00b9d6d791bb7ee9bddc583c8e60784cfaacf94a1b07b3fa459470ef930` | ShellCheck 0.11.0 failed on `SC2016` and `SC2034`; 19/19 test files and 918/918 assertions passed; overall result FAIL. | The suite pass does not override ShellCheck failure; this is not the current candidate hash. |
| Older diagnostics (`EVIDENCE/SHELLCHECK-OLDER-BUILD-21-DIAGNOSTICS.log`) | Exact hash not proven in that log | 21 ShellCheck diagnostics. | Historical lead list only; confirm every finding against current source. |

## Final evidence required from Kimi

The final source ZIP must get a new SHA-256. The same exact final hash must be referenced in final test report metadata/logs and external delivery checksums. The final tests must run against a fresh extraction of that final ZIP after the embedded report and `SHA256SUMS` are final.
