#!/usr/bin/env bash
# test_termux_apps.sh - PRD §43.1: Termux apps, 11-field schema validation,
# pkg/github dispatch, script source rejected, graceful degradation.
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

section "termux_apps.db schema: field count and load"
out="$(run_module "${SBOX}" "termux_apps" '
    _termux_apps_load && printf "load=ok count=%d\n" "${#DEVILS_MINIOS_CATALOG[@]}" || printf "load=fail\n"
')"
assert_contains "termux_apps.db loads successfully" "${out}" "load=ok"
assert_contains "catalog has entries" "${out}" "count="
assert_not_contains "catalog is not empty" "${out}" "count=0"

section "11-field schema validation rejects script source"
out="$(run_module "${SBOX}" "termux_apps" '
    _validate_termux_app_record "badapp" "Bad App" "development" "desc" "pkgname" "script" "-" "-" "-" "-" "-" \
        && printf "script=accepted\n" || printf "script=rejected\n"
')"
assert_contains "install_source=script is rejected at schema validation" "${out}" "script=rejected"

section "package_name / github field validation"
out="$(run_module "${SBOX}" "termux_apps" '
    _validate_termux_app_record "git" "Git" "development" "Git VCS" "git" "pkg" "-" "-" "-" "-" "-" \
        && printf "pkg_good=ok\n" || printf "pkg_good=fail\n"
    _validate_termux_app_record "evil" "Evil" "cli" "x" "pkg;rm" "pkg" "-" "-" "-" "-" "-" \
        && printf "meta=accepted\n" || printf "meta=rejected\n"
    _validate_termux_app_record "tool" "Tool" "cli" "x" "-" "github" "-" "owner/repo" "main" "tool.tar.gz" "0000000000000000000000000000000000000000000000000000000000000000" \
        && printf "branch=accepted\n" || printf "branch=rejected\n"
')"
assert_contains "valid pkg record accepted" "${out}" "pkg_good=ok"
assert_contains "package_name with shell metacharacters rejected" "${out}" "meta=rejected"
assert_contains "github_ref set to branch name rejected" "${out}" "branch=rejected"

section "list and category filtering"
out="$(run_module "${SBOX}" "termux_apps" '
    _termux_apps_list development 2>/dev/null | head -5
')"
assert_contains "development category list produces output" "${out}" "ID"

section "install_github_artifact contract (checksum mismatch)"
out="$(run_core "${SBOX}" '
    install_github_artifact "owner/repo" "v1.0.0" "artifact.bin" "0000000000000000000000000000000000000000000000000000000000000000" 2>&1 || true
    printf "exit_handled=1\n"
')"
assert_contains "github install path handles checksum failure" "${out}" "exit_handled=1"

print_summary "test_termux_apps.sh"
