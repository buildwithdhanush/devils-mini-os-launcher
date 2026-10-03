#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_state.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# Covers persistent state, the state machine, resource gates, and
# signal handling / crash recording / safe mode.
# PRD Reference: §25, §26, §26.3, §26.4, §28, §39, §40
# ============================================================================
# PERSISTENT STATE (§26.3, §26.4)
# ============================================================================
_validate_state_values() {
    local -n st_ref="$1"
    [[ "${st_ref[state_version]:-}" == "${DEVILS_MINIOS_STATE_VERSION}" ]] || {
        _warn "E405" "state_version must be ${DEVILS_MINIOS_STATE_VERSION}"
        return 1
    }
    _is_bool "${st_ref[onboarding_completion]:-}" || {
        _warn "E405" "Invalid onboarding_completion value"
        return 1
    }
    local value
    for key in primary_distro last_successful_workflow crash_loop_state; do
        value="${st_ref[${key}]:-}"
        [[ "${value}" != *".."* && "${value}" != *$'\n'* ]] || {
            _warn "E405" "Unsafe state value for ${key}"
            return 1
        }
    done
    if [[ -n "${st_ref[last_successful_workflow]:-}" ]] &&
       [[ ! "${st_ref[last_successful_workflow]}" =~ ^[a-z0-9_][a-z0-9_-]*\|[a-z0-9_][a-z0-9_-]*\|[A-Za-z0-9._-]+$ ]]; then
        _warn "E405" "Invalid last_successful_workflow typed value"
        return 1
    fi
    return 0
}
# Contract: default_state(none); returns: 0 on success, non-zero on failure; side effects: may mutate launcher state according to the function purpose.
default_state() {
    # DEVILS_MINIOS_STATE is first declared -gA in modules/core.sh. Repeating
    # the same attributes here (declare -gA, same global, same contents
    # semantics) lets ShellCheck, which analyzes this file standalone, see
    # that the literal [key]= subscripts are associative keys, not variables.
    declare -gA DEVILS_MINIOS_STATE=(
        [state_version]="${DEVILS_MINIOS_STATE_VERSION}"
        [primary_distro]=""
        [last_successful_workflow]=""
        [onboarding_completion]="false"
        [crash_loop_state]=""
    )
}
# _fsync_path: best-effort fsync of a single file (§26.4). Pure Bash plus
# standard coreutils only (no language runtime): prefers `dd conv=fsync`,
# which asks the kernel to fsync(2) the named file specifically, and falls
# back to a filesystem-wide `sync` on environments whose `dd` lacks
# conv=fsync (e.g. a toybox/busybox dd). Never fatal.
_fsync_path() {
    local target="$1"
    if command -v dd >/dev/null 2>&1 && \
       dd if=/dev/null of="${target}" conv=notrunc,fsync count=0 status=none 2>/dev/null; then
        return 0
    fi
    sync 2>/dev/null || true
    return 0
}
# Contract: save_state(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
save_state() {
    mkdir -p "${DEVILS_MINIOS_CONFIG_DIR}"
    local tmp_file="${DEVILS_MINIOS_STATE_FILE}.tmp.$$"
    local bak_tmp="${DEVILS_MINIOS_STATE_BACKUP}.tmp.$$"
    local key
    # 1. Write the new state to a temp file in the same directory and fsync it.
    (
        umask 077
        {
            for key in "${DEVILS_MINIOS_STATE_KEYS[@]}"; do
                printf '%s=%s\n' "${key}" "${DEVILS_MINIOS_STATE[${key}]:-}"
            done
        } > "${tmp_file}"
    )
    _fsync_path "${tmp_file}"
    # 2/3. Atomically create/update state.bak from the previous valid state
    # BEFORE it is replaced, via its own temp+rename, and fsync that backup
    # too — so a last-known-good copy always exists once at least one
    # successful write has occurred (§26.4).
    if [[ -f "${DEVILS_MINIOS_STATE_FILE}" ]]; then
        (
            umask 077
            cp -f "${DEVILS_MINIOS_STATE_FILE}" "${bak_tmp}"
        )
        _fsync_path "${bak_tmp}"
        mv -f "${bak_tmp}" "${DEVILS_MINIOS_STATE_BACKUP}"
        chmod 600 "${DEVILS_MINIOS_STATE_BACKUP}" 2>/dev/null || true
    fi
    # 4. Atomic rename of the new state into place (same filesystem).
    mv -f "${tmp_file}" "${DEVILS_MINIOS_STATE_FILE}"
    chmod 600 "${DEVILS_MINIOS_STATE_FILE}"
}
# Contract: validate_state(state_file); returns: 0 when valid, non-zero when rejected; side effects: none.
validate_state() {
    local state_file="${1:-${DEVILS_MINIOS_STATE_FILE}}"
    local -A parsed=()
    local allowed_flat="${DEVILS_MINIOS_STATE_KEYS[*]}"
    _parse_strict_kv_file "${state_file}" parsed "${allowed_flat}" || return 1
    _validate_state_values parsed || return 1
    local key
    for key in "${DEVILS_MINIOS_STATE_KEYS[@]}"; do
        [[ -n "${parsed[${key}]+x}" ]] || return 1
    done
    return 0
}
# Contract: restore_state_from_backup(none); returns: 0 on success, non-zero on failure; side effects: loads or restores runtime/config/state data.
restore_state_from_backup() {
    if [[ -f "${DEVILS_MINIOS_STATE_BACKUP}" ]] && validate_state "${DEVILS_MINIOS_STATE_BACKUP}"; then
        local restore_tmp="${DEVILS_MINIOS_STATE_FILE}.tmp.$$"
        (
            umask 077
            cp -f "${DEVILS_MINIOS_STATE_BACKUP}" "${restore_tmp}"
        )
        _fsync_path "${restore_tmp}"
        mv -f "${restore_tmp}" "${DEVILS_MINIOS_STATE_FILE}"
        chmod 600 "${DEVILS_MINIOS_STATE_FILE}" 2>/dev/null || true
        # §48.2 E406: persistent state corruption where state.bak is valid -
        # this is load_state()'s self-healing restoration path (§26.4), not
        # generic crash recording (that fallback is E900; see
        # _record_serious_crash() below).
        _warn "E406" "State corrupted; restored from last-known-good backup"
        return 0
    fi
    _warn "E405" "State backup invalid or absent; reinitialized defaults"
    return 1
}
# Contract: load_state(none); returns: 0 on success, non-zero on failure; side effects: loads or restores runtime/config/state data.
load_state() {
    mkdir -p "${DEVILS_MINIOS_CONFIG_DIR}"
    local -A parsed=()
    local allowed_flat="${DEVILS_MINIOS_STATE_KEYS[*]}"
    if [[ -f "${DEVILS_MINIOS_STATE_FILE}" ]]; then
        if _parse_strict_kv_file "${DEVILS_MINIOS_STATE_FILE}" parsed "${allowed_flat}" && _validate_state_values parsed; then
            _copy_config_assoc parsed DEVILS_MINIOS_STATE
            return 0
        fi
        _warn "E405" "Persistent state is corrupt"
    fi
    if restore_state_from_backup; then
        if _parse_strict_kv_file "${DEVILS_MINIOS_STATE_FILE}" parsed "${allowed_flat}" && _validate_state_values parsed; then
            _copy_config_assoc parsed DEVILS_MINIOS_STATE
            return 0
        fi
    fi
    default_state
    if ! save_state; then
        _warn "E703" "Persistent state could not be regenerated after corruption"
        return 1
    fi
    # The caller maps an unrecoverable persistent-state condition to the
    # lifecycle recovery path; never claim recovery succeeded here.
    DEVILS_MINIOS_STATE_RECOVERY_REINITIALIZED=true
    return 0
}
# ============================================================================
# STATE MACHINE (§39)
# ============================================================================
_is_valid_transition() {
    local from="$1"
    local to="$2"
    case "${from}->${to}" in
        "UNINSTALLED->INSTALLING"|"INSTALLING->FIRST_BOOT"|"INSTALLING->UNINSTALLED"|\
        "FIRST_BOOT->ONBOARDING"|"FIRST_BOOT->IDLE"|"FIRST_BOOT->RECOVERY"|"FIRST_BOOT->SAFE_MODE"|\
        "ONBOARDING->IDLE"|"ONBOARDING->FIRST_BOOT"|\
        "IDLE->MODULE_RUNNING"|"MODULE_RUNNING->IDLE"|"IDLE->SAFE_MODE"|"MODULE_RUNNING->RECOVERY"|\
        "RECOVERY->IDLE"|"RECOVERY->SAFE_MODE"|"SAFE_MODE->RECOVERY"|"SAFE_MODE->IDLE"|\
        "RECOVERY->FIRST_BOOT"|"IDLE->UNINSTALLED"|"IDLE->UPDATING"|"UPDATING->IDLE"|\
        "UPDATING->SAFE_MODE")
            return 0 ;;
        *) return 1 ;;
    esac
}
# Contract: record_state_transition(target_state); returns: 0 on success, non-zero on failure/abort; side effects: updates lifecycle/recovery state and may log diagnostics.
record_state_transition() {
    local to="$1"
    if ! _is_valid_transition "${DEVILS_MINIOS_CURRENT_STATE}" "${to}"; then
        _error "E400" "Invalid state transition: ${DEVILS_MINIOS_CURRENT_STATE} -> ${to}" 0
        return 2
    fi
    DEVILS_MINIOS_LAST_STATE="${DEVILS_MINIOS_CURRENT_STATE}"
    DEVILS_MINIOS_CURRENT_STATE="${to}"
    write_log_file "INFO" "State transition: ${DEVILS_MINIOS_LAST_STATE} -> ${DEVILS_MINIOS_CURRENT_STATE}"
    if [[ "${to}" == IDLE ]]; then
        # Covers §26.5 stage 5 generally and stage 6 specifically for
        # RECOVERY -> IDLE. The helper is idempotent and preserves the crash window.
        _clear_crash_flag_on_idle
    fi
    return 0
}
# ============================================================================
# RESOURCE GATES (§25)
# ============================================================================
# ============================================================================
# SIGNAL HANDLING, CRASH RECORDING, SAFE MODE (§26, §28, §39, §40)
# ============================================================================
# Contract: handle_sigint(none); returns: 0 on success, non-zero on failure/abort; side effects: updates lifecycle/recovery state and may log diagnostics.
handle_sigint() {
    printf '\n'
    if _confirm "Are you sure you want to exit?"; then
        write_log_file "INFO" "Exit via SIGINT confirmed"
        exit 130
    fi
    return 0
}
# Writes a crash record, updates the rolling crash-timestamp window in
# persistent state, and (re)writes the normalized crash flag (§26, §26.5).
# Returns the number of serious crashes within the active 10-minute window.
_record_serious_crash() {
    local context="${1:-unknown}"
    # §26.5 stages 5/6: this session has recorded a new serious crash, so
    # reaching IDLE later must not clear the crash flag created by this crash.
    DEVILS_MINIOS_SESSION_CRASH_RECORDED=true
    local now
    now="$(date +%s)"
    mkdir -p "${DEVILS_MINIOS_CRASH_DIR}"
    local crash_file="${DEVILS_MINIOS_CRASH_DIR}/crash-${now}-$$.log"
    # §26: the crash record is written atomically (temp file + rename in the
    # same directory) and carries timestamp, error/context, current state,
    # platform, and relevant recent log context.
    local crash_tmp="${crash_file}.tmp.$$"
    {
        printf 'timestamp=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'context=%s\n' "${context}"
        printf 'state=%s\n' "${DEVILS_MINIOS_CURRENT_STATE}"
        printf 'platform=%s\n' "${DEVILS_MINIOS_PLATFORM}"
        printf 'recent_log_begin\n'
        tail -n 20 "$(get_log_file)" 2>/dev/null || true
        printf 'recent_log_end\n'
    } > "${crash_tmp}" 2>/dev/null && mv -f "${crash_tmp}" "${crash_file}" 2>/dev/null || rm -f "${crash_tmp}" 2>/dev/null || true
    local raw="${DEVILS_MINIOS_STATE[crash_loop_state]:-}"
    local -a window=()
    local ts
    if [[ -n "${raw}" ]]; then
        local -a raw_parts=()
        local IFS=","
        # shellcheck disable=SC2206
        raw_parts=(${raw})
        for ts in "${raw_parts[@]}"; do
            [[ "${ts}" =~ ^[0-9]+$ ]] || continue
            [[ $((now - ts)) -lt 600 ]] && window+=("${ts}")
        done
    fi
    window+=("${now}")
    local joined
    joined="$(IFS=,; printf '%s' "${window[*]}")"
    DEVILS_MINIOS_STATE[crash_loop_state]="${joined}"
    save_state || true
    local tmp_flag="${DEVILS_MINIOS_CRASH_FLAG}.tmp.$$"
    printf 'created_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "${tmp_flag}"
    mv -f "${tmp_flag}" "${DEVILS_MINIOS_CRASH_FLAG}"
    # §48.2 E900: a serious (trapped, uncategorized) crash has been recorded
    # against the crash-loop window, which is what ultimately drives the
    # caller's Safe Mode routing decision (§26, §40). E900 is the generic/
    # unclassified-failure fallback; E406 is reserved specifically for
    # load_state()'s own valid-backup restoration path above, not for
    # generic crash recording.
    _error "E900" "Serious crash recorded (${#window[@]} in active window): ${context}" 0
    printf '%s' "${#window[@]}"
}
# Reads and applies the crash-flag lifecycle (§26.5). Echoes "active",
# "stale", or "absent".
_check_crash_flag() {
    [[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] || { printf 'absent'; return 0; }
    local created_at line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" == created_at=* ]] && created_at="${line#created_at=}"
    done < "${DEVILS_MINIOS_CRASH_FLAG}"
    if [[ -z "${created_at:-}" ]]; then
        write_log_file "WARN" "Unparseable crash flag treated as active trigger (fail closed)"
        printf 'active'
        return 0
    fi
    local created_epoch now
    created_epoch="$(date -d "${created_at}" +%s 2>/dev/null || printf '0')"
    now="$(date +%s)"
    if [[ "${created_epoch}" != "0" && $(( now - created_epoch )) -gt 86400 ]]; then
        rm -f "${DEVILS_MINIOS_CRASH_FLAG}"
        write_log_file "WARN" "stale crash flag cleared; created_at=${created_at}"
        printf 'stale'
        return 0
    fi
    printf 'active'
}
# recover_runtime_temp_corrupt() — PRD §26.1 RUNTIME-TEMP-CORRUPT.
# Rebuilds a process-local runtime context or removes one named temporary
# artifact from the launcher-owned temp directory. The caller decides whether
# a failed recovery must escalate to Safe Mode; this function never silently
# treats a failed rebuild as success.
# Contract: recover_runtime_temp_corrupt(what); returns: 0 on success, non-zero on failure/abort; side effects: updates lifecycle/recovery state and may log diagnostics.
recover_runtime_temp_corrupt() {
    local what="${1:-}"
    write_log_file "WARN" "RUNTIME-TEMP-CORRUPT: rebuilding '${what}' from authoritative source"
    case "${what}" in
        runtime_context)
            if build_runtime_context; then
                if [[ "${DEVILS_MINIOS_TERMINAL_WIDTH:-}" =~ ^[0-9]+$ ]] &&
                   [[ "${DEVILS_MINIOS_TERMINAL_WIDTH}" -ge 1 ]] &&
                   [[ "${DEVILS_MINIOS_UI_MODE:-}" =~ ^(minimal|compact|full)$ ]]; then
                    write_log_file "INFO" "RUNTIME-TEMP-CORRUPT: runtime_context rebuilt successfully"
                    return 0
                fi
            fi
            write_log_file "ERROR" "RUNTIME-TEMP-CORRUPT: runtime_context rebuild failed"
            return 1
            ;;
        tmpfile:*)
            local name="${what#tmpfile:}"
            [[ -n "${name}" && "${name}" != *'/'* && "${name}" != *'..'* ]] || {
                write_log_file "ERROR" "RUNTIME-TEMP-CORRUPT: invalid temp artifact name"
                return 1
            }
            local target="${DEVILS_MINIOS_TMP_DIR}/${name}"
            if ! validate_path "${target}" "${DEVILS_MINIOS_TMP_DIR}"; then
                write_log_file "ERROR" "RUNTIME-TEMP-CORRUPT: temp artifact path rejected"
                return 1
            fi
            rm -f -- "${DEVILS_MINIOS_PATH_RESOLVED:-${target}}" 2>/dev/null || {
                write_log_file "ERROR" "RUNTIME-TEMP-CORRUPT: failed to discard temp artifact '${name}'"
                return 1
            }
            write_log_file "INFO" "RUNTIME-TEMP-CORRUPT: discarded temp artifact '${name}'"
            return 0
            ;;
        *)
            write_log_file "ERROR" "RUNTIME-TEMP-CORRUPT: unknown recovery target '${what}'"
            return 1
            ;;
    esac
}
# §26.5 stages 5/6: clear the crash marker only after a successful entry into
# IDLE in a session that has recorded no new serious crash. The crash-loop
# timestamps in persistent state are deliberately untouched.
_clear_crash_flag_on_idle() {
    if [[ "${DEVILS_MINIOS_SESSION_CRASH_RECORDED:-false}" == false && -f "${DEVILS_MINIOS_CRASH_FLAG}" ]]; then
        _clear_crash_flag
        write_log_file "INFO" "Crash flag cleared after successful IDLE entry"
    fi
}
# _enter_idle_state() centralizes direct IDLE assignments that do not use the
# state-transition API (startup/onboarding/menu return paths). It performs the
# same stage-5 lifecycle action as record_state_transition(... IDLE).
_enter_idle_state() {
    DEVILS_MINIOS_LAST_STATE="${DEVILS_MINIOS_CURRENT_STATE}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    write_log_file "INFO" "State reached: IDLE"
    _clear_crash_flag_on_idle
}
_clear_crash_flag() {
    rm -f "${DEVILS_MINIOS_CRASH_FLAG}" 2>/dev/null || true
}
# The single Safe Mode entry point (§40). Safe Mode Core never depends on
# Proot/Desktop availability (§40.1).
# Contract: trigger_safe_mode(reason); returns: 0 on success, non-zero on failure/abort; side effects: updates lifecycle/recovery state and may log diagnostics.
trigger_safe_mode() {
    local reason="${1:-unspecified}"
    DEVILS_MINIOS_LAST_STATE="${DEVILS_MINIOS_CURRENT_STATE}"
    DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"
    # DEVILS_MINIOS_SAFE_MODE is declared -g in modules/core.sh and exported
    # there; this file's own scope has no read of it, hence SC2034.
    # shellcheck disable=SC2034
    DEVILS_MINIOS_SAFE_MODE=true
    write_log_file "WARN" "Entering Safe Mode: ${reason}"
    local choice
    while true; do
        clear_screen
        printf '%s\n' "==================== SAFE MODE ===================="
        printf 'Reason: %s\n\n' "${reason}"
        printf '%s\n' "1) View recent log entries"
        printf '%s\n' "2) Repair configuration (reset to defaults)"
        printf '%s\n' "3) Repair state (reset to defaults)"
        printf '%s\n' "4) Nuclear reset (wipe config + state + cache)"
        if [[ -n "${DEVILS_MINIOS_STATE[primary_distro]:-}" ]]; then
            if _safe_mode_primary_distro_valid_p; then
                printf '%s\n' "5) Attempt to relaunch primary Proot distro"
            else
                printf '%s\n' "5) Proot relaunch unavailable (primary rootfs failed validation)"
            fi
        fi
        printf '%s\n' "0) Exit launcher"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1)
                tail -n 40 "$(get_log_file)" 2>/dev/null || printf 'No log entries yet.\n'
                _confirm "Continue" || true
                ;;
            2)
                _confirm "Reset configuration to defaults (state is not affected). Continue" || continue
                load_default_config
                if ! save_config || ! validate_config; then
                    _error "E703" "Safe Mode configuration repair could not be persisted and validated" 0
                    continue
                fi
                # §26.5 step 7: a Safe Mode repair that succeeds AND passes
                # validation also clears the crash flag.
                _clear_crash_flag
                _warn "" "Configuration reset to defaults"
                _enter_idle_state
                return 0
                ;;
            3)
                _confirm "Reset state to defaults (configuration is not affected). Continue" || continue
                default_state
                if ! save_state || ! validate_state; then
                    _error "E703" "Safe Mode state repair could not be persisted and validated" 0
                    continue
                fi
                _clear_crash_flag
                _warn "" "State reset to defaults"
                _enter_idle_state
                return 0
                ;;
            4)
                _confirm "Quarantine the entire configuration and perform nuclear reset. Continue" || continue
                nuclear_reset || true
                [[ "${DEVILS_MINIOS_CURRENT_STATE}" == FIRST_BOOT ]] && return 0
                ;;
            5)
                if _safe_mode_primary_distro_valid_p; then
                    # Revalidate immediately before the external launch.
                    execute_structured "proot-distro" "login" "${DEVILS_MINIOS_STATE[primary_distro]}" || true
                else
                    _warn "E203" "Primary Proot rootfs is unavailable or failed Safe Mode validation"
                fi
                ;;
            0)
                write_log_file "INFO" "Exiting launcher from Safe Mode"
                exit 0
                ;;
            *) : ;;
        esac
    done
}
# log_viewer.sh delegates mutation here so it never rotates/truncates/deletes
# logs directly (§13.9, §24 - core.sh is the sole writer).
# Contract: clear_logs(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
clear_logs() {
    local log_file="${DEVILS_MINIOS_LOG_DIR}/launcher.log"
    : > "${log_file}" 2>/dev/null || true
    rm -f "${log_file}".1 "${log_file}".2 "${log_file}".3 "${log_file}".4 2>/dev/null || true
    write_log_file "INFO" "Logs cleared by user request"
}
# Contract: check_storage_threshold(required_bytes); returns: 0 when gate passes, non-zero when unavailable/rejected; side effects: reads resource state and may log diagnostics.
check_storage_threshold() {
    local required_bytes="${1:-0}"
    _is_int "${required_bytes}" || required_bytes=0
    local target="${DEVILS_MINIOS_CONFIG_DIR}"
    [[ -d "${target}" ]] || target="${HOME}"
    local available
    available="$(df -B1 "${target}" 2>/dev/null | awk 'NR==2 {print $4}')"
    [[ "${available}" =~ ^[0-9]+$ ]] || {
        _warn "E900" "Storage availability is unavailable; proceeding with caution"
        return 0
    }
    local required_total=$((required_bytes + DEVILS_MINIOS_SAFETY_MARGIN_BYTES))
    if [[ ${available} -lt ${required_total} ]]; then
        # §48.2 E603: insufficient-storage is a specifically-registered code,
        # distinct from the generic E300 resource-check family used above for
        # "could not determine availability at all".
        _error "E603" "Insufficient storage: required ${required_total} bytes, available ${available} bytes" 0
        return 3
    fi
    return 0
}
_get_battery_percent() {
    _has_command termux-battery-status || return 3
    local json percent
    json="$(termux-battery-status 2>/dev/null || true)"
    percent="$(printf '%s' "${json}" | tr -d '\n' | sed -n 's/.*"percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    [[ "${percent}" =~ ^[0-9]+$ ]] || return 3
    printf '%s' "${percent}"
}
# Contract: check_battery_gate(operation); returns: 0 when gate passes, non-zero when unavailable/rejected; side effects: reads resource state and may log diagnostics.
check_battery_gate() {
    local operation="${1:-operation}"
    local percent
    if ! percent="$(_get_battery_percent)"; then
        if [[ "${DEVILS_MINIOS_BATTERY_WARNED}" != true ]]; then
            _warn "" "battery level unavailable; proceeding"
            DEVILS_MINIOS_BATTERY_WARNED=true
        fi
        return 0
    fi
    if [[ ${percent} -le 9 ]]; then
        _error "E900" "Battery at ${percent}%; ${operation} blocked until battery is above 9%" 0
        return 3
    elif [[ ${percent} -le 20 ]]; then
        printf 'Battery is at %s%%. This heavy operation may fail if power is lost.\n' "${percent}"
        _confirm "Continue with ${operation}?" || return 4
    fi
    return 0
}
