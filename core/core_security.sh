#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_security.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# Holds input/path/security validation (sanitize_input, validate_path,
# symlink-destination rejection, dangerous-argument guards).
# The §23 executor implementation lives in core/core_executor.sh (split
# from this file; see that file for the §23.0/§23.1 reconciliation). This
# file retains the §23.1 shell denylist pattern and dangerous-pattern
# pre-checks used by the executor.
# PRD Reference: §22, §23, §23.1

# ============================================================================
# INPUT, PATH, AND SECURITY VALIDATION (§22, §23)
# ============================================================================

# Contract: sanitize_input(input, max_length); returns: sanitized value on stdout; non-zero on invalid input; side effects: none.
sanitize_input() {
    local input="${1:-}"
    local max_length="${2:-1024}"
    input="$(printf '%s' "${input}" | tr -d '\000-\010\013-\037\177')"
    if [[ ${#input} -gt ${max_length} ]]; then
        input="${input:0:${max_length}}"
    fi
    printf '%s' "${input}"
}

_validate_no_metacharacters() {
    local input="${1:-}"
    [[ -n "${input}" && "${input}" =~ ${DEVILS_MINIOS_SHELL_DENYLIST_PATTERN} ]] && return 1
    return 0
}


# validate_path(path, [allowed_root]) — PRD §22.1.
#
# Implements the 8-step deterministic algorithm as a dependency-free Bash
# function:
#   1. Lexical validation (empty / NUL / PATH_MAX)
#   2. Traversal rejection — per-segment (not substring) ".." check, so a
#      legitimate filename such as "notes..txt" is not falsely rejected,
#      while any real ".." path segment (relative or absolute input) is.
#   3-4. Existing-parent-chain resolution (via `realpath -m` when present,
#        else a `cd`+`pwd` fallback) and allowed_root containment, checked
#        against the *resolved* parent so a symlinked parent cannot be used
#        to point the effective location outside allowed_root.
#   5. Lexical validation of a nonexistent final component.
# Steps 6 (per-operation symlink policy) and 7 (immediate pre-mutation
# revalidation) are NOT implemented generically inside this function —
# they depend on the specific operation (read vs. rename vs. recursive
# delete) and are the caller's responsibility: see
# _reject_symlink_destination() for step 6, and re-invoke validate_path()
# immediately before the mutating call for step 7 (see
# modules/file_mgr.sh::_file_mgr_delete, modules/workspace.sh::_workspace_delete,
# core/core_state.sh's nuclear-reset cache-dir deletion).
#
# PRD-22.1-07 ("operate on the resolved path from steps 3/4, not the
# original unresolved input"): when base_dir/allowed_root is given and
# validation succeeds, the fully resolved absolute path computed during
# steps 3-4 is exported in DEVILS_MINIOS_PATH_RESOLVED (like
# DEVILS_MINIOS_PATH_FAIL_STEP, it is overwritten on every call, so a
# caller that wants it must read it immediately after a successful call
# and before invoking validate_path() again). A caller that performs the
# actual mutation should use "${DEVILS_MINIOS_PATH_RESOLVED:-<original>}"
# so the syscall operates on the same location that was just
# resolved-and-contained, not on a literal string that could still be
# re-interpreted (e.g. via a parent-chain symlink swapped in during the
# TOCTOU window) at the time of the mutating call. When no base_dir is
# given, steps 3/4 do not run (no confinement is being asserted), so
# DEVILS_MINIOS_PATH_RESOLVED is left empty and callers keep using the
# original string, exactly as before.
# Contract: validate_path(path, base_dir); returns: 0 when valid, non-zero when rejected; side effects: none.
validate_path() {
    local path="${1:-}"
    local base_dir="${2:-}"

    # §48.2 E430-E439: one sub-code per failed §22.1 step. Callers read this
    # via _path_validation_error_code() immediately after a failed call
    # (nothing else may run validate_path() in between, since it is
    # overwritten on every call, success or failure).
    DEVILS_MINIOS_PATH_FAIL_STEP=""
    # PRD-22.1-07: cleared on every call (success or failure); only ever
    # set on a *successful* call that had a base_dir to resolve against.
    DEVILS_MINIOS_PATH_RESOLVED=""

    # --- Step 1: lexical validation ---
    if [[ -z "${path}" || ${#path} -gt 4096 ]]; then
        DEVILS_MINIOS_PATH_FAIL_STEP="lexical"
        return 1
    fi
    # NOTE: no separate NUL-byte check here. A Bash string variable cannot
    # contain an embedded NUL byte in the first place (NUL terminates the
    # C string Bash stores it in), so any glob/regex attempting to test
    # for one against "${path}" is inherently unable to observe what it
    # claims to check — worse, a naive `$'\0'` pattern silently degrades
    # to matching *any* string (glob `**`), which would falsely reject
    # every path. §22.1 step 1's NUL-byte requirement is therefore
    # satisfied trivially by Bash's own string representation, not by an
    # explicit runtime check, and is documented as such rather than
    # implemented with a check that cannot do what its name claims.

    # --- Step 2: traversal / invalid-form rejection (structural, per-segment) ---
    local seg
    local -a segs=()
    IFS='/' read -ra segs <<< "${path}"
    for seg in "${segs[@]}"; do
        if [[ "${seg}" == ".." ]]; then
            DEVILS_MINIOS_PATH_FAIL_STEP="traversal"
            return 1
        fi
    done
    if [[ "${path}" == *"//"* ]]; then
        DEVILS_MINIOS_PATH_FAIL_STEP="traversal"
        return 1
    fi

    if [[ -n "${base_dir}" ]]; then
        local abs_path="${path}"
        if [[ "${abs_path}" != /* ]]; then
            abs_path="${base_dir%/}/${abs_path}"
        fi
        local parent final
        parent="$(dirname -- "${abs_path}")"
        final="$(basename -- "${abs_path}")"

        # --- Step 5 (lexical part): final component sanity ---
        if [[ "${final}" == "." || "${final}" == ".." ]]; then
            DEVILS_MINIOS_PATH_FAIL_STEP="final-component"
            return 1
        fi

        # --- Step 3: resolve the existing parent chain ---
        local resolved_parent=""
        if command -v realpath >/dev/null 2>&1; then
            resolved_parent="$(realpath -m -- "${parent}" 2>/dev/null || true)"
        fi
        if [[ -z "${resolved_parent}" ]]; then
            if [[ -d "${parent}" ]]; then
                resolved_parent="$(cd -- "${parent}" 2>/dev/null && pwd)"
            else
                resolved_parent="${parent}"
            fi
        fi
        if [[ -z "${resolved_parent}" ]]; then
            DEVILS_MINIOS_PATH_FAIL_STEP="final-component"
            return 1
        fi
        abs_path="${resolved_parent%/}/${final}"

        local abs_base="${base_dir}"
        if [[ -d "${abs_base}" ]]; then
            abs_base="$(cd -- "${abs_base}" 2>/dev/null && pwd)"
        elif command -v realpath >/dev/null 2>&1; then
            abs_base="$(realpath -m -- "${base_dir}" 2>/dev/null || printf '%s' "${base_dir}")"
        fi

        # --- Step 4: verify the resolved parent is inside allowed_root ---
        if [[ "${resolved_parent}" != "${abs_base}" && "${resolved_parent}" != "${abs_base}"/* ]]; then
            DEVILS_MINIOS_PATH_FAIL_STEP="root-containment"
            return 1
        fi

        # PRD-22.1-07: hand the caller the actual resolved-and-contained
        # location (steps 3/4's output), not just a pass/fail boolean.
        # shellcheck disable=SC2034  # output variable; read in core/core_recovery.sh
        DEVILS_MINIOS_PATH_RESOLVED="${abs_path}"
    fi
    return 0
}

# _path_validation_error_code() — PRD §48.2 E430-E439 mapping. Call
# immediately after a failed validate_path(), before anything else can
# overwrite DEVILS_MINIOS_PATH_FAIL_STEP by calling validate_path() again.
# Steps not distinguished by validate_path() itself (symlink-policy is a
# per-operation caller check; revalidation is the caller's own step-7
# re-invocation) are the caller's responsibility to report as E434/E435
# directly at the specific call sites that implement them.
_path_validation_error_code() {
    case "${DEVILS_MINIOS_PATH_FAIL_STEP:-}" in
        lexical) printf 'E430' ;;
        traversal) printf 'E431' ;;
        root-containment) printf 'E432' ;;
        final-component) printf 'E433' ;;
        symlink-policy) printf 'E434' ;;
        revalidation) printf 'E435' ;;
        *) printf 'E430' ;;
    esac
}

# _reject_symlink_destination(path) — PRD §22.1 step 6 (per-operation
# symlink policy), for the one class of raw-user-path mutation where an
# existing symlink at the destination is actually dangerous: an
# overwrite-style write (copy/move/create onto a path that already exists).
# If `path` already exists as a symlink, writing "through" it would silently
# affect whatever it points to instead of the location the user typed, so
# such operations MUST reject it rather than following/replacing it
# silently. Call this immediately before the mutating call (alongside a
# fresh validate_path()), never earlier, so the check cannot go stale.
#
# Deliberately NOT applied to plain deletion (file_mgr's rm -f/-rf,
# workspace's rm -rf, self-update's/nuclear-reset's fixed-path cleanup):
# removing a symlink unlinks the symlink itself and — by GNU coreutils'
# own documented behavior — `rm`, including `rm -r`, never dereferences a
# symlink argument to recurse into whatever it points to. There is
# therefore no redirection risk for deletion to guard against here, and
# adding this check to delete call sites would only block the legitimate,
# safe case of deleting a symlink.
_reject_symlink_destination() {
    local path="${1:-}"
    if [[ -L "${path}" ]]; then
        DEVILS_MINIOS_PATH_FAIL_STEP="symlink-policy"
        return 1
    fi
    return 0
}

# Contract: is_external_storage_path(path); returns: 0 when valid, non-zero when rejected; side effects: none.
is_external_storage_path() {
    local path="${1:-}"
    [[ "${path}" == /sdcard* || "${path}" == /storage/* || "${path}" == /storage/emulated/* ]]
}

# Contract: assert_execution_path_allowed(path); returns: 0 when valid, non-zero when rejected; side effects: none.
assert_execution_path_allowed() {
    local path="${1:-}"
    validate_path "${path}" || { _error "$(_path_validation_error_code)" "Invalid execution path" 0; return 2; }
    if is_external_storage_path "${path}"; then
        _error "E900" "Execution from external storage is blocked; Android external storage is mounted noexec" 0
        return 2
    fi
    return 0
}

_dangerous_arguments_rejected() {
    local executor="$1"
    shift
    local arg
    # NOTE: generic shell-metacharacter rejection is NOT duplicated here.
    # execute_structured() already calls _validate_no_metacharacters() (the
    # PRD §23.1-authoritative DEVILS_MINIOS_SHELL_DENYLIST_PATTERN regex,
    # defined once in core.sh) against every argument and the action before
    # this function runs. That regex-based check matches the denylisted
    # characters `;&|$\`<>()` anywhere in the string; an earlier case-glob
    # reimplementation of the same denylist here was both redundant and
    # strictly weaker (several arms only matched a leading prefix, e.g.
    # '&&'* would miss "foo&&bar"), and its quoted-paren case patterns
    # produced real ShellCheck parser errors (SC1072/SC1073/SC1085/SC1124).
    # Removing it fixes the parser errors without weakening validation,
    # since the broader, correctly-anchored regex check still runs first.
    # PRD §23.4: reject dangerous patterns (rm -rf /, rm -rf /*, dd, mkfs).
    # Validated non-root targets with -rf are permitted after call-site confirmation
    # (file_mgr, workspace). Nuclear reset uses direct rm outside execute_structured.
    if [[ "${executor}" == "rm" ]]; then
        for arg in "$@"; do
            if [[ "${arg}" == "/" || "${arg}" == "/*" || "${arg}" == "/.." || "${arg}" == ".." ]]; then
                return 1
            fi
            # Reject attempts to wipe critical filesystem roots
            if [[ "${arg}" == "/" || "${arg}" == "/bin" || "${arg}" == "/usr" || \
                  "${arg}" == "/etc" || "${arg}" == "/var" || "${arg}" == "/home" || \
                  "${arg}" == "/root" || "${arg}" == "/data" || "${arg}" == "/system" ]]; then
                return 1
            fi
        done
    fi
    if [[ "${executor}" == "dd" || "${executor}" == "mkfs"* ]]; then
        return 1
    fi
    return 0
}

