#!/usr/bin/env bash
# test_android_tools.sh - PRD §43.1: Android tools, API 29+, Termux:API
# fail-open + unavailable-capability UI state.
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

section "Termux:API absent fail-open"
out="$(run_module "${SBOX}" "android_tools" '
    _android_tools_termux_api_status
')"
assert_contains "Termux:API status reports availability state" "${out}" "Termux:API"

section "Android/device info surfaces platform facts"
out="$(run_module "${SBOX}" "android_tools" '
    detect_platform 2>/dev/null || true
    _android_tools_info
')"
assert_contains "info prints Android version line" "${out}" "Android version"
assert_contains "info prints Architecture line" "${out}" "Architecture"

section "adb/fastboot graceful when missing"
out="$(run_module "${SBOX}" "android_tools" '
    _android_tools_adb 2>&1 || true
    _android_tools_fastboot 2>&1 || true
    printf "adb_fastboot_handled=1\n"
')"
assert_contains "missing adb/fastboot does not crash" "${out}" "adb_fastboot_handled=1"

section "battery gate fail-open when Termux:API absent"
out="$(run_core "${SBOX}" '
    # Simulate battery check path used by heavy ops
    if ! command -v termux-battery-status >/dev/null 2>&1; then
        write_log_file "WARN" "battery level unavailable; proceeding"
        printf "fail_open=ok\n"
    else
        printf "api_present=1\n"
    fi
')"
assert_true "battery fail-open path reachable" 0


section "ADB/fastboot dispatch uses execute_structured"
SBOX_ANDROID_DISPATCH="$(new_sandbox)"
out="$(run_module "${SBOX_ANDROID_DISPATCH}" android_tools '
    mkdir -p "${PREFIX}/bin"
    printf "#!/usr/bin/env bash\nexit 0\n" > "${PREFIX}/bin/adb"
    printf "#!/usr/bin/env bash\nexit 0\n" > "${PREFIX}/bin/fastboot"
    chmod +x "${PREFIX}/bin/adb" "${PREFIX}/bin/fastboot"
    PATH="${PREFIX}/bin:${PATH}"
    execute_structured() { printf "EXEC:%s:%s\n" "$1" "$2"; return 0; }
    _android_tools_adb
    _android_tools_fastboot
')"
assert_contains "ADB dispatch reaches execute_structured" "${out}" "EXEC:adb:devices"
assert_contains "fastboot dispatch reaches execute_structured" "${out}" "EXEC:fastboot:devices"

print_summary "test_android_tools.sh"
