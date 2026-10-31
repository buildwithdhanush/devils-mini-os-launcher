#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/settings.sh
# PRD Reference: §13.14, §17, §31, §33.1
# Public: settings_menu()
# Configuration editing, reset, export/import; all validation delegates to
# core.sh::validate_config()/import_config(). This module never parses or
# writes the config file directly outside of that contract; the reset
# actions here implement exactly the "Configuration reset" and "State
# reset" operations of §33.1 (Nuclear reset is Safe-Mode-only, §33.1/§40).

readonly DEVILS_MINIOS_BOOT_FILE="${HOME}/.termux/boot/devils-minios-autostart.sh"

_settings_view() {
    local width="${DEVILS_MINIOS_TERMINAL_WIDTH}"
    [[ ${width} -lt 40 ]] && width=60
    draw_box_top "${width}" "Current Configuration"
    local key
    for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
        draw_box_line "${width}" "$(printf '%-22s = %s' "${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}")"
    done
    draw_box_line "${width}" "--- runtime facts (read-only, refreshed every launch) ---"
    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        draw_box_line "${width}" "$(printf '%-22s = %s' "${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}")"
    done
    draw_box_bottom "${width}"
}

# Builds a strict key=value candidate file from the in-memory config plus one
# overridden key, then delegates the entire validation decision to
# core.sh::validate_config() (§17.4: "No module may parse or write
# configuration directly").
_settings_validate_candidate() {
    local override_key="$1"
    local override_value="$2"
    local candidate_file="${DEVILS_MINIOS_TMP_DIR}/settings-candidate.$$"
    mkdir -p "${DEVILS_MINIOS_TMP_DIR}"
    local key value
    {
        for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}" "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
            if [[ "${key}" == "${override_key}" ]]; then
                value="${override_value}"
            else
                value="${DEVILS_MINIOS_CONFIG[${key}]:-}"
            fi
            printf '%s=%s\n' "${key}" "${value}"
        done
    } > "${candidate_file}"
    if validate_config "${candidate_file}"; then
        rm -f "${candidate_file}"
        return 0
    fi
    rm -f "${candidate_file}"
    return 1
}

_settings_edit_key() {
    local key value
    printf 'Editable keys: %s\n' "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]}"
    key="$(_prompt_default 'Key to edit' '')"
    _is_valid_key "${key}" "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}" || {
        _error "E900" "Not an editable persisted_config key: ${key}" 0
        return 2
    }
    value="$(_prompt_default "New value for ${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}")"
    value="$(sanitize_input "${value}" 256)"
    if _settings_validate_candidate "${key}" "${value}"; then
        local old_value="${DEVILS_MINIOS_CONFIG[${key}]:-}"
        local old_log_level="${DEVILS_MINIOS_LOG_LEVEL:-INFO}"
        DEVILS_MINIOS_CONFIG["${key}"]="${value}"
        if ! save_config; then
            DEVILS_MINIOS_CONFIG["${key}"]="${old_value}"
            DEVILS_MINIOS_LOG_LEVEL="${old_log_level}"
            _error "E900" "Configuration update was not saved; previous value restored" 0
            return 1
        fi
        # DEVILS_MINIOS_LOG_LEVEL is declared -g in core.sh and consumed there
        # by the logging dispatcher; this module only assigns it, so
        # ShellCheck's single-file analysis flags a false-positive here.
        # shellcheck disable=SC2034
        [[ "${key}" == "log_level" ]] && DEVILS_MINIOS_LOG_LEVEL="${value}"
        _info "Configuration key '${key}' updated"
    else
        _error "E900" "Rejected: '${key}=${value}' fails configuration validation" 0
        return 2
    fi
}

# Configuration reset (§33.1): persisted_config only; state untouched.
_settings_reset_config() {
    _confirm "Reset configuration to defaults (state is not affected)" || return 0
    # _copy_config_assoc snapshots/restores this array through a nameref.
    # shellcheck disable=SC2034
    local -A old_config=()
    local old_log_level="${DEVILS_MINIOS_LOG_LEVEL:-INFO}"
    _copy_config_assoc DEVILS_MINIOS_CONFIG old_config
    if ! load_default_config || ! save_config; then
        _copy_config_assoc old_config DEVILS_MINIOS_CONFIG
        DEVILS_MINIOS_LOG_LEVEL="${old_log_level}"
        _error "E900" "Configuration reset failed; previous configuration retained" 0
        return 1
    fi
    # DEVILS_MINIOS_LOG_LEVEL is declared -g in core.sh and consumed there
    # by the logging dispatcher; this module only assigns it, so
    # ShellCheck's single-file analysis flags a false-positive here.
    # shellcheck disable=SC2034
    DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
    _info "Configuration reset to defaults"
}

