# Android Run Evidence — Manifest Failure

Source: user-provided Termux console output, primary device, 25 October 2026.

- Run ID: `run-20261025T103830Z-1872`
- Archive tested: `devils-mini-os-launcher-PRD62-shellcheck-fix-2026-10-25.zip`
- SHA-256: `cccfbc701540f6351c39e2fbcde02e0abd17b141143ad440aa44fcc5b802456e`
- Platform: Termux, Android 17 / API 37, `aarch64`.
- ZIP hash and ZIP integrity passed. Each recorded `SHA256SUMS` entry passed.
- Check 6 failed: manifest completeness mismatch. The user output identified `data/reports/report.md` as the extra file.
- Result: `AUTOMATED RESULT: FAIL`; checks after this failure did not execute. Do not represent this run as a suite or ShellCheck result.

This is evidence for that archive hash only, not proof about the source candidate bundled in `INPUTS/`.
