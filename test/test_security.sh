#!/usr/bin/env bash
# test_security.sh - PRD §43.1: Path traversal, dangerous patterns,
# external-storage execution block vs allowed file access, confirmation
# gates, rootless policy, execute_structured() denylist rejection (§23.1),
# forbidden-token rejection for install_target/startup_args/GitHub fields
# (§18.2-§18.4).
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
section "assert_execution_path_allowed: traversal + external storage"
out="$(run_core "${SBOX}" '
    assert_execution_path_allowed "${HOME}/safe/bin" && printf "internal=allowed\n" || printf "internal=blocked\n"
    assert_execution_path_allowed "/sdcard/some/bin" && printf "sdcard=allowed\n" || printf "sdcard=blocked\n"
    assert_execution_path_allowed "/storage/emulated/0/bin" && printf "storage=allowed\n" || printf "storage=blocked\n"
    assert_execution_path_allowed "${HOME}/../escape" && printf "traversal=allowed\n" || printf "traversal=blocked\n"
')"
assert_contains "internal path execution is allowed" "${out}" "internal=allowed"
assert_contains "external storage (/sdcard) execution is blocked" "${out}" "sdcard=blocked"
assert_contains "external storage (/storage/emulated) execution is blocked" "${out}" "storage=blocked"
assert_contains "path traversal is blocked for execution" "${out}" "traversal=blocked"
section "execute_structured(): allowlisted executors only"
out="$(run_core "${SBOX}" '
    execute_structured "true" "" >/dev/null 2>&1 && printf "true=ok\n" || printf "true=rejected\n"
    execute_structured "sh" "-c" "echo hi" >/dev/null 2>&1 && printf "sh=ok\n" || printf "sh=rejected\n"
    execute_structured "python3" "-c" "print(1)" >/dev/null 2>&1 && printf "python3=ok\n" || printf "python3=rejected\n"
')"
assert_contains "allowlisted executor (true) runs" "${out}" "true=ok"
assert_contains "non-allowlisted executor (sh) is rejected" "${out}" "sh=rejected"
section "execute_structured(): arrays only, one args[] element = one argv element (PRD-23.1-02, §23.1)"
SBOX_ARGV="$(new_sandbox)"
mkdir -p "${SBOX_ARGV}/argvbin"
cat > "${SBOX_ARGV}/argvbin/true" <<'BIN'
#!/usr/bin/env bash
printf 'argc=%s\n' "$#"
i=0
for a in "$@"; do
    i=$((i + 1))
    printf 'arg%s=[%s]\n' "${i}" "${a}"
done
BIN
chmod +x "${SBOX_ARGV}/argvbin/true"
argv_out="$(run_core "${SBOX_ARGV}" '
    export PATH="'"${SBOX_ARGV}"'/argvbin:${PATH}"
    execute_structured "true" "" "hello world" "second arg"
')"
assert_contains "an args[] element containing a space is delivered as ONE argv element, not split (no re-parsing/interpolation)" "${argv_out}" "argc=2"
assert_contains "first structured argument arrives intact" "${argv_out}" "arg1=[hello world]"
assert_contains "second structured argument arrives intact" "${argv_out}" "arg2=[second arg]"
assert_contains "non-allowlisted executor (python3) is rejected" "${out}" "python3=rejected"
section "execute_structured(): shell metacharacter rejection in action/args"
out="$(run_core "${SBOX}" '
    execute_structured "true" "ok-action" >/dev/null 2>&1 && printf "clean_action=ok\n" || printf "clean_action=rejected\n"
    execute_structured "true" "bad;action" >/dev/null 2>&1 && printf "semicolon_action=ok\n" || printf "semicolon_action=rejected\n"
    execute_structured "true" "" "clean-arg" >/dev/null 2>&1 && printf "clean_arg=ok\n" || printf "clean_arg=rejected\n"
    execute_structured "true" "" "\$(whoami)" >/dev/null 2>&1 && printf "subshell_arg=ok\n" || printf "subshell_arg=rejected\n"
    execute_structured "true" "" "a\`b\`" >/dev/null 2>&1 && printf "backtick_arg=ok\n" || printf "backtick_arg=rejected\n"
    execute_structured "true" "" "a|b" >/dev/null 2>&1 && printf "pipe_arg=ok\n" || printf "pipe_arg=rejected\n"
    execute_structured "true" "" "a&b" >/dev/null 2>&1 && printf "amp_arg=ok\n" || printf "amp_arg=rejected\n"
    execute_structured "true" "" "a>b" >/dev/null 2>&1 && printf "redirect_arg=ok\n" || printf "redirect_arg=rejected\n"
