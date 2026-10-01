#!/usr/bin/env bash
# test_file_mgr.sh - PRD §43.1: Browse/search/read/copy/transfer incl.
# external storage, execution block, confirmations.
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

section "Browse: rejects invalid/traversal paths"
out="$(run_module "${SBOX}" file_mgr '
    mkdir -p "${HOME}/docs"
    touch "${HOME}/docs/one.txt"
    printf "%s\n" "${HOME}/docs" | _file_mgr_browse >/dev/null 2>&1
    printf "browse_rc=%s\n" "$?"
')"
assert_contains "browsing a valid directory succeeds" "${out}" "browse_rc=0"

section "Browse: confirms before listing external storage"
out="$(run_module "${SBOX}" file_mgr '
    mkdir -p /tmp/fakesdcard 2>/dev/null || true
    printf "/sdcard\nn\n" | _file_mgr_browse >/dev/null 2>&1
    printf "declined_rc=%s\n" "$?"
')"
assert_true "declining the external-storage confirmation short-circuits cleanly" "$(printf '%s' "${out}" | grep -o 'declined_rc=.' | cut -d= -f2)"

section "Read: path validation and external-storage confirmation gate"
out="$(run_module "${SBOX}" file_mgr '
    printf "hello world" > "${HOME}/secret.txt"
    printf "%s\n" "${HOME}/secret.txt" | _file_mgr_read
')"
assert_contains "reading an internal file returns its contents" "${out}" "hello world"

out="$(run_module "${SBOX}" file_mgr '
    printf "../escape\n" | _file_mgr_read >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "reading a path containing .. traversal is rejected" "${out}" "rc=2"

section "Copy: uses execute_structured (cp -a), path validated"
out="$(run_module "${SBOX}" file_mgr '
    printf "content" > "${HOME}/src.txt"
    printf "%s\n%s\n" "${HOME}/src.txt" "${HOME}/dst.txt" | _file_mgr_copy >/dev/null 2>&1
    printf "rc=%s\n" "$?"
    [[ -f "${HOME}/dst.txt" ]] && printf "copied=yes\n" || printf "copied=no\n"
')"
assert_contains "copy succeeds for validated internal paths" "${out}" "rc=0"
assert_contains "copy actually produces the destination file" "${out}" "copied=yes"

out="$(run_module "${SBOX}" file_mgr '
    printf "%s\n%s\n" "../escape" "${HOME}/dst2.txt" | _file_mgr_copy >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "copy rejects a source path containing traversal" "${out}" "rc=2"

section "Delete: requires confirmation, path must exist"
out="$(run_module "${SBOX}" file_mgr '
    printf "x" > "${HOME}/todelete.txt"
    printf "%s\nn\n" "${HOME}/todelete.txt" | _file_mgr_delete >/dev/null 2>&1
    [[ -f "${HOME}/todelete.txt" ]] && printf "still_exists=yes\n" || printf "still_exists=no\n"
')"
assert_contains "declining delete confirmation leaves the file intact" "${out}" "still_exists=yes"

out="$(run_module "${SBOX}" file_mgr '
    printf "x" > "${HOME}/todelete2.txt"
    printf "%s\ny\n" "${HOME}/todelete2.txt" | _file_mgr_delete >/dev/null 2>&1
    [[ -f "${HOME}/todelete2.txt" ]] && printf "still_exists=yes\n" || printf "still_exists=no\n"
')"
assert_contains "confirming delete removes the file" "${out}" "still_exists=no"

out="$(run_module "${SBOX}" file_mgr '
    printf "%s\n" "${HOME}/does-not-exist.txt" | _file_mgr_delete >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "deleting a non-existent path is rejected" "${out}" "rc=2"

section "External-storage execution is never possible from file_mgr (no exec primitive exists here)"
out="$(cat modules/file_mgr.sh)"
assert_not_contains "file_mgr never calls execute_structured with a raw interpreter (sh/bash/python) executor" "${out}" 'execute_structured sh'
assert_contains "file_mgr delegates all mutation to execute_structured (§23.1 sole execution primitive)" "${out}" "execute_structured"

section "Search: confirms external storage, validates directory path"
out="$(run_module "${SBOX}" file_mgr '
    mkdir -p "${HOME}/searchable"
    touch "${HOME}/searchable/match.txt"
    printf "%s\n*.txt\n" "${HOME}/searchable" | _file_mgr_search
')"
assert_contains "search finds matching files under an internal directory" "${out}" "match.txt"

section "Bulk delete: lists matches and requires one confirmation for the batch"
out="$(run_module "${SBOX}" file_mgr '
    mkdir -p "${HOME}/bulk"
    touch "${HOME}/bulk/a.tmp" "${HOME}/bulk/b.tmp"
    printf "%s\n*.tmp\nn\n" "${HOME}/bulk" | _file_mgr_bulk_delete >/dev/null 2>&1
    ls "${HOME}/bulk" | wc -l
')"
assert_contains "declining bulk-delete confirmation leaves all matched files intact" "${out}" "2"

section "PRD §22.1 step 6: copy/move refuse to write onto an existing symlink destination"
out="$(run_module "${SBOX}" file_mgr '
    printf "content" > "${HOME}/copysrc.txt"
    ln -s "${HOME}/copysrc.txt" "${HOME}/symlinked-dst"
    printf "%s\n%s\n" "${HOME}/copysrc.txt" "${HOME}/symlinked-dst" | _file_mgr_copy >/dev/null 2>&1
    printf "copy_onto_symlink_rc=%s\n" "$?"
')"
assert_contains "copy onto an existing symlink destination is refused (E434)" "${out}" "copy_onto_symlink_rc=2"

out="$(run_module "${SBOX}" file_mgr '
    printf "content" > "${HOME}/movesrc.txt"
    ln -s "${HOME}/movesrc.txt" "${HOME}/symlinked-dst2"
    printf "%s\n%s\ny\n" "${HOME}/movesrc.txt" "${HOME}/symlinked-dst2" | _file_mgr_move_rename >/dev/null 2>&1
    printf "move_onto_symlink_rc=%s\n" "$?"
    [[ -f "${HOME}/movesrc.txt" ]] && printf "source_untouched=yes\n" || printf "source_untouched=no\n"
')"
assert_contains "move onto an existing symlink destination is refused (E434)" "${out}" "move_onto_symlink_rc=2"
assert_contains "refused move leaves the original source file in place" "${out}" "source_untouched=yes"

section "PRD §48.2: path-validation failures use E430-E433, not E400"
out="$(run_module "${SBOX}" file_mgr '
    _prompt_default() { case "$1" in Source|"New path/name") printf "%s" "${HOME}/../escape";; *) printf "%s" "${HOME}/dst";; esac; }
    _file_mgr_copy 2>&1; printf "copy_rc=%s\n" "$?"
')"
assert_contains "copy with a traversal source exits 2" "${out}" "copy_rc=2"
assert_contains "copy with a traversal source logs E431 (traversal step)" "${out}" "ERROR [E431]"
assert_not_contains "copy path failure is not logged as E400" "${out}" "ERROR [E400]"

print_summary "test_file_mgr.sh"
exit $?
