# Devil's Mini OS Launcher - Test Suite Report

- Generated: 2026-10-01T01:19:24Z (started 2026-10-01T01:19:12Z)
- Generator: `test/test_report_generator.sh`
- Scope: the other 18 of the 19 mandatory test files (§43.1); this file's own
  pass/fail status (below the table) is reported separately by `test/run_all.sh`.

## Summary

| Metric | Value |
|---|---|
| Test files run | 18 |
| Test files passed | 18 |
| Test files failed | 0 |
| Test files missing | 0 |
| Assertions run | 853 |
| Assertions passed | 853 |
| Assertions failed | 0 |
| Overall status | PASS |

## Per-file results

| Test file | Status | Run | Passed | Failed |
|---|---|---|---|---|
| test_core.sh | PASS | 130 | 130 | 0 |
| test_utils.sh | PASS | 152 | 152 | 0 |
| test_security.sh | PASS | 136 | 136 | 0 |
| test_linux_env.sh | PASS | 48 | 48 | 0 |
| test_file_mgr.sh | PASS | 20 | 20 | 0 |
| test_termux_apps.sh | PASS | 9 | 9 | 0 |
| test_proot_apps.sh | PASS | 10 | 10 | 0 |
| test_android_tools.sh | PASS | 5 | 5 | 0 |
| test_workspace.sh | PASS | 14 | 14 | 0 |
| test_health_check.sh | PASS | 18 | 18 | 0 |
| test_log_viewer.sh | PASS | 4 | 4 | 0 |
| test_customize.sh | PASS | 14 | 14 | 0 |
| test_system_tools.sh | PASS | 5 | 5 | 0 |
| test_system_info.sh | PASS | 15 | 15 | 0 |
| test_update_all.sh | PASS | 94 | 94 | 0 |
| test_settings.sh | PASS | 51 | 51 | 0 |
| test_integration.sh | PASS | 100 | 100 | 0 |
| test_install.sh | PASS | 28 | 28 | 0 |

## Complete output

Full per-assertion output for each file is produced by `bash test/run_all.sh`
and is not duplicated here; this report captures the aggregate status plus
per-file pass/fail counts for archival (§A-6, §43.1).