')"
assert_contains "clean action string is accepted" "${out}" "clean_action=ok"
assert_contains "semicolon in action is rejected" "${out}" "semicolon_action=rejected"
assert_contains "clean argument is accepted" "${out}" "clean_arg=ok"
assert_contains "command-substitution argument is rejected" "${out}" "subshell_arg=rejected"
assert_contains "backtick argument is rejected" "${out}" "backtick_arg=rejected"
assert_contains "pipe argument is rejected" "${out}" "pipe_arg=rejected"
assert_contains "ampersand argument is rejected" "${out}" "amp_arg=rejected"
assert_contains "redirect argument is rejected" "${out}" "redirect_arg=rejected"
section "_dangerous_arguments_rejected(): rm -rf / and dd/mkfs"
out="$(run_core "${SBOX}" '
    _dangerous_arguments_rejected "rm" "-r" "/tmp/safe-target" && printf "rm_r_only=ok\n" || printf "rm_r_only=rejected\n"
    _dangerous_arguments_rejected "rm" "-rf" "/tmp/safe-target" && printf "rm_rf_safe=ok\n" || printf "rm_rf_safe=rejected\n"
    _dangerous_arguments_rejected "rm" "-rf" "/" && printf "rm_root=ok\n" || printf "rm_root=rejected\n"
    _dangerous_arguments_rejected "rm" "-rf" "/*" && printf "rm_root_glob=ok\n" || printf "rm_root_glob=rejected\n"
    _dangerous_arguments_rejected "dd" "if=/dev/zero" "of=/dev/sda" && printf "dd=ok\n" || printf "dd=rejected\n"
    _dangerous_arguments_rejected "mkfs.ext4" "/dev/sda1" && printf "mkfs=ok\n" || printf "mkfs=rejected\n"
')"
# PRD §23.4: only root-destructive targets are rejected; validated non-root
# -rf paths are allowed (call-site confirmation is the other control).
assert_contains "rm -r (no -f) on a normal path is not blocked by this guard" "${out}" "rm_r_only=ok"
assert_contains "rm -rf on a normal, non-root path is permitted" "${out}" "rm_rf_safe=ok"
assert_contains "rm -rf / is rejected" "${out}" "rm_root=rejected"
assert_contains "rm -rf /* is rejected" "${out}" "rm_root_glob=rejected"
assert_contains "dd is always rejected by execute_structured's own denylist" "${out}" "dd=rejected"
assert_contains "mkfs* is always rejected" "${out}" "mkfs=rejected"
section "Rootless policy: no privilege-escalation executor is allowlisted"
out="$(run_core "${SBOX}" '
    for exe in su sudo doas; do
        execute_structured "${exe}" "" >/dev/null 2>&1 && printf "%s=ok\n" "${exe}" || printf "%s=rejected\n" "${exe}"
    done
')"
assert_not_contains "su is never allowlisted for execution" "${out}" "su=ok"
assert_not_contains "sudo is never allowlisted for execution" "${out}" "sudo=ok"
assert_not_contains "doas is never allowlisted for execution" "${out}" "doas=ok"
section "Confirmation gates: _confirm() semantics"
out="$(run_core "${SBOX}" '
    printf "y\n" | _confirm "proceed" >/dev/null 2>&1; printf "yes_rc=%s\n" "$?"
    printf "n\n" | _confirm "proceed" >/dev/null 2>&1; printf "no_rc=%s\n" "$?"
    printf "\n" | _confirm "proceed" >/dev/null 2>&1; printf "empty_rc=%s\n" "$?"
    printf "garbage\n" | _confirm "proceed" >/dev/null 2>&1; printf "garbage_rc=%s\n" "$?"
')"
assert_contains "_confirm accepts y with status 0" "${out}" "yes_rc=0"
assert_contains "_confirm rejects n with non-zero status" "${out}" "no_rc=4"
assert_contains "_confirm rejects empty input" "${out}" "empty_rc=4"
assert_contains "_confirm rejects garbage input" "${out}" "garbage_rc=4"
section "Informational pause: Enter continues without pretending to confirm"
out="$(run_core "${SBOX}" '
    printf "\n" | _pause "Continue" >/dev/null 2>&1; printf "pause_rc=%s\n" "$?"
')"
assert_contains "_pause accepts Enter as a continue action" "${out}" "pause_rc=0"
section "Forbidden-token rejection: install_target/package_name shell metacharacters (§18.2/§18.3 schema load)"
out="$(run_module "${SBOX}" proot_apps '
    _validate_proot_app_record "git" "Git" "dev-proot" "desc" "git; rm -rf /" "all" "any" \
        && printf "proot_target_meta=accepted\n" || printf "proot_target_meta=rejected\n"
    _validate_proot_app_record "git" "Git" "dev-proot" "desc" "git" "all" "any" \
        && printf "proot_target_clean=accepted\n" || printf "proot_target_clean=rejected\n"
