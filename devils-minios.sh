#!/usr/bin/env bash
# Devil's Mini OS Launcher - Main Entry Point
# Version: v1.0.0
# PRD Reference: §14, §15

set -euo pipefail

# ============================================================================
# BASH VERSION CHECK (§9)
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
# RESOLVE INSTALLATION PATH
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
# CLI PARSING (§15)
# ============================================================================

# CLI flags (reserved for future phase implementation)
# shellcheck disable=SC2034
declare -g FLAG_HELP=false
declare -g FLAG_VERSION=false
declare -g FLAG_SAFE_MODE=false
declare -g FLAG_DEBUG=false
declare -g FLAG_OFFLINE=false
declare -g FLAG_NO_CHECKS=false
declare -g FLAG_RUN_MODULE=""
declare -g FLAG_UPDATE=false
declare -g FLAG_UNINSTALL=false
declare -g FLAG_UNINSTALL_AUTO_START=false

_parse_cli() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                FLAG_HELP=true
                shift
                ;;
            -v|--version)
                FLAG_VERSION=true
                shift
                ;;
            --safe-mode)
                FLAG_SAFE_MODE=true
                shift
                ;;
            --debug)
                FLAG_DEBUG=true
                shift
                ;;
            --offline)
                FLAG_OFFLINE=true
                shift
                ;;
            --no-checks)
                # shellcheck disable=SC2034
                FLAG_NO_CHECKS=true
                shift
                ;;
            --run-module)
                if [[ $# -lt 2 ]]; then
                    _error "E400" "--run-module requires a module name" 0
                    exit 2
                fi
                FLAG_RUN_MODULE="$2"
                shift 2
                ;;
            --update)
                FLAG_UPDATE=true
                shift
                ;;
            --uninstall)
                FLAG_UNINSTALL=true
                shift
                ;;
            --uninstall-auto-start)
                FLAG_UNINSTALL_AUTO_START=true
                shift
                ;;
            *)
                _error "E400" "Unknown option: $1" 0
                exit 2
                ;;
        esac
    done
}

# ============================================================================
# CLI DISPATCH (§15)
# ============================================================================

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
  --uninstall             Uninstall launcher
  --uninstall-auto-start  Remove auto-start configuration

Supported architectures: aarch64, x86_64
Platform: Termux on Android (API 29+)

For more information, see: https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher
EOF
}

_show_version() {
    echo "Devil's Mini OS Launcher v${DEVILS_MINIOS_VERSION}"
}

_validate_cli_precedence() {
    local conflict_count=0
    
    # Safe arithmetic to prevent 'set -e' from triggering on ((0++))
    if [[ "${FLAG_HELP}" == true ]]; then
        conflict_count=$((conflict_count + 1))
    fi
    if [[ "${FLAG_VERSION}" == true ]]; then
        conflict_count=$((conflict_count + 1))
    fi
    
    if [[ "${conflict_count}" -gt 1 ]]; then
        _error "E400" "Conflicting flags: --help and --version are mutually exclusive" 0
        exit 2
    fi
    
    local lifecycle_count=0
    
    if [[ "${FLAG_UPDATE}" == true ]]; then
        lifecycle_count=$((lifecycle_count + 1))
    fi
    if [[ "${FLAG_UNINSTALL}" == true ]]; then
        lifecycle_count=$((lifecycle_count + 1))
    fi
    if [[ "${FLAG_UNINSTALL_AUTO_START}" == true ]]; then
        lifecycle_count=$((lifecycle_count + 1))
    fi
    
    if [[ "${lifecycle_count}" -gt 1 ]]; then
        _error "E400" "Conflicting lifecycle commands" 0
        exit 2
    fi
}

_dispatch_cli() {
    if [[ "${FLAG_HELP}" == true ]]; then
        _show_help
        exit 0
    fi
    
    if [[ "${FLAG_VERSION}" == true ]]; then
        _show_version
        exit 0
    fi
    
    if [[ "${FLAG_DEBUG}" == true ]]; then
        DEVILS_MINIOS_DEBUG_MODE=true
    fi
    
    if [[ "${FLAG_OFFLINE}" == true ]]; then
        DEVILS_MINIOS_OFFLINE_MODE=true
    fi
    
    if [[ "${FLAG_SAFE_MODE}" == true ]]; then
        DEVILS_MINIOS_SAFE_MODE=true
        _info "Safe mode enabled via CLI flag"
    fi
    
    if [[ "${FLAG_UPDATE}" == true ]]; then
        _warn "" "Update functionality not yet implemented (Phase 1 foundation only)"
        exit 0
    fi
    
    if [[ "${FLAG_UNINSTALL}" == true ]]; then
        _warn "" "Uninstall functionality not yet implemented (Phase 1 foundation only)"
        exit 0
    fi
    
    if [[ "${FLAG_UNINSTALL_AUTO_START}" == true ]]; then
        _warn "" "Auto-start removal not yet implemented (Phase 1 foundation only)"
        exit 0
    fi
    
    if [[ -n "${FLAG_RUN_MODULE}" ]]; then
        _info "Module dispatch requested: ${FLAG_RUN_MODULE}"
        _warn "" "Module dispatch not yet implemented (Phase 1 foundation only)"
        exit 0
    fi
    
    _info "Entering interactive mode (not yet implemented)"
    echo "Devil's Mini OS Launcher v${DEVILS_MINIOS_VERSION}"
    echo "Interactive menu not yet implemented (Phase 1 foundation only)"
    echo "Use --help for available options"
}

# ============================================================================
# MAIN
# ============================================================================

_main() {
    _parse_cli "$@"
    _validate_cli_precedence
    core_init
    _warn_play_store
    _dispatch_cli
}

_main "$@"