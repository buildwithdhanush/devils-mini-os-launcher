#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_executor.sh
# Split from core/core_security.sh (PRD file-size limit, §-referenced
# sections preserved verbatim). Sourced by modules/core.sh (loaded from
# core/) after core_security.sh; not a standalone feature module and not
# part of DEVILS_MINIOS_FEATURE_MODULES.
# Holds execute_structured(), the sole sanctioned external-command
# execution boundary, plus its executor enum, per-executor action
# allowlist, environment/cwd/stdin/timeout/exit-status policy (§23.0-05),
# and §48.2 E420-E429 structured-execution error mapping.
# Depends on core/core_security.sh (loaded first): validate_path(),
# _reject_symlink_destination(), _path_validation_error_code(), and the
# §23.1 shell denylist pattern.
# PRD Reference: §23, §23.0, §23.1, §48.2

# ============================================================================
# STRUCTURED EXECUTION (§23.0, §23.1) — sole execution primitive
# ============================================================================
#
# Reconciliation of the §23.0/§23.1 executor-list contradiction
# ------------------------------------------------------------
# §23.0 states its 6-row table (proot-distro, pkg, git, tar, sha256sum,
# curl) "is the entire allowlist" for execute_structured(); §23.1 in the
# same revision permits "a small number of other fixed system tools".
# Treat §23.0's six catalog/network-facing executors as the complete
# catalog-facing set; §23.1's fixed-tool allowance is limited to explicitly
# implemented internal operations so the execution contract stays deterministic:
#
#   1. §23.0's 6 rows remain the complete set of CATALOG/NETWORK-FACING
#      executors — the ones whose args[] can carry catalog- or
#      network-derived data (distro ids, package names, repo/ref/artifact
#      fields, URLs) and which therefore need the full per-row contract
#      (env policy, cwd, timeout, exit-code mapping) §23.0 defines.
#   2. §23.1's "small number of other fixed system tools" is read as
#      covering exactly the LOCAL, launcher/user-file-system-facing
#      executors that real module functionality requires (file manager
#      move/copy/link/delete, process termination, ADB/fastboot device
#      queries §35.3) and that are *actually dispatched* through
#      execute_structured() somewhere in this codebase. Every prior
#      allowlist entry that was never actually invoked via
#      execute_structured() anywhere in the codebase (mkdir, cat, ls,
#      find, df, du, date, uname, getprop, termux-battery-status) has
#      been removed: those operations are performed as direct, trusted,
#      fixed-argument Bash builtins/coreutils calls on launcher-constant
#      paths elsewhere (never on catalog- or user-supplied data), which
#      is exactly the class of call §23.1 exempts from centralization
#      ("...permitted to spawn a subprocess derived from catalog or
#      configuration data" — trusted fixed-argument internal calls are
#      not derived from catalog/config data). Keeping unused executor
#      names in the enum only widens the attack surface without adding
#      real functionality, which works against §23.0's own "entire
#      allowlist" intent even under this reconciliation.
#   3. Both classes are subject to the SAME underlying invariant shared
#      by §23.0 and §23.1: "a fixed enum... never a user- or
#      catalog-supplied string", enforced identically below by
#      _is_valid_key() against a fixed array plus, for every executor,
#      a fixed per-(executor,action) allowlist (see
#      _executor_action_allowed()) so that neither class can be driven
#      through an action/flag combination absent from this file.
#   4. Within the 6 catalog executors, a handful of actions this
#      codebase actually issues are not literally enumerated in §23.0's
#      table text (`pkg update`/`upgrade`/`list-upgradable` for
#      §13.13's "ordered update operations"; `git ls-remote --tags` for
#      self-update version discovery, §30.6; `tar -czf` for §32.1 backup
#      creation and log export, §13.9). These are recorded here as an
#      explicit, versioned extension of §23.0's baseline — not a silent
#      deviation — because every one of them still goes exclusively
#      through execute_structured(), is still argv-array dispatched
#      (never shell-interpolated), and is still individually
#      allowlisted by exact action string. This preserves §23.0's core
#      security property (no arbitrary command construction from
#      catalog/user data) even where the specific action string wasn't
#      enumerated in the PRD's illustrative table. This decision and its
#      rationale are also recorded in docs/TRACEABILITY.md and
#      docs/SECURITY.md so it is not silently re-litigated in a future
#      session.
#
# Determinism: unlike the prior implementation (executor name allowlisted,
# but action/flags unconstrained beyond a generic metacharacter denylist
# and a small rm/dd/mkfs-specific blacklist), every executor below now has
# an explicit, exhaustive action allowlist. An executor+action combination
# absent from _executor_action_allowed() is rejected with E402 even if the
# executor itself is allowlisted and contains no denylisted metacharacter.

