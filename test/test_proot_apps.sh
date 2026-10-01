#!/usr/bin/env bash
# test_proot_apps.sh - PRD §43.1: Proot apps, 7-field schema, install_target
# grammar, architecture filtering, install_proot_package argv construction.
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

section "proot_apps.db schema load"
out="$(run_module "${SBOX}" "proot_apps" '
    _proot_apps_load && printf "load=ok count=%d\n" "${#DEVILS_MINIOS_CATALOG[@]}" || printf "load=fail\n"
')"
assert_contains "proot_apps.db loads" "${out}" "load=ok"
assert_contains "catalog non-empty" "${out}" "count="
assert_not_contains "catalog not zero" "${out}" "count=0"

section "install_target grammar validation"
out="$(run_core "${SBOX}" '
    _validate_proot_app_record "vim" "Vim" "utilities" "editor" "vim" "all" "any" \
        && printf "good=ok\n" || printf "good=fail\n"
    _validate_proot_app_record "evil" "Evil" "utilities" "x" "vim;rm" "all" "any" \
        && printf "meta=accepted\n" || printf "meta=rejected\n"
    _validate_proot_app_record "evil2" "Evil2" "utilities" "x" "vim&&true" "all" "any" \
        && printf "and=accepted\n" || printf "and=rejected\n"
')"
assert_contains "valid install_target accepted" "${out}" "good=ok"
assert_contains "install_target with semicolon rejected" "${out}" "meta=rejected"
assert_contains "install_target with && rejected" "${out}" "and=rejected"

section "architecture filtering"
out="$(run_module "${SBOX}" "proot_apps" '
    DEVILS_MINIOS_ARCH=aarch64
    _proot_apps_load || true
    printf "arch=%s catalog=%d\n" "${DEVILS_MINIOS_ARCH}" "${#DEVILS_MINIOS_CATALOG[@]}"
')"
assert_contains "architecture context set" "${out}" "arch=aarch64"

section "install_proot_package uses package_manager templates"
out="$(run_core "${SBOX}" '
    load_database "$(data_file_path proot_distros.db)" 7 _validate_distro_record true
    find_catalog_record "ubuntu" && printf "ubuntu_pm=%s\n" "${DEVILS_MINIOS_RECORD_FIELDS[6]}"
    find_catalog_record "archlinux" && printf "arch_pm=%s\n" "${DEVILS_MINIOS_RECORD_FIELDS[6]}"
    find_catalog_record "alpine" && printf "alpine_pm=%s\n" "${DEVILS_MINIOS_RECORD_FIELDS[6]}"
')"
assert_contains "ubuntu uses apt" "${out}" "ubuntu_pm=apt"
assert_contains "archlinux uses pacman" "${out}" "arch_pm=pacman"
assert_contains "alpine uses apk" "${out}" "alpine_pm=apk"

print_summary "test_proot_apps.sh"
