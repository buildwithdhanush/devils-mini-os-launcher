#!/usr/bin/env bash
# test_workspace.sh - PRD §43.1: Workspace confinement to
# $HOME/devils-minios/workspaces/ (D3).
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

section "default workspace root is under HOME/devils-minios/workspaces"
out="$(run_core "${SBOX}" '
    printf "root=%s\n" "${DEVILS_MINIOS_WORKSPACE_ROOT}"
')"
assert_contains "workspace root uses dedicated path" "${out}" "devils-minios/workspaces"

section "workspace path validation rejects traversal"
out="$(run_core "${SBOX}" '
    validate_path "${HOME}/devils-minios/workspaces/../escape" && printf "traversal=allowed\n" || printf "traversal=blocked\n"
    validate_path "${HOME}/devils-minios/workspaces/ok-project" && printf "ok=allowed\n" || printf "ok=blocked\n"
')"
assert_contains "path traversal outside workspace is blocked" "${out}" "traversal=blocked"
assert_contains "in-workspace path is allowed" "${out}" "ok=allowed"

section "external storage never an execution workspace"
out="$(run_core "${SBOX}" '
    is_external_storage_path "/sdcard/workspaces/foo" && printf "sdcard=external\n" || printf "sdcard=internal\n"
    assert_execution_path_allowed "/sdcard/workspaces/foo" && printf "exec=allowed\n" || printf "exec=blocked\n"
')"
assert_contains "sdcard detected as external" "${out}" "sdcard=external"
assert_contains "external storage execution blocked" "${out}" "exec=blocked"

section "workspace delete: name is sanitized/grammar-checked, same as create (regression)"
out="$(run_module "${SBOX}" "workspace" '
    printf "sneaky/../../escape\ny\n" | _workspace_delete >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "delete rejects a non-grammar-conforming workspace name before it ever reaches validate_path" "${out}" "rc=2"

section "workspace delete: actually removes an existing workspace on confirmation"
out="$(run_module "${SBOX}" "workspace" '
    mkdir -p "${DEVILS_MINIOS_WORKSPACE_ROOT}/gone-soon"
    printf "gone-soon\ny\n" | _workspace_delete >/dev/null 2>&1
    [[ -d "${DEVILS_MINIOS_WORKSPACE_ROOT}/gone-soon" ]] && printf "still_exists=yes\n" || printf "still_exists=no\n"
')"
assert_contains "confirmed delete removes the workspace directory" "${out}" "still_exists=no"

section "workspace module loads"
out="$(run_module "${SBOX}" "workspace" '
    type workspace_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "workspace_menu is defined" "${out}" "menu=ok"

section "PRD-22.1-07: validate_path() exports the resolved path when a base_dir is given"
out="$(run_core "${SBOX}" '
    want="${HOME}/devils-minios/workspaces/ok-project"
    validate_path "${want}" "${HOME}/devils-minios/workspaces" \
        && { [[ "${DEVILS_MINIOS_PATH_RESOLVED}" == "${want}" ]] && printf "resolved=match\n" || printf "resolved=mismatch:%s\n" "${DEVILS_MINIOS_PATH_RESOLVED}"; } \
        || printf "resolved=<unset>\n"
    validate_path "relative/no-base-dir" >/dev/null 2>&1
    printf "no_base_dir_resolved=[%s]\n" "${DEVILS_MINIOS_PATH_RESOLVED}"
')"
assert_contains "resolved path is the confined, canonicalized location" "${out}" "resolved=match"
assert_contains "no base_dir means no resolution is claimed (empty, not a guess)" "${out}" "no_base_dir_resolved=[]"

section "PRD-22.1-07: create/delete operate on the resolved path, not just validate it (regression)"
out="$(run_module "${SBOX}" "workspace" '
    printf "resolved-project\n" | _workspace_create >/dev/null 2>&1
    [[ -d "${DEVILS_MINIOS_WORKSPACE_ROOT}/resolved-project" ]] && printf "create_landed=yes\n" || printf "create_landed=no\n"
    printf "resolved-project\ny\n" | _workspace_delete >/dev/null 2>&1
    [[ -d "${DEVILS_MINIOS_WORKSPACE_ROOT}/resolved-project" ]] && printf "still_exists=yes\n" || printf "still_exists=no\n"
')"
assert_contains "workspace created via the resolved path lands at the expected, unchanged location" "${out}" "create_landed=yes"
assert_contains "workspace deleted via the resolved path is actually gone" "${out}" "still_exists=no"

section "PRD §22.1 step 6: workspace create refuses to land on an existing symlink"
out="$(run_module "${SBOX}" "workspace" '
    mkdir -p "${DEVILS_MINIOS_WORKSPACE_ROOT}"
    ln -s /tmp "${DEVILS_MINIOS_WORKSPACE_ROOT}/symlinked-name"
    printf "symlinked-name\nblank\n" | _workspace_create >/dev/null 2>&1
    printf "rc=%s\n" "$?"
    [[ -L "${DEVILS_MINIOS_WORKSPACE_ROOT}/symlinked-name" ]] && printf "still_symlink=yes\n" || printf "still_symlink=no\n"
')"
assert_contains "creating a workspace over an existing symlink is refused (E434)" "${out}" "rc=2"
assert_contains "the existing symlink is left untouched, not written through" "${out}" "still_symlink=yes"

print_summary "test_workspace.sh"
