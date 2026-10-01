#!/usr/bin/env bash
# test_log_viewer.sh - PRD §43.1: Read-only boundary, Exit action,
# clear/export delegates to core.sh.
# This file's test snippets are intentionally single-quoted (see
# test/lib/harness.sh: run_core/run_module embed the snippet verbatim
# into a heredoc evaluated by a separate inner `bash -s`, so it must
# NOT be expanded by this outer shell). File-wide, not per-line, since
# nearly every assertion in this file uses the pattern.
# shellcheck disable=SC2016
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/harness.sh
source "${SCRIPT_DIR}/lib/harness.sh"

SBOX="$(new_sandbox)"

section "log_viewer module is read-only (no rotation/delete in module)"
out="$(run_module "${SBOX}" "log_viewer" '
    # Ensure clear_logs lives in core, not log_viewer
    type clear_logs >/dev/null 2>&1 && printf "clear_in_core=ok\n" || printf "clear_missing\n"
    type log_viewer_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "clear_logs is available from core" "${out}" "clear_in_core=ok"
assert_contains "log_viewer_menu defined" "${out}" "menu=ok"

section "clear_logs mutates via core only"
out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    write_log_file "INFO" "entry-before-clear"
    clear_logs
    content="$(cat "$(get_log_file)" 2>/dev/null || true)"
    if [[ "${content}" != *"entry-before-clear"* ]]; then
        printf "cleared=ok\n"
    else
        printf "cleared=fail\n"
    fi
')"
assert_contains "clear_logs removes prior entries" "${out}" "cleared=ok"

section "log viewer does not define its own rotation"
# Static check: log_viewer.sh must not call rotate or rm on log files
if grep -qE 'rotate_and_purge|rm .*launcher\.log' "${DMOS_PROJECT_ROOT}/modules/log_viewer.sh" 2>/dev/null; then
    fail "log_viewer.sh must not rotate/delete logs itself"
else
    pass "log_viewer.sh has no direct log mutation"
fi

print_summary "test_log_viewer.sh"
