#!/usr/bin/env bash
# test_system_info.sh - PRD §43.1: System information display.
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

section "system_info module loads"
out="$(run_module "${SBOX}" "system_info" '
    type system_info_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "system_info_menu defined" "${out}" "menu=ok"

section "system report surfaces required fields"
out="$(run_module "${SBOX}" "system_info" '
    detect_platform 2>/dev/null || true
    build_runtime_context 2>/dev/null || true
    _system_info_show 2>/dev/null || true
')"
assert_contains "reports architecture" "${out}" "Architecture"
assert_contains "reports Bash version" "${out}" "Bash version"
assert_contains "reports terminal width" "${out}" "Terminal width"

section "environment info shows install/config paths"
out="$(run_module "${SBOX}" "system_info" '
    _system_info_environment 2>/dev/null || true
')"
assert_contains "shows install dir" "${out}" "Install dir"
assert_contains "shows config dir" "${out}" "Config dir"
assert_contains "shows workspace root" "${out}" "Workspace root"

section "PRD §13.12-001: storage detail report"
out="$(run_module "${SBOX}" "system_info" '
    _system_info_storage_detail 2>/dev/null || true
')"
assert_contains "storage detail reports the HOME filesystem" "${out}" "Filesystem detail for"
assert_contains "storage detail reports launcher config/state/logs size" "${out}" "Launcher config/state/logs size"

section "PRD §13.12-001: system_info_menu dispatches all three read-only reports and returns"
out="$(run_module "${SBOX}" "system_info" '
    detect_platform 2>/dev/null || true
    build_runtime_context 2>/dev/null || true
    system_info_menu >/tmp/dmos_sysinfo_out.$$ 2>&1 <<< "1
y
2
y
3
y
0"
    rc=$?
    printf "menu_rc=%s\n" "${rc}"
    grep -c "System Info" /tmp/dmos_sysinfo_out.$$ | { read -r n; printf "reentries=%s\n" "${n}"; }
    grep -q "Architecture" /tmp/dmos_sysinfo_out.$$ && printf "showed_full_report=yes\n" || printf "showed_full_report=no\n"
    grep -q "Filesystem detail" /tmp/dmos_sysinfo_out.$$ && printf "showed_storage_detail=yes\n" || printf "showed_storage_detail=no\n"
    grep -q "Environment" /tmp/dmos_sysinfo_out.$$ && printf "showed_environment=yes\n" || printf "showed_environment=no\n"
    rm -f /tmp/dmos_sysinfo_out.$$
')"
assert_contains "system_info_menu returns cleanly (choice 0)" "${out}" "menu_rc=0"
assert_contains "menu choice 1 shows the full system report" "${out}" "showed_full_report=yes"
assert_contains "menu choice 2 shows storage details" "${out}" "showed_storage_detail=yes"
assert_contains "menu choice 3 shows environment info" "${out}" "showed_environment=yes"

section "PRD §13.12-001: system_info is read-only (no config/state mutation)"
out="$(run_module "${SBOX}" "system_info" '
    detect_platform 2>/dev/null || true
    build_runtime_context 2>/dev/null || true
    load_default_config
    load_state 2>/dev/null || default_state
    cfg_before="$(declare -p DEVILS_MINIOS_CONFIG)"
    state_before="$(declare -p DEVILS_MINIOS_STATE)"
    system_info_menu >/dev/null 2>&1 <<< "1
y
2
y
3
y
0"
    cfg_after="$(declare -p DEVILS_MINIOS_CONFIG)"
    state_after="$(declare -p DEVILS_MINIOS_STATE)"
    [[ "${cfg_before}" == "${cfg_after}" ]] && printf "config_unchanged=yes\n" || printf "config_unchanged=no\n"
    [[ "${state_before}" == "${state_after}" ]] && printf "state_unchanged=yes\n" || printf "state_unchanged=no\n"
')"
assert_contains "running every system_info report leaves config untouched" "${out}" "config_unchanged=yes"
assert_contains "running every system_info report leaves state untouched" "${out}" "state_unchanged=yes"

print_summary "test_system_info.sh"