')"
assert_contains "install_target with shell metacharacters is rejected at schema validation" "${out}" "proot_target_meta=rejected"
assert_contains "clean install_target passes schema validation" "${out}" "proot_target_clean=accepted"
out="$(run_module "${SBOX}" termux_apps '
    _validate_termux_app_record "git" "Git" "development" "desc" "git\$(whoami)" "pkg" "-" "-" "-" "-" "-" \
        && printf "termux_pkg_meta=accepted\n" || printf "termux_pkg_meta=rejected\n"
    _validate_termux_app_record "git" "Git" "development" "desc" "git" "pkg" "-" "-" "-" "-" "-" \
        && printf "termux_pkg_clean=accepted\n" || printf "termux_pkg_clean=rejected\n"
')"
assert_contains "termux package_name with shell metacharacters is rejected" "${out}" "termux_pkg_meta=rejected"
assert_contains "clean termux package_name passes" "${out}" "termux_pkg_clean=accepted"
section "GitHub field validation: script source rejected, unpinned ref rejected"
out="$(run_module "${SBOX}" termux_apps '
    _validate_termux_app_record "app" "App" "development" "desc" "-" "script" "-" "owner/repo" "v1.0.0" "artifact" "$(printf "a%.0s" {1..64})" \
        && printf "script_source=accepted\n" || printf "script_source=rejected\n"
    _validate_termux_app_record "app" "App" "development" "desc" "-" "github" "-" "owner/repo" "main" "artifact" "$(printf "a%.0s" {1..64})" \
        && printf "unpinned_ref=accepted\n" || printf "unpinned_ref=rejected\n"
    _validate_termux_app_record "app" "App" "development" "desc" "-" "github" "-" "owner/repo" "v1.2.3" "artifact" "$(printf "a%.0s" {1..64})" \
        && printf "pinned_ref=accepted\n" || printf "pinned_ref=rejected\n"
    _validate_termux_app_record "app" "App" "development" "desc" "-" "github" "-" "owner/repo" "v1.2.3" "artifact" "notacorrecthexsha" \
        && printf "bad_sha=accepted\n" || printf "bad_sha=rejected\n"
'
)"
assert_contains "install_source=script is rejected at schema validation (removed source)" "${out}" "script_source=rejected"
assert_contains "GitHub ref set to a branch name (not pinned) is rejected" "${out}" "unpinned_ref=rejected"
assert_contains "GitHub ref pinned to a SemVer tag is accepted" "${out}" "pinned_ref=accepted"
assert_contains "non-hex/non-64-char sha256 is rejected" "${out}" "bad_sha=rejected"
section "install_github_artifact(): ref + checksum grammar enforced before any network use"
out="$(run_core "${SBOX}" '
    install_github_artifact "owner/repo" "main" "artifact.tar" "$(printf "a%.0s" {1..64})" >/dev/null 2>&1
    printf "branch_ref_rc=%s\n" "$?"
    install_github_artifact "not a repo" "v1.0.0" "artifact.tar" "$(printf "a%.0s" {1..64})" >/dev/null 2>&1
    printf "bad_repo_rc=%s\n" "$?"
    install_github_artifact "owner/repo" "v1.0.0" "artifact.tar" "shortsha" >/dev/null 2>&1
    printf "bad_sha_rc=%s\n" "$?"
')"
assert_ne "unpinned branch ref is rejected (non-zero exit)" "0" "$(printf '%s' "${out}" | grep -o 'branch_ref_rc=.' | cut -d= -f2)"
assert_ne "malformed repository field is rejected" "0" "$(printf '%s' "${out}" | grep -o 'bad_repo_rc=.' | cut -d= -f2)"
assert_ne "malformed checksum is rejected" "0" "$(printf '%s' "${out}" | grep -o 'bad_sha_rc=.' | cut -d= -f2)"
section "Malformed startup_binary rejected at schema load (§18.4)"
out="$(run_module "${SBOX}" linux_env '
    _validate_desktop_record "xfce4" "Xfce" "xfce4,xfce4-terminal" "startxfce4; rm -rf /" "-" "false" "1024" \
        && printf "binary_meta=accepted\n" || printf "binary_meta=rejected\n"
    generate_xstartup "ubuntu" "startxfce4; rm -rf /" "-" >/dev/null 2>&1
    printf "generate_xstartup_rc=%s\n" "$?"
')"
assert_contains "desktop record with metacharacters in startup_binary field is rejected" "${out}" "binary_meta=rejected"
assert_not_contains "generate_xstartup never accepts a non-allowlisted binary" "${out}" "generate_xstartup_rc=0"
section "§23.0/§23.1 reconciliation: executor enum is trimmed to actually-dispatched tools"
out="$(run_core "${SBOX}" '
    for exe in mkdir cat ls find df du date uname getprop termux-battery-status chmod; do
        execute_structured "${exe}" "" >/dev/null 2>&1 && printf "%s=ok\n" "${exe}" || printf "%s=rejected\n" "${exe}"
    done
