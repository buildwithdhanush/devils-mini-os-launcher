#!/usr/bin/env bash
# Devil's Mini OS Launcher - Main Entry Point
# Version: v1.0.0
# PRD Reference: §14, §15

set -euo pipefail

# ============================================================================
# BASH VERSION CHECK (§9) - runs before strict options rely on anything else
# ============================================================================

_check_bash_version() {
    local required_major=4
    local required_minor=3
    local current_major="${BASH_VERSINFO[0]}"
    local current_minor="${BASH_VERSINFO[1]}"

    if [[ "${current_major}" -lt "${required_major}" ]] || \
       [[ "${current_major}" -eq "${required_major}" && "${current_minor}" -lt "${required_minor}" ]]; then
        echo "ERROR: Bash ${required_major}.${required_minor} or higher required" >&2
        echo "Current version: ${BASH_VERSION}" >&2
        exit 1
    fi
}
_check_bash_version

# ============================================================================
# RESOLVE INSTALLATION PATH (symlink resolution)
# ============================================================================

_resolve_install_path() {
    local script_path="${BASH_SOURCE[0]}"
    while [[ -L "${script_path}" ]]; do
        local script_dir
        script_dir="$(cd "$(dirname "${script_path}")" && pwd)"
        script_path="$(readlink "${script_path}")"
        [[ "${script_path}" != /* ]] && script_path="${script_dir}/${script_path}"
    done
    DEVILS_MINIOS_ENTRY_POINT="$(cd "$(dirname "${script_path}")" && pwd)/$(basename "${script_path}")"
    DEVILS_MINIOS_INSTALL_DIR="$(dirname "${DEVILS_MINIOS_ENTRY_POINT}")"
}
_resolve_install_path

# ============================================================================
# LOAD CORE MODULE
# ============================================================================

_source_core() {
    local core_path="${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"
    if [[ ! -f "${core_path}" ]]; then
        echo "ERROR: Core module not found: ${core_path}" >&2
        exit 1
    fi
    # shellcheck source=modules/core.sh
    source "${core_path}"
}
_source_core

# ============================================================================
# LOAD SELF-UPDATE COMPONENT (split out for the PRD 500-line-per-file limit)
# ============================================================================

_source_self_update() {
    local su_path="${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    if [[ ! -f "${su_path}" ]]; then
        echo "ERROR: Self-update component not found: ${su_path}" >&2
        exit 1
    fi
    # shellcheck source=core/devils_self_update.sh
    source "${su_path}"
}
_source_self_update

# ============================================================================
# LOAD ONBOARDING COMPONENT (split out for the PRD 500-line-per-file limit)
# ============================================================================

_source_onboarding() {
    local ob_path="${DEVILS_MINIOS_INSTALL_DIR}/core/devils_onboarding.sh"
    if [[ ! -f "${ob_path}" ]]; then
        echo "ERROR: Onboarding component not found: ${ob_path}" >&2
        exit 1
    fi
    # shellcheck source=core/devils_onboarding.sh
    source "${ob_path}"
}
_source_onboarding


# ============================================================================
# CLI PARSING (§15)
# ============================================================================

declare -g FLAG_SAFE_MODE=false
declare -g FLAG_DEBUG=false
declare -g FLAG_OFFLINE=false
declare -g FLAG_NO_CHECKS=false
declare -g FLAG_RUN_MODULE=""
declare -g FLAG_UPDATE=false
declare -g FLAG_UNINSTALL=false
declare -g FLAG_UNINSTALL_AUTO_START=false
declare -g FLAG_ANY_PRESENT=false

_parse_cli() {
    while [[ $# -gt 0 ]]; do
        FLAG_ANY_PRESENT=true
        case "$1" in
            -h|--help) _show_help; exit 0 ;;  # §15 rule 1: terminate immediately, first wins
            -v|--version) _show_version; exit 0 ;;
            --safe-mode) FLAG_SAFE_MODE=true; shift ;;
            --debug) FLAG_DEBUG=true; shift ;;
            --offline) FLAG_OFFLINE=true; shift ;;
            --no-checks) FLAG_NO_CHECKS=true; shift ;;
            --run-module)
                if [[ $# -lt 2 ]]; then
                    _error "E400" "--run-module requires a module name" 2
                    exit 2
                fi
                FLAG_RUN_MODULE="$2"
                shift 2
                ;;
            --update) FLAG_UPDATE=true; shift ;;
            --uninstall) FLAG_UNINSTALL=true; shift ;;
            --uninstall-auto-start) FLAG_UNINSTALL_AUTO_START=true; shift ;;
            *)
                _error "E400" "Unknown option: $1" 2
                exit 2
                ;;
        esac
    done
}

# Canonical --run-module aliases (§15). Echoes the canonical dispatch_module
# name, or returns 1 for an unknown alias (including the removed future|roadmap).
_resolve_run_module_alias() {
    case "$1" in
        linux_env) printf 'linux_env' ;;
        file_mgr|files) printf 'file_mgr' ;;
        termux_apps) printf 'termux_apps' ;;
        proot_apps) printf 'proot_apps' ;;
        desktop_env|desktops) printf 'linux_env' ;;
        android_tools|android) printf 'android_tools' ;;
        workspace) printf 'workspace' ;;
        health_check|doctor) printf 'health_check' ;;
        logs) printf 'logs' ;;
        customize|theme) printf 'customize' ;;
        system_tools|tools) printf 'system_tools' ;;
        system_info|info) printf 'system_info' ;;
        update) printf 'update' ;;
        settings) printf 'settings' ;;
        *) return 1 ;;
    esac
}

_show_help() {
    cat <<EOF
Devil's Mini OS Launcher v${DEVILS_MINIOS_VERSION}

Usage: devils-minios [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --version           Show version information
  --safe-mode             Force safe mode entry
  --debug                 Enable debug logging for this session
  --offline               Disable network operations
  --no-checks             Skip non-critical startup diagnostics
  --run-module <module>   Launch a specific module directly
  --update                Update launcher to latest version
  --uninstall             Uninstall launcher (only from IDLE state)
  --uninstall-auto-start  Remove auto-start configuration

Supported architectures: aarch64, x86_64
Platform: Termux on Android (API 29+)

For more information, see: ${DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL}
EOF
}

_show_version() {
    echo "Devil's Mini OS Launcher v${DEVILS_MINIOS_VERSION}"
}

# CLI precedence (D13, §15) validated before any dispatch.
_validate_cli_precedence() {
    local lifecycle_count=0
    [[ "${FLAG_UPDATE}" == true ]] && lifecycle_count=$((lifecycle_count + 1))
    [[ "${FLAG_UNINSTALL}" == true ]] && lifecycle_count=$((lifecycle_count + 1))
    [[ "${FLAG_UNINSTALL_AUTO_START}" == true ]] && lifecycle_count=$((lifecycle_count + 1))
    if [[ ${lifecycle_count} -gt 1 ]]; then
        _error "E400" "Conflicting lifecycle commands" 2
        exit 2
    fi

    if [[ -n "${FLAG_RUN_MODULE}" ]] && ! _resolve_run_module_alias "${FLAG_RUN_MODULE}" >/dev/null; then
        _error "E400" "Unknown --run-module target: ${FLAG_RUN_MODULE}" 2
        exit 2
    fi
}

# ============================================================================
# CRASH TRAP / SIGNAL HANDLING (§14 step 9, §26, §28)
# ============================================================================

_crash_trap() {
    local exit_code=$?
    local line_no=${1:-0}
    [[ ${exit_code} -eq 0 ]] && return 0
    # A prior explicit E400/E401-class exit already logged its own message
    # and is not a "serious" crash per §26; only trap genuine failures.
    local count
    count="$(_record_serious_crash "unexpected failure near line ${line_no} (exit ${exit_code})")"
    if [[ "${count}" -ge 3 ]]; then
        trigger_safe_mode "crash-loop threshold reached (${count} crashes in 10 minutes)"
    else
        trigger_safe_mode "unexpected failure (exit ${exit_code})"
    fi
    exit 1
}

_install_traps() {
    trap '_crash_trap ${LINENO}' ERR
    trap 'handle_sigint' INT
}

# ============================================================================
# INTERACTIVE MAIN MENU (§19)
# ============================================================================

_interactive_menu() {
    local choice module
    while true; do
        show_main_menu
        printf 'Choice: ' >&2
        if ! IFS= read -r choice; then
            choice="0"
        fi
        [[ -z "${choice}" ]] && choice="0"
        [[ "${choice}" == "0" ]] && { write_log_file "INFO" "Exiting launcher"; exit 0; }
        if module="$(main_menu_module_for_choice "${choice}")"; then
            DEVILS_MINIOS_CURRENT_STATE="MODULE_RUNNING"
            if dispatch_module "${module}"; then
                _enter_idle_state
            else
                _warn "" "Module '${module}' returned a non-zero status"
                _enter_idle_state
            fi
            _confirm "Return to main menu" || true
        else
            printf 'Invalid selection.\n'
            sleep 1
        fi
    done
}

# ============================================================================
# NON-CRITICAL STARTUP DIAGNOSTICS (§14 step 12, §15 --no-checks)
# Update check, battery and storage notices only. Never blocks, never
# prompts. Security checks, platform checks, config/state validation and
# Safe Mode diagnostics are handled elsewhere and are never gated here.
# ============================================================================

_check_for_update_notice() {
    [[ "${DEVILS_MINIOS_OFFLINE_MODE}" == true ]] && return 0
    [[ "${DEVILS_MINIOS_CONFIG[check_updates]:-false}" == true ]] || return 0
    _has_command git || return 0

    local repo_url="${DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL}"
    [[ "${repo_url}" == https://github.com/* ]] || return 0

    # Network timeout/retry policy is enforced centrally by execute_structured().
    local raw_tags
    raw_tags="$(execute_structured git "ls-remote" "--tags" "${repo_url}" 2>/dev/null)" || return 0
    [[ -n "${raw_tags}" ]] || return 0

    local -a candidates=()
    local line tag
    while IFS= read -r line; do
        tag="${line##*refs/tags/}"
        tag="${tag%\^\{\}}"
        [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && candidates+=("${tag}")
    done <<< "${raw_tags}"
    [[ ${#candidates[@]} -gt 0 ]] || return 0

    local current="v${DEVILS_MINIOS_VERSION}"
    local best="" c
    for c in "${candidates[@]}"; do
        if _semver_gt "${c}" "${current}" && { [[ -z "${best}" ]] || _semver_gt "${c}" "${best}"; }; then
            best="${c}"
        fi
    done
    [[ -n "${best}" ]] && _info "Update available: ${best} (current ${current}). Run --update to install."
    return 0
}

_run_startup_diagnostics() {
    [[ "${DEVILS_MINIOS_NO_CHECKS}" == true ]] && return 0
    [[ "${DEVILS_MINIOS_SAFE_MODE}" == true ]] && return 0

    local percent
    if percent="$(_get_battery_percent 2>/dev/null)" && [[ ${percent} -le 20 ]]; then
        _info "Battery at ${percent}%."
    fi

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}" 2>/dev/null \
        || _warn "E603" "Insufficient storage for the default heavy operation (see check_storage_threshold)"

    _check_for_update_notice
    return 0
}

# ============================================================================
# CLI DISPATCH (§15)
# ============================================================================

_apply_cli_session_overrides() {
    # §14 step 12: session modifiers are applied before onboarding and CLI
    # dispatch, and never written to persistent configuration.
    # shellcheck disable=SC2034
    [[ "${FLAG_DEBUG}" == true ]] && { DEVILS_MINIOS_DEBUG_MODE=true; DEVILS_MINIOS_LOG_LEVEL=DEBUG; }
    [[ "${FLAG_OFFLINE}" == true ]] && DEVILS_MINIOS_OFFLINE_MODE=true
    [[ "${FLAG_NO_CHECKS}" == true ]] && DEVILS_MINIOS_NO_CHECKS=true
    _debug "CLI session overrides applied: debug=${DEVILS_MINIOS_DEBUG_MODE} offline=${DEVILS_MINIOS_OFFLINE_MODE} no_checks=${DEVILS_MINIOS_NO_CHECKS}"
}

_dispatch_cli() {

    # DEVILS_MINIOS_DEBUG_MODE and DEVILS_MINIOS_LOG_LEVEL are declared -g in
    # core.sh and consumed there (logging level dispatch) and exported for
    # child processes; this file only assigns them, so ShellCheck's
    # single-file analysis flags a false-positive unused-variable warning.
    _run_startup_diagnostics

    if [[ "${FLAG_UPDATE}" == true ]]; then
        _self_update
    fi

    if [[ "${FLAG_UNINSTALL}" == true ]]; then
        if [[ "${DEVILS_MINIOS_CURRENT_STATE}" != "IDLE" ]]; then
            _error "E401" "--uninstall is only valid from IDLE (current: ${DEVILS_MINIOS_CURRENT_STATE})" 2
        fi
        if _confirm "Uninstall Devil's Mini OS Launcher (user state and Proot environments are preserved)"; then
            validate_path "${DEVILS_MINIOS_INSTALL_DIR}" "${PREFIX}/opt" || {
                _error "$(_path_validation_error_code)" "Invalid installation path; uninstall refused" 0
                exit 2
            }
            [[ -d "${DEVILS_MINIOS_INSTALL_DIR}" && ! -L "${DEVILS_MINIOS_INSTALL_DIR}" ]] || {
                _error "E401" "Installation directory is invalid or symlinked; uninstall refused" 0
                exit 2
            }
            validate_path "${DEVILS_MINIOS_INSTALL_DIR}" "${PREFIX}/opt" || {
                _error "$(_path_validation_error_code)" "Installation path changed before uninstall" 0
                exit 2
            }
            record_state_transition "UNINSTALLED"
            execute_structured rm "-rf" "${DEVILS_MINIOS_INSTALL_DIR}" || {
                _error "E900" "Uninstall deletion failed" 0
                exit 1
            }
            _info "Uninstall complete; ${DEVILS_MINIOS_CONFIG_DIR} and Proot environments were preserved"
        fi
        exit 0
    fi

    if [[ "${FLAG_UNINSTALL_AUTO_START}" == true ]]; then
        local boot_file="${HOME}/.termux/boot/devils-minios-autostart.sh"
        rm -f "${boot_file}"
        _info "Auto-start file removed (idempotent)"
        exit 0
    fi

    if [[ -n "${FLAG_RUN_MODULE}" ]]; then
        local module
        module="$(_resolve_run_module_alias "${FLAG_RUN_MODULE}")"
        DEVILS_MINIOS_CURRENT_STATE="MODULE_RUNNING"
        dispatch_module "${module}"
        _enter_idle_state
        exit $?
    fi

    # auto_launch (§27.5): only with zero CLI flags.
    if [[ "${FLAG_ANY_PRESENT}" == false && "${DEVILS_MINIOS_CONFIG[auto_launch]:-false}" == true \
          && -n "${DEVILS_MINIOS_STATE[last_successful_workflow]:-}" ]]; then
        local workflow="${DEVILS_MINIOS_STATE[last_successful_workflow]}"
        local wf_module="${workflow%%|*}"
        if _resolve_run_module_alias "${wf_module}" >/dev/null 2>&1; then
            DEVILS_MINIOS_CURRENT_STATE="MODULE_RUNNING"
            dispatch_module "$(_resolve_run_module_alias "${wf_module}")" || true
            _enter_idle_state
            # §27.5: bare auto-launch executes the recorded workflow instead
            # of falling through into the interactive main menu.
            return 0
        fi
    fi

    _interactive_menu
}

# ============================================================================
# MAIN (§14 - deterministic startup sequence)
# ============================================================================

_main() {
    _parse_cli "$@"
    _validate_cli_precedence

    core_init
    _install_traps
    warn_play_store

    if [[ "${FLAG_SAFE_MODE}" == true ]]; then
        trigger_safe_mode "--safe-mode flag"
    else
        local crash_status
        crash_status="$(_check_crash_flag)"
        if [[ "${crash_status}" == "active" ]]; then
            trigger_safe_mode "active crash flag detected"
        fi
    fi

    if [[ "${DEVILS_MINIOS_CURRENT_STATE}" == "UNINSTALLED" || "${DEVILS_MINIOS_CURRENT_STATE}" == "FIRST_BOOT" ]]; then
        DEVILS_MINIOS_CURRENT_STATE="FIRST_BOOT"
    fi

    _apply_cli_session_overrides
    # §27.1 trigger: onboarding runs when the marker is absent OR when
    # onboarding_completion is false (both signals are kept in sync by the
    # same write). --safe-mode skips onboarding (§27.1).
    if [[ "${FLAG_SAFE_MODE}" != true ]] && { [[ ! -f "${DEVILS_MINIOS_ONBOARDING_MARKER}" ]] \
        || [[ "${DEVILS_MINIOS_STATE[onboarding_completion]:-false}" != true ]]; }; then
        _run_onboarding
    else
        _enter_idle_state
    fi

    _dispatch_cli
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