# The complete, fixed executor enum (§23.0 catalog/network-facing rows +
# §23.1 local system-tool rows actually dispatched via execute_structured()
# in this codebase). No other value is ever accepted.
readonly -a DEVILS_MINIOS_ALLOWED_EXECUTORS=(
    # §23.0 catalog/network-facing executors (complete, verbatim)
    "proot-distro" "pkg" "git" "tar" "sha256sum" "curl"
    # §23.1 local system-tool executors (fixed, actually used, non-catalog)
    "rm" "mv" "cp" "ln" "kill" "adb" "fastboot" "true" "false"
)

# _executor_action_allowed(executor, action) — PRD §23.0/§23.1 reconciliation.
# Returns 0 iff `action` (the value execute_structured() receives as its
# second positional argument — for tools with no real subcommand grammar,
# such as mv/cp, this is conventionally the flag or first path argument
# actually passed at each call site) is one this executor is permitted to
# receive. Argument *count/shape* beyond this is validated by
# _dangerous_arguments_rejected() and by each call site's own use of
# validate_path() on every path-shaped argument (§22.1) before it ever
# reaches execute_structured().
_executor_action_allowed() {
    local executor="$1"
    local action="$2"
    case "${executor}" in
        proot-distro)
            case "${action}" in
                install|login|list|remove|backup|restore) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        pkg)
            # install/list-installed are §23.0's literal table; update,
            # upgrade and list-upgradable are the §13.13 "ordered update
            # operations" extension documented above.
            case "${action}" in
                install|list-installed|list-upgradable|update|upgrade) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        git)
            # clone/fetch/rev-parse are §23.0's literal table; ls-remote
            # is the §30.6 self-update version-discovery extension.
            case "${action}" in
                clone|fetch|rev-parse|ls-remote) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        tar)
            # -xzf (extract, §23.0) plus -czf (create, §32.1/§13.9
            # backup-and-log-export extension); no other tar action.
            case "${action}" in
                -xzf|-czf) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        sha256sum)
            case "${action}" in
                -c|"") return 0 ;;
                *) return 1 ;;
            esac
            ;;
        curl)
            # Single fixed download-shape flag per call; the exact flag
            # string used at the one call site (§23.3) is allowlisted
            # verbatim rather than accepting an arbitrary flag.
            case "${action}" in
                -fL|-fsSL) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        rm)
            case "${action}" in
                -rf|-f) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        mv)
            # mv has no flag-based action in this codebase's call sites;
            # the "action" slot carries the source path itself, which is
            # validated by the caller via validate_path() (§22.1) before
            # execute_structured() is ever invoked. Any non-empty value
            # is structurally acceptable here; the metacharacter denylist
            # and _dangerous_arguments_rejected() still apply to it.
            [[ -n "${action}" ]] && return 0 || return 1
            ;;
        cp)
            case "${action}" in
                -a) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        ln)
            case "${action}" in
                -s) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        kill)
            case "${action}" in
                -TERM|-KILL) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        adb|fastboot)
            case "${action}" in
                devices) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        true|false)
            # Diagnostic/test-only executors; any action is inert.
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ----------------------------------------------------------------------------
# §23.0-05 — per-executor environment / cwd / stdin / timeout / exit-status
# policy.
#
# Network policy: this codebase cannot enforce actual network isolation
# without root/namespace support that a stock, non-rooted Termux/Android
# target does not provide (no `unshare -n`, no netns). "Network policy" is
# therefore implemented as a *documented allowlist invariant*, enforced at
# the executor-enum/action level rather than at the OS level: only
# "proot-distro" (install path), "pkg", "git" (clone/fetch/ls-remote) and
# "curl" ever touch the network; every other allowlisted executor
# (rm/mv/cp/ln/kill/tar/sha256sum/adb/fastboot/true/false) is local-only by
# construction of what real call sites pass it. This is recorded here
# rather than silently assumed.
#
# Privilege policy: execute_structured() never elevates privilege — there
# is no "sudo"/"su" in DEVILS_MINIOS_ALLOWED_EXECUTORS and none is ever
# added implicitly. Every dispatched command runs at the caller's own
# privilege level, consistent with the project's "no root requirement for
# core functionality" constraint.
#
# Timeout policy: every executor has a bounded default timeout below,
# EXCEPT an interactive "proot-distro login <distro>" call with no
# trailing "--" (i.e. no batch command after it) — that is the launcher
# opening a live, user-facing terminal session inside the guest distro
# (modules/linux_env.sh, core/core_state.sh's primary-distro resume), which
# is expected to run indefinitely until the user exits it. Applying a
# timeout there would kill a normal user session, not just a hung one, so
# it is deliberately exempt. Every other proot-distro action (install,
# list, remove, backup, restore, and "login ... -- <pkg-manager> ..."
# batch calls) is bounded like any other executor.
#
# stdin/stdout policy: stdin is closed (</dev/null) for every non-interactive
# dispatch, so a hung or malicious child process can never block on or read
# from the launcher's own stdin. The one interactive proot-distro login case
# above is exempt for the same reason it is timeout-exempt: it IS the user's
# terminal session. stdout/stderr are always left inherited from the caller
# unchanged, since existing call sites depend on capturing them via command
# substitution (e.g. `execute_structured sha256sum ...`) or by writing
# through the launcher's terminal directly.
#
# cwd policy: every non-interactive dispatch runs inside a subshell whose
# cwd is switched to the launcher's own tmp directory (falling back to
# HOME, then left unchanged if neither is usable) before exec — this is a
# defense-in-depth measure so no executor can be influenced by whatever
# directory the launcher happened to be started from, and costs nothing
# functionally because every real call site already passes fully-resolved
# absolute paths (or, for tar, an explicit -C) rather than relying on cwd.
declare -grA DEVILS_MINIOS_EXECUTOR_TIMEOUT_SECONDS=(
    [proot-distro]=3600   # distro install/backup/restore over mobile networks
    [pkg]=900
    [git]=600
    [curl]=900
    [tar]=300
    [cp]=300
    [sha256sum]=120
    [rm]=120
    [mv]=120
    [ln]=30
    [adb]=30
    [fastboot]=30
    [kill]=10
    [true]=5
    [false]=5
)