')"
assert_not_contains "mkdir is not in the executor enum (never dispatched via execute_structured)" "${out}" "mkdir=ok"
assert_not_contains "cat is not in the executor enum" "${out}" "cat=ok"
assert_not_contains "ls is not in the executor enum" "${out}" "ls=ok"
assert_not_contains "find is not in the executor enum" "${out}" "find=ok"
assert_not_contains "df is not in the executor enum" "${out}" "df=ok"
assert_not_contains "du is not in the executor enum" "${out}" "du=ok"
assert_not_contains "date is not in the executor enum" "${out}" "date=ok"
assert_not_contains "uname is not in the executor enum" "${out}" "uname=ok"
assert_not_contains "getprop is not in the executor enum" "${out}" "getprop=ok"
assert_not_contains "termux-battery-status is not in the executor enum" "${out}" "termux-battery-status=ok"
assert_not_contains "chmod is not in the executor enum (always called directly on trusted paths)" "${out}" "chmod=ok"
section "§23.0/§23.1: deterministic per-(executor,action) allowlist — E422 on unlisted action"
# Allowed-action assertions call _executor_action_allowed() directly (pure
# allowlist logic, no subprocess) so this test never performs a real
# package install, network fetch, or filesystem mutation. Rejected-action
# assertions still go through execute_structured() itself, since a
# disallowed action is caught before any subprocess is spawned.
out="$(run_core "${SBOX}" '
    _executor_action_allowed "pkg" "install" && printf "pkg_install=allowed\n" || printf "pkg_install=rejected\n"
    _executor_action_allowed "pkg" "remove" && printf "pkg_remove=allowed\n" || printf "pkg_remove=rejected\n"
    _executor_action_allowed "pkg" "update" && printf "pkg_update=allowed\n" || printf "pkg_update=rejected\n"
    _executor_action_allowed "pkg" "upgrade" && printf "pkg_upgrade=allowed\n" || printf "pkg_upgrade=rejected\n"
    _executor_action_allowed "pkg" "list-upgradable" && printf "pkg_list_upgradable=allowed\n" || printf "pkg_list_upgradable=rejected\n"
    _executor_action_allowed "tar" "-xzf" && printf "tar_extract=allowed\n" || printf "tar_extract=rejected\n"
    _executor_action_allowed "tar" "-czf" && printf "tar_create=allowed\n" || printf "tar_create=rejected\n"
    _executor_action_allowed "tar" "--delete" && printf "tar_delete=allowed\n" || printf "tar_delete=rejected\n"
    _executor_action_allowed "git" "clone" && printf "git_clone=allowed\n" || printf "git_clone=rejected\n"
    _executor_action_allowed "git" "ls-remote" && printf "git_ls_remote=allowed\n" || printf "git_ls_remote=rejected\n"
    _executor_action_allowed "git" "push" && printf "git_push=allowed\n" || printf "git_push=rejected\n"
')"
assert_contains "pkg install is an allowlisted action (§23.0)" "${out}" "pkg_install=allowed"
assert_contains "pkg remove is NOT an allowlisted action" "${out}" "pkg_remove=rejected"
assert_contains "pkg update is an allowlisted §13.13 extension action" "${out}" "pkg_update=allowed"
assert_contains "pkg upgrade is an allowlisted §13.13 extension action" "${out}" "pkg_upgrade=allowed"
assert_contains "pkg list-upgradable is an allowlisted §13.13 extension action" "${out}" "pkg_list_upgradable=allowed"
assert_contains "tar -xzf (extract) is allowlisted per §23.0" "${out}" "tar_extract=allowed"
assert_contains "tar -czf (create) is an allowlisted §32.1/§13.9 extension action" "${out}" "tar_create=allowed"
assert_contains "tar --delete is NOT an allowlisted action" "${out}" "tar_delete=rejected"
assert_contains "git clone is an allowlisted action (§23.0)" "${out}" "git_clone=allowed"
assert_contains "git ls-remote is an allowlisted §30.6 extension action" "${out}" "git_ls_remote=allowed"
assert_contains "git push is NOT an allowlisted action" "${out}" "git_push=rejected"
section "§23.0/§23.1: rejected actions never reach the executor (E420-E429 before dispatch)"
out="$(run_core "${SBOX}" '
    execute_structured "pkg" "remove" "git" >/dev/null 2>&1; printf "pkg_remove_rc=%s\n" "$?"
    execute_structured "tar" "--delete" "/tmp/does-not-matter" >/dev/null 2>&1; printf "tar_delete_rc=%s\n" "$?"
    execute_structured "git" "push" "origin" "main" >/dev/null 2>&1; printf "git_push_rc=%s\n" "$?"
    execute_structured "rm" "-r" "/tmp/x" >/dev/null 2>&1; printf "rm_bad_flag_rc=%s\n" "$?"
    execute_structured "curl" "-o" "/tmp/x" "https://example.invalid" >/dev/null 2>&1; printf "curl_bad_flag_rc=%s\n" "$?"
