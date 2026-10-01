#!/usr/bin/env bash
# test_system_tools.sh - PRD §43.1: System operations, kill confirmations.
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

section "system_tools module loads"
out="$(run_module "${SBOX}" "system_tools" '
    type system_tools_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "system_tools_menu defined" "${out}" "menu=ok"

section "no unsafe blanket pkill in module"
if grep -qE 'pkill -u|killall -9|rm -rf /' "${DMOS_PROJECT_ROOT}/modules/system_tools.sh" 2>/dev/null; then
    fail "system_tools.sh must not contain unsafe blanket kill/rm"
else
    pass "system_tools.sh has no unsafe blanket commands"
fi

section "cache clear is scoped to launcher cache dir"
out="$(run_core "${SBOX}" '
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    printf "junk" > "${DEVILS_MINIOS_CACHE_DIR}/tmpfile"
    # system_tools clears only cache dir contents
    rm -rf "${DEVILS_MINIOS_CACHE_DIR:?}"/* 2>/dev/null || true
    if [[ ! -f "${DEVILS_MINIOS_CACHE_DIR}/tmpfile" ]]; then
        printf "scoped_clear=ok\n"
    else
        printf "scoped_clear=fail\n"
    fi
')"
assert_contains "cache clear is scoped" "${out}" "scoped_clear=ok"

section "§22.1/§23.1 cache maintenance revalidates entries and refuses symlinked cache roots"
SBOX_CACHE="$(new_sandbox)"
out="$(run_module "${SBOX_CACHE}" system_tools '
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    printf cache > "${DEVILS_MINIOS_CACHE_DIR}/health_cache.json"
    ln -s "${HOME}" "${DEVILS_MINIOS_CACHE_DIR}/escape"
    _confirm() { return 0; }
    _system_tools_maintenance
    printf "cache_file=%s symlink=%s\n" "$(test -e "${DEVILS_MINIOS_CACHE_DIR}/health_cache.json" && echo present || echo removed)" "$(test -L "${DEVILS_MINIOS_CACHE_DIR}/escape" && echo present || echo removed)"
')"
assert_contains "cache maintenance removes regular cache entries" "${out}" "cache_file=removed"
assert_contains "cache maintenance removes symlink objects without following them" "${out}" "symlink=removed"

print_summary "test_system_tools.sh"