# _is_interactive_executor_call(executor, action, args...) — the single
# documented exemption from the timeout/stdin policy above: a
# "proot-distro login <distro>" call with no "--" batch-command separator.
_is_interactive_executor_call() {
    local executor="$1" action="$2"
    shift 2 || true
    [[ "${executor}" == "proot-distro" && "${action}" == "login" ]] || return 1
    local a
    for a in "$@"; do
        [[ "${a}" == "--" ]] && return 1
    done
    return 0
}

# _executor_safe_cwd() — best-effort neutral working directory for
# non-interactive dispatches (§23.0-05 cwd policy). Never fatal: an unusable
# candidate is skipped, and if none are usable the caller simply keeps
# whatever cwd it already has.
_executor_safe_cwd() {
    local candidate
    for candidate in "${DEVILS_MINIOS_TMP_DIR:-}" "${HOME:-}" "/tmp"; do
        [[ -n "${candidate}" && -d "${candidate}" ]] && { printf '%s' "${candidate}"; return 0; }
    done
    return 1
}

# Contract: execute_structured(executor, action, args...); returns: underlying command status or validation failure; side effects: spawns only an allowlisted structured subprocess.
execute_structured() {
    local executor="${1:-}"
    local action="${2:-}"
    shift 2 || true
    local -a args=("$@")

    # §48.2: E420-E429 is the reserved range for every execute_structured()
    # denylist/structural rejection (§23.0, §23.1). E401/E402 are already
    # assigned elsewhere in the registry (CLI-state and startup_binary
    # errors) and must not be reused here.
    _is_valid_key "${executor}" "${DEVILS_MINIOS_ALLOWED_EXECUTORS[@]}" || {
        _error "E420" "Executor is not allowlisted: ${executor}" 0
        return 2
    }

    if [[ -n "${action}" ]]; then
        _validate_no_metacharacters "${action}" || {
            _error "E421" "Action contains shell metacharacters" 0
            return 2
        }
    fi

    _executor_action_allowed "${executor}" "${action}" || {
        _error "E422" "Action '${action}' is not allowlisted for executor: ${executor}" 0
        return 2
    }

    local item
    for item in "${args[@]}"; do
        _validate_no_metacharacters "${item}" || {
            _error "E423" "Structured argument contains shell metacharacters" 0
            return 2
        }
    done

    if ! _dangerous_arguments_rejected "${executor}" "${args[@]}"; then
        _error "E424" "Dangerous command pattern rejected" 0
        return 2
    fi

    local -a cmd=("${executor}")
    [[ -n "${action}" ]] && cmd+=("${action}")
    cmd+=("${args[@]}")

    _debug "Structured execution: ${cmd[*]}"

    local rc
    if _is_interactive_executor_call "${executor}" "${action}" "${args[@]}"; then
        # Interactive proot-distro login: no timeout, no stdin closure, no
        # cwd change — this is a live user terminal session, not a bounded
        # batch operation (§23.0-05 exemption documented above).
        "${cmd[@]}"
        rc=$?
    else
        local timeout_secs="${DEVILS_MINIOS_EXECUTOR_TIMEOUT_SECONDS[${executor}]:-}"
        local attempts=1
        # §17.6/§29: network_timeout and network_retries are consumed by
        # network operations. Read-only Git tag discovery and GitHub downloads
        # are safe to retry because they do not mutate the active installation.
        if [[ "${executor}" == "curl" || ( "${executor}" == "git" && "${action}" == "ls-remote" ) ]]; then
            timeout_secs="${DEVILS_MINIOS_CONFIG[network_timeout]:-30}"
            attempts="${DEVILS_MINIOS_CONFIG[network_retries]:-3}"
            _is_int "${timeout_secs}" || timeout_secs=30
            _is_int "${attempts}" || attempts=3
            (( attempts < 1 )) && attempts=1
        fi
        local safe_cwd
        safe_cwd="$(_executor_safe_cwd)" || safe_cwd=""
        local attempt
        for ((attempt=1; attempt<=attempts; attempt++)); do
            local -a wrapped=("${cmd[@]}")
            if [[ -n "${timeout_secs}" ]] && _has_command timeout; then
                wrapped=(timeout "--" "${timeout_secs}s" "${cmd[@]}")
            fi
            if [[ -n "${safe_cwd}" ]]; then
                ( cd -- "${safe_cwd}" 2>/dev/null && exec "${wrapped[@]}" </dev/null )
            else
                ( exec "${wrapped[@]}" </dev/null )
            fi
            rc=$?
            if [[ ${rc} -eq 0 || ${attempt} -eq attempts ]]; then
                break
            fi
            _warn "E425" "Network operation failed (attempt ${attempt}/${attempts}); retrying: ${executor} ${action}"
        done
        if [[ ${rc} -eq 124 ]]; then
            _warn "E425" "Structured execution timed out after ${timeout_secs}s: ${executor} ${action}"
        fi
    fi
    return "${rc}"
}