')"
assert_ne "pkg remove is rejected before dispatch (E420-E429)" "0" "$(printf '%s' "${out}" | grep -o 'pkg_remove_rc=.' | cut -d= -f2)"
assert_ne "tar --delete is rejected before dispatch (E420-E429)" "0" "$(printf '%s' "${out}" | grep -o 'tar_delete_rc=.' | cut -d= -f2)"
assert_ne "git push is rejected before dispatch (E420-E429)" "0" "$(printf '%s' "${out}" | grep -o 'git_push_rc=.' | cut -d= -f2)"
assert_ne "rm -r (not -rf/-f) is rejected before dispatch (E420-E429)" "0" "$(printf '%s' "${out}" | grep -o 'rm_bad_flag_rc=.' | cut -d= -f2)"
assert_ne "curl -o (not -fL/-fsSL) is rejected before dispatch (E420-E429)" "0" "$(printf '%s' "${out}" | grep -o 'curl_bad_flag_rc=.' | cut -d= -f2)"
section "§23.3: install_github_artifact() checksums the download via execute_structured(), not a raw subprocess call"
out="$(run_core "${SBOX}" '
    type install_github_artifact >/dev/null 2>&1 && printf "fn=present\n"
    declare -f install_github_artifact | grep -q "execute_structured sha256sum" && printf "checksum_via_executor=yes\n" || printf "checksum_via_executor=no\n"
    declare -f install_github_artifact | grep -qE "^\s*actual=\"\\\$\\(sha256sum " && printf "raw_sha256sum_call=yes\n" || printf "raw_sha256sum_call=no\n"
')"
assert_contains "install_github_artifact is defined" "${out}" "fn=present"
assert_contains "checksum of downloaded artifact goes through execute_structured (§23.1 centralization)" "${out}" "checksum_via_executor=yes"
assert_contains "no raw, uncentralized sha256sum subprocess call remains in install_github_artifact" "${out}" "raw_sha256sum_call=no"
section "§48.2: execute_structured() rejections use the reserved E420-E429 range, not E401/E402"
out="$(run_core "${SBOX}" '
    execute_structured "sh" "-c" "echo hi" 2>&1 >/dev/null | grep -o "E4[0-9][0-9]" | head -1
    execute_structured "pkg" "remove" "x" 2>&1 >/dev/null | grep -o "E4[0-9][0-9]" | head -1
')"
assert_contains "unallowlisted executor is reported as E420, not E401 (E401 = --uninstall outside IDLE)" "${out}" "E420"
assert_contains "unallowlisted action is reported as E422, not E402 (E402 = unknown startup_binary)" "${out}" "E422"
assert_not_contains "execute_structured never reports E401 (reserved elsewhere in §48.2)" "${out}" "E401"
section "§48.2: validate_path() failures report the correct E430-E439 sub-code per failed step"
out="$(run_core "${SBOX}" '
    validate_path "" >/dev/null 2>&1; printf "lexical=%s\n" "$(_path_validation_error_code)"
    validate_path "a/../b" >/dev/null 2>&1; printf "traversal=%s\n" "$(_path_validation_error_code)"
    validate_path "${HOME}/x" "/some/other/root" >/dev/null 2>&1; printf "root_containment=%s\n" "$(_path_validation_error_code)"
    validate_path "${HOME}" >/dev/null 2>&1; printf "success=%s\n" "$?"
')"
assert_contains "empty path is reported as E430 (lexical)" "${out}" "lexical=E430"
assert_contains "'..' segment is reported as E431 (traversal)" "${out}" "traversal=E431"
assert_contains "path outside allowed_root is reported as E432 (root-containment)" "${out}" "root_containment=E432"
assert_contains "a valid path still succeeds (rc 0)" "${out}" "success=0"
section "§23.0-05: per-executor timeout/env/cwd/stdin policy exists and is applied"
out="$(run_core "${SBOX}" '
    declare -f execute_structured | grep -q "DEVILS_MINIOS_EXECUTOR_TIMEOUT_SECONDS" && printf "uses_timeout_map=yes\n" || printf "uses_timeout_map=no\n"
    declare -f execute_structured | grep -q "< */dev/null" && printf "closes_stdin=yes\n" || printf "closes_stdin=no\n"
    declare -f execute_structured | grep -q "_executor_safe_cwd" && printf "sets_safe_cwd=yes\n" || printf "sets_safe_cwd=no\n"
    declare -f execute_structured | grep -q "_is_interactive_executor_call" && printf "checks_interactive=yes\n" || printf "checks_interactive=no\n"
    missing=0
    for e in "${DEVILS_MINIOS_ALLOWED_EXECUTORS[@]}"; do
        [[ -n "${DEVILS_MINIOS_EXECUTOR_TIMEOUT_SECONDS[${e}]:-}" ]] || missing=$((missing+1))
    done
    printf "executors_without_timeout=%s\n" "${missing}"
    execute_structured "true" "ok" >/dev/null 2>&1; printf "true_still_works_rc=%s\n" "$?"
