# Android Run Evidence — ShellCheck Failure

Source: user-provided Termux console output and archived runner evidence, 25 October 2026.

- Run ID: `run-20261025T052825Z-18029`
- Archive tested: `devils-mini-os-launcher-PRD62-shellcheck-patch-2026-10-25.zip`
- SHA-256: `3684d00b9d6d791bb7ee9bddc583c8e60784cfaacf94a1b07b3fa459470ef930`
- Platform: Termux, Android 17 / API 37, `aarch64`.
- Manifest completeness passed with 135 static entries; 51 `.sh` files passed `bash -n`; structure, traceability, catalogs, security and CLI smoke checks passed.
- Mandatory suite passed in that run: 19/19 files and 918/918 assertions.
- ShellCheck 0.11.0 failed with two findings in that archive: `SC2016` at `test/test_report_generator.sh` line 100 and `SC2034` at `core/core_config.sh` line 427.
- Overall result was `AUTOMATED RESULT: FAIL`.

Do not assume those source lines or line numbers are unchanged in the current bundled source ZIP. Re-run against the exact current candidate and inspect current code.