# State reset (§33.1): state only; persisted_config untouched. Mirrors the
# equivalent Safe Mode action (core.sh::trigger_safe_mode()), including
# clearing the crash flag, since a reset state should not be immediately
# re-flagged by a stale crash marker.
_settings_reset_state() {
    _confirm "Reset state to defaults (configuration is not affected)" || return 0
    default_state
    save_state
    _clear_crash_flag
    _info "State reset to defaults"
}

_settings_export() {
    local dest
    dest="$(_prompt_default 'Export configuration to path' "${HOME}/devils-minios-config-$(date +%Y%m%d-%H%M%S).conf")"
    validate_path "${dest}" || { _error "$(_path_validation_error_code)" "Invalid destination path" 0; return 2; }
    local tmp_file="${dest}.tmp.$$"
    local key
    {
        for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
            printf '%s=%s\n' "${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}"
        done
    } > "${tmp_file}"
    mv -f "${tmp_file}" "${dest}"
    _info "Configuration exported to ${dest} (persisted_config keys only, per §17.7)"
}

_settings_import() {
    local src
    src="$(_prompt_default 'Import configuration from path' '')"
    validate_path "${src}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    [[ -f "${src}" ]] || { _error "E900" "Not a file: ${src}" 0; return 2; }
    if import_config "${src}"; then
        _info "Configuration imported from ${src}"
    else
        _error "E900" "Import rejected: file failed strict validation (§17.7)" 0
        return 2
    fi
}

_settings_auto_start_status() {
    if [[ -f "${DEVILS_MINIOS_BOOT_FILE}" ]] && grep -q 'devils-minios' "${DEVILS_MINIOS_BOOT_FILE}" 2>/dev/null; then
        printf 'enabled'
    else
        printf 'disabled'
    fi
}

# §31: the boot file must invoke a plain `devils-minios` (never --safe-mode).
_settings_auto_start_enable() {
    if [[ ! -d "${HOME}/.termux/boot" ]]; then
        _warn "" "Termux:Boot does not appear to be installed (no ~/.termux/boot); install the Termux:Boot app first. No action taken."
        return 0
    fi
    mkdir -p "${HOME}/.termux/boot"
    local tmp_file="${DEVILS_MINIOS_BOOT_FILE}.tmp.$$"
    {
        printf '#!/data/data/com.termux/files/usr/bin/sh\n'
        printf 'devils-minios\n'
    } > "${tmp_file}"
    chmod 700 "${tmp_file}"
    mv -f "${tmp_file}" "${DEVILS_MINIOS_BOOT_FILE}"
    _info "Auto-start enabled (${DEVILS_MINIOS_BOOT_FILE})"
}

_settings_auto_start_disable() {
    rm -f "${DEVILS_MINIOS_BOOT_FILE}"
    _info "Auto-start disabled (idempotent)"
}

_settings_toggle_auto_start() {
    if [[ "$(_settings_auto_start_status)" == "enabled" ]]; then
        _settings_auto_start_disable
    else
        _settings_auto_start_enable
    fi
}

# Contract: settings_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
settings_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Settings =="
        printf 'Termux:Boot auto-start: %s\n\n' "$(_settings_auto_start_status)"
        printf '%s\n' "1) View current configuration"
        printf '%s\n' "2) Edit a configuration key"
        printf '%s\n' "3) Reset configuration to defaults"
        printf '%s\n' "4) Reset state to defaults"
        printf '%s\n' "5) Export configuration"
        printf '%s\n' "6) Import configuration"
        printf '%s\n' "7) Toggle Termux:Boot auto-start"
        printf '%s\n' "8) Re-run first-run onboarding"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _settings_view; _pause "Press Enter to return to the menu" ;;
            2) _settings_edit_key ;;
            3) _settings_reset_config ;;
            4) _settings_reset_state ;;
            5) _settings_export ;;
            6) _settings_import ;;
            7) _settings_toggle_auto_start; sleep 1 ;;
            # §27.3: manual re-run re-creates the completion marker
            # idempotently. run_onboarding_force() is defined by the entry
            # point (devils-minios.sh); guard for standalone module use.
            8) if declare -F run_onboarding_force >/dev/null 2>&1; then
                   run_onboarding_force
               else
                   printf '%s\n' "Onboarding re-run is available from the launcher entry point."
                   sleep 1
               fi ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