')"
assert_contains "execute_structured applies a per-executor timeout map (§23.0-05)" "${out}" "uses_timeout_map=yes"
assert_contains "execute_structured closes stdin for non-interactive dispatches" "${out}" "closes_stdin=yes"
assert_contains "execute_structured retains a neutral cwd helper for ordinary non-interactive dispatches" "${out}" "sets_safe_cwd=yes"
assert_contains "execute_structured distinguishes interactive proot-distro login" "${out}" "checks_interactive=yes"
assert_contains "every allowlisted executor has a timeout policy entry" "${out}" "executors_without_timeout=0"
assert_contains "policy wrapping preserves normal exit-status passthrough" "${out}" "true_still_works_rc=0"
section "§23.0-05: sha256sum manifest checks preserve the caller-selected working directory"
SBOX_SHA="$(new_sandbox)"
out="$(run_core "${SBOX_SHA}" '
    mkdir -p "${HOME}/manifest-check"
    printf "payload\n" > "${HOME}/manifest-check/payload"
    (cd "${HOME}/manifest-check" && sha256sum payload > SHA256SUMS)
    (cd "${HOME}/manifest-check" && execute_structured sha256sum "-c" "SHA256SUMS" "--status")
    printf "manifest_check_rc=%s\n" "$?"
    printf "caller_dir=%s\n" "$(cd "${HOME}/manifest-check" && pwd)"
')"
assert_contains "sha256sum manifest check succeeds from the manifest directory" "${out}" "manifest_check_rc=0"
section "§23.0-05: interactive proot-distro login detection is exempt from timeout/stdin, batch calls are not"
out="$(run_core "${SBOX}" '
    _is_interactive_executor_call "proot-distro" "login" "ubuntu" && printf "plain_login=interactive\n" || printf "plain_login=batch\n"
    _is_interactive_executor_call "proot-distro" "login" "ubuntu" "--" "apt" "update" && printf "batch_login=interactive\n" || printf "batch_login=batch\n"
    _is_interactive_executor_call "pkg" "install" "-y" "git" && printf "pkg_install=interactive\n" || printf "pkg_install=batch\n"
')"
assert_contains "plain proot-distro login (no --) is classified interactive" "${out}" "plain_login=interactive"
assert_contains "proot-distro login with a -- batch command is classified non-interactive" "${out}" "batch_login=batch"
assert_contains "non-proot-distro executors are always classified non-interactive" "${out}" "pkg_install=batch"
section "§22.1 step 6: _reject_symlink_destination() unit behavior"
out="$(run_core "${SBOX}" '
    ln -s /tmp "${HOME}/a-symlink"
    _reject_symlink_destination "${HOME}/a-symlink" && printf "symlink=allowed\n" || printf "symlink=rejected\n"
    printf "fail_step=%s\n" "${DEVILS_MINIOS_PATH_FAIL_STEP}"
    touch "${HOME}/a-real-file"
    _reject_symlink_destination "${HOME}/a-real-file" && printf "real_file=allowed\n" || printf "real_file=rejected\n"
    _reject_symlink_destination "${HOME}/does-not-exist-at-all" && printf "nonexistent=allowed\n" || printf "nonexistent=rejected\n"
