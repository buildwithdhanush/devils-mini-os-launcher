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


section "Proot app install dispatch and architecture mismatch confirmation"
SBOX_INSTALL="$(new_sandbox)"
printf '%s\n' 'compatible|Compatible App|dev-proot|Fixture|git|aarch64|any' 'incompatible|Incompatible App|dev-proot|Fixture|git|x86_64|any' > "${SBOX_INSTALL}/usr/opt/devils-minios/data/proot_apps.db"
out="$(run_module "${SBOX_INSTALL}" proot_apps '
    DEVILS_MINIOS_ARCH=aarch64
    DEVILS_MINIOS_STATE[primary_distro]=ubuntu
    _prompt_default() { case "$1" in App\ id*) printf "compatible";; Target*) printf "ubuntu";; esac; }
    check_storage_threshold() { return 0; }
    save_state() { return 0; }
    install_proot_package() { printf "INSTALL:%s:%s\n" "$1" "$2"; return 0; }
    _proot_apps_install
')"
assert_contains "compatible Proot app reaches install_proot_package" "${out}" "INSTALL:ubuntu:git"

out="$(run_module "${SBOX_INSTALL}" proot_apps '
    DEVILS_MINIOS_ARCH=aarch64
    _prompt_default() { case "$1" in App\ id*) printf "incompatible";; Target*) printf "ubuntu";; esac; }
    _confirm() { printf "CONFIRM:%s\n" "$1"; return 1; }
    check_storage_threshold() { return 0; }
    install_proot_package() { printf "INSTALL_SHOULD_NOT_RUN\n"; return 0; }
    _proot_apps_install
    printf "mismatch_rc=%s\n" "$?"
')"
assert_contains "architecture mismatch requires explicit confirmation" "${out}" "CONFIRM:Install anyway despite the architecture mismatch"
assert_not_contains "declined architecture mismatch does not execute the install" "${out}" "INSTALL_SHOULD_NOT_RUN"

print_summary "test_proot_apps.sh"