')"
assert_contains "an existing symlink destination is rejected" "${out}" "symlink=rejected"
assert_contains "rejection is classified as the symlink-policy step" "${out}" "fail_step=symlink-policy"
assert_contains "an existing real file destination is allowed (overwrite is the caller's own concern, not a symlink-redirection risk)" "${out}" "real_file=allowed"
assert_contains "a nonexistent destination is allowed (nothing to redirect through yet)" "${out}" "nonexistent=allowed"
section "§43.3 / §18.3 / §48 E404: install_github_artifact() input validation and checksum mismatch"
SBOX_G="$(new_sandbox)"
mkdir -p "${SBOX_G}/fakebin"
cat > "${SBOX_G}/fakebin/curl" <<'FAKECURL'
#!/usr/bin/env bash
out=""; while [[ $# -gt 0 ]]; do [[ "$1" == "-o" ]] && { out="$2"; shift; }; shift; done
printf 'artifact-bytes' > "${out}"
FAKECURL
chmod 755 "${SBOX_G}/fakebin/curl"
_good_sha="$(printf 'artifact-bytes' | sha256sum | cut -d' ' -f1)"
_bad_sha="$(printf '%064d' 0)"
out="$(PATH="${SBOX_G}/fakebin:${PATH}" run_core "${SBOX_G}" "
    install_github_artifact 'bad repo' v1.0.0 tool.bin ${_good_sha}; printf 'badrepo_rc=%s\n' \"\$?\"
    install_github_artifact owner/repo main tool.bin ${_good_sha}; printf 'unpinned_rc=%s\n' \"\$?\"
    install_github_artifact owner/repo v1.0.0 tool.bin nothex; printf 'badsha_rc=%s\n' \"\$?\"
    install_github_artifact owner/repo v1.0.0 tool.bin ${_bad_sha}; printf 'mismatch_rc=%s\n' \"\$?\"
    [[ -e \"\${DEVILS_MINIOS_INSTALL_DIR}/apps/tool.bin\" ]] && printf 'partial=present\n' || printf 'partial=absent\n'
    install_github_artifact owner/repo v1.0.0 tool.bin ${_good_sha}; printf 'match_rc=%s\n' \"\$?\"
    [[ -e \"\${DEVILS_MINIOS_INSTALL_DIR}/apps/tool.bin\" ]] && printf 'installed=present\n' || printf 'installed=absent\n'
")"
assert_contains "invalid repository rejected (status 2)" "${out}" "badrepo_rc=2"
assert_contains "unpinned ref (branch name) rejected (status 2)" "${out}" "unpinned_rc=2"
assert_contains "non-SHA-256 checksum field rejected (status 2)" "${out}" "badsha_rc=2"
assert_contains "checksum mismatch aborts (status 2)" "${out}" "mismatch_rc=2"
assert_contains "checksum mismatch is reported as E404" "${out}" "E404"
assert_contains "checksum mismatch leaves no partial artifact" "${out}" "partial=absent"
assert_contains "matching checksum installs (status 0)" "${out}" "match_rc=0"
assert_contains "matching checksum leaves the artifact in place" "${out}" "installed=present"
section "§43.3 / §18.4 / §48 E402 E403: run_desktop_startup() rejects unknown binary and shell-metacharacter args"
out="$(run_core "${SBOX_G}" '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    run_desktop_startup ubuntu "rm" "-"; printf "badbin_rc=%s\n" "$?"
    run_desktop_startup ubuntu "startxfce4" "a;b"; printf "semicolon_rc=%s\n" "$?"
    run_desktop_startup ubuntu "startxfce4" "a\$(id)"; printf "subst_rc=%s\n" "$?"
')"
assert_contains "unknown startup binary rejected (status 2)" "${out}" "badbin_rc=2"
assert_contains "unknown startup binary reported as E402" "${out}" "E402"
assert_contains "startup arg containing ';' rejected before execution (status 2)" "${out}" "semicolon_rc=2"
assert_contains "startup arg containing command substitution rejected (status 2)" "${out}" "subst_rc=2"
assert_contains "rejected startup args are reported as E403" "${out}" "E403"
section "§48.2 E203/E404 semantics: E203 only for 'rootfs not installed'; E404 only for checksum-verification failure"
out="$(run_core "${SBOX_G}" '
    rm -rf "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    run_desktop_startup nosuchdistro startxfce4 "-" 2>&1 | sed "s/^/unknown: /"
    run_desktop_startup ubuntu startxfce4 "-" 2>&1 | sed "s/^/norootfs: /"
    install_github_artifact "bad repo" v1.0.0 tool.bin 0000000000000000000000000000000000000000000000000000000000000000 2>&1 | sed "s/^/badrepo: /"
')"
assert_not_contains "unknown distro is not reported as E203 (E203 = rootfs not installed only)" "$(printf '%s\n' "${out}" | grep '^unknown: ')" "E203"
assert_contains "distro with no installed rootfs is reported as E203" "$(printf '%s\n' "${out}" | grep '^norootfs: ')" "E203"
assert_not_contains "invalid GitHub repository argument is not reported as E404 (E404 = checksum mismatch only)" "$(printf '%s\n' "${out}" | grep '^badrepo: ')" "E404"
section "§23.4/§43.3: curl|sh and wget|sh pipelines cannot be constructed through execute_structured() (negative verification)"
out="$(run_core "${SBOX}" '
    execute_structured "curl" "-fsSL" "-o" "/tmp/x" "https://github.com/o/r/archive/v1.tar.gz|sh" >/dev/null 2>&1; printf "curl_pipe_url_rc=%s\n" "$?"
    execute_structured "curl" "-fsSL" "https://github.com/o/r" "|" "sh" >/dev/null 2>&1; printf "curl_pipe_arg_rc=%s\n" "$?"
    execute_structured "curl" "-fsSL" "https://github.com/o/r" ";" "sh" >/dev/null 2>&1; printf "curl_chain_arg_rc=%s\n" "$?"
    execute_structured "wget" "-qO-" "https://github.com/o/r" >/dev/null 2>&1; printf "wget_rc=%s\n" "$?"
    execute_structured "sh" "-c" "curl https://github.com/o/r | sh" >/dev/null 2>&1; printf "sh_c_rc=%s\n" "$?"
    execute_structured "bash" "-c" "curl https://github.com/o/r | bash" >/dev/null 2>&1; printf "bash_c_rc=%s\n" "$?"
')"
for _k in curl_pipe_url curl_pipe_arg curl_chain_arg wget sh_c bash_c; do
    assert_contains "${_k}: rc was captured" "${out}" "${_k}_rc="
    assert_ne "${_k}: pipeline/non-allowlisted form is rejected (nonzero)" "0" "$(printf '%s' "${out}" | grep -o "${_k}_rc=[0-9]*" | cut -d= -f2)"
done
section "PRD §48.2 error-code registry: no unregistered code may be introduced"
# Registered (known §48.2 registry: 19 single codes + E420-E429 + E430-E439).
# PENDING = codes used in source that §48.2 does not register and for which no
# registered code clearly fits; documented in docs/TRACEABILITY.md (§48 section)
# as an open PRD conflict. The list may only shrink: adding a code fails here.
REG_RE='^E(203|40[0-6]|41[0-2]|42[0-9]|43[0-9]|440|60[1-3]|70[1-3]|900)$'
PENDING_RE='a^'  # no unregistered runtime codes remain
used="$(cd "${DMOS_PROJECT_ROOT}" && grep -hvE '^[[:space:]]*#' core/*.sh modules/*.sh install.sh devils-minios.sh | grep -oE '\bE[0-9]{3}\b' | sort -u)"
unknown=""
for c in ${used}; do
    [[ "${c}" =~ ${REG_RE} || "${c}" =~ ${PENDING_RE} ]] || unknown+="${c} "
done
assert_eq "every E### code in executable source is registered or on the documented pending list" "" "${unknown}"
if printf '%s\n' "${used}" | grep -qx 'E999'; then fail "E999 is not a registered code and must not appear in executable source"; else pass "E999 (unregistered) does not appear in executable source"; fi
assert_true "_error() falls back to registered E900, not an invented code" "$(grep -q 'code="${1:-E900}"' "${DMOS_PROJECT_ROOT}/core/core_logging.sh"; printf %s $?)"
assert_eq "E400 appears only at registered state/CLI call sites" "" "$(grep -RnhE '_(error|warn) "E400"' --include='*.sh' "${DMOS_PROJECT_ROOT}/modules" "${DMOS_PROJECT_ROOT}/core/core_catalog.sh" "${DMOS_PROJECT_ROOT}/core/core_config.sh" "${DMOS_PROJECT_ROOT}/core/core_platform.sh" "${DMOS_PROJECT_ROOT}/core/core_security.sh" "${DMOS_PROJECT_ROOT}/core/core_ui.sh" "${DMOS_PROJECT_ROOT}/core/core_logging.sh" "${DMOS_PROJECT_ROOT}/core/core_executor.sh" || true)"
assert_eq "legacy unregistered E100/E101/E102/E104/E105/E300/E301/E500 are absent from executable source" "" "$(grep -RnhE '_(error|warn) "E(100|101|102|104|105|300|301|500)"' --include='*.sh' "${DMOS_PROJECT_ROOT}/modules" "${DMOS_PROJECT_ROOT}/core" "${DMOS_PROJECT_ROOT}/devils-minios.sh" || true)"
section "PRD §26.5 / §33.1: Safe Mode repair checks persistence and post-validation before IDLE"
repair_block="$(sed -n '/default_state/,/_enter_idle_state/p' core/core_state.sh)"
config_repair_block="$(sed -n '/load_default_config/,/_enter_idle_state/p' core/core_state.sh)"
assert_contains "Safe Mode state repair checks save_state and validate_state before IDLE" "${repair_block}" "save_state || ! validate_state"
assert_contains "Safe Mode configuration repair checks save_config and validate_config before IDLE" "${config_repair_block}" "save_config || ! validate_config"
section "PRD §37 / §45.1 / §51 / §52: governance, acceptance and dependency documentation are structurally complete"
trace="$(cat "${DMOS_PROJECT_ROOT}/docs/TRACEABILITY.md")"
assert_contains "§37 traceability has owner fields" "${trace}" "BDFL (default)"
assert_contains "§45.1 critical workflow matrix is present" "${trace}" "Critical Workflow Matrix"
sec="$(cat "${DMOS_PROJECT_ROOT}/docs/SECURITY.md")"
assert_contains "§51 private vulnerability reporting is documented" "${sec}" "private vulnerability"
assert_contains "§51 acknowledgement target is documented" "${sec}" "within 7 days"
compat="$(cat "${DMOS_PROJECT_ROOT}/docs/COMPATIBILITY.md")"
assert_contains "§52 optional dependency Termux:API is documented" "${compat}" "Termux:API"
assert_contains "§52 optional dependency Termux:Boot is documented" "${compat}" "Termux:Boot"
assert_contains "§52 proot-distro dependency is documented" "${compat}" "proot-distro"
print_summary "test_security.sh"
exit $?
