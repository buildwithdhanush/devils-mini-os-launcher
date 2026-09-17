#!/usr/bin/env bash
# Devil's Mini OS Launcher - Core Runtime Module
# Version: v1.0.0
# PRD Reference: §13.1, §23.1
# shellcheck disable=SC2034

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly DEVILS_MINIOS_VERSION="1.0.0"
readonly DEVILS_MINIOS_CONFIG_VERSION="1"
readonly DEVILS_MINIOS_STATE_VERSION="1"
readonly DEVILS_MINIOS_INSTALL_DIR="${PREFIX:-/data/data/com.termux/files/usr}/opt/devils-minios"
readonly DEVILS_MINIOS_TERMUX_SOURCES=("f-droid" "github" "play-store" "unknown")

# Project paths
readonly DEVILS_MINIOS_CONFIG_DIR="${HOME}/.config/devils-minios"
readonly DEVILS_MINIOS_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/devils-minios"

# Runtime directories (created on demand)
readonly DEVILS_MINIOS_LOG_DIR="${DEVILS_MINIOS_CONFIG_DIR}/logs"
readonly DEVILS_MINIOS_TMP_DIR="${DEVILS_MINIOS_CONFIG_DIR}/tmp"
readonly DEVILS_MINIOS_PID_DIR="${DEVILS_MINIOS_CONFIG_DIR}/pids"
readonly DEVILS_MINIOS_CRASH_DIR="${DEVILS_MINIOS_CONFIG_DIR}/crashes"

# Supported architectures
readonly DEVILS_MINIOS_SUPPORTED_ARCHS=("aarch64" "x86_64")

# Error code ranges (§48)
readonly DEVILS_MINIOS_ERR_CORE_START=100
readonly DEVILS_MINIOS_ERR_CORE_END=199
readonly DEVILS_MINIOS_ERR_LINUX_START=200
readonly DEVILS_MINIOS_ERR_LINUX_END=299
readonly DEVILS_MINIOS_ERR_APP_START=300
readonly DEVILS_MINIOS_ERR_APP_END=399
readonly DEVILS_MINIOS_ERR_SECURITY_START=400
readonly DEVILS_MINIOS_ERR_SECURITY_END=499
readonly DEVILS_MINIOS_ERR_NETWORK_START=500
readonly DEVILS_MINIOS_ERR_NETWORK_END=599
readonly DEVILS_MINIOS_ERR_UNKNOWN_START=900
readonly DEVILS_MINIOS_ERR_UNKNOWN_END=999

# Shell metacharacter denylist for structured execution (§23.1)
readonly DEVILS_MINIOS_SHELL_METACHARACTERS=';|&$`<>(){}[]!#~'

# ============================================================================
# RUNTIME STATE (in-memory only, never persisted)
# ============================================================================

declare -g DEVILS_MINIOS_PLATFORM=""
declare -g DEVILS_MINIOS_ARCH=""
declare -g DEVILS_MINIOS_TERMUX_SOURCE=""
declare -g DEVILS_MINIOS_TERMINAL_WIDTH=0
declare -g DEVILS_MINIOS_UI_MODE=""
declare -g DEVILS_MINIOS_LOG_LEVEL="INFO"
declare -g DEVILS_MINIOS_DEBUG_MODE=false
declare -g DEVILS_MINIOS_OFFLINE_MODE=false
declare -g DEVILS_MINIOS_SAFE_MODE=false

# ============================================================================
# LOGGING PRIMITIVES (§24)
# ============================================================================

_write_log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local log_file="${DEVILS_MINIOS_LOG_DIR}/launcher.log"
    
    [[ -d "${DEVILS_MINIOS_LOG_DIR}" ]] || return 0
    
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    if command -v flock &>/dev/null; then
        {
            flock -x 200
            printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${log_file}"
        } 200>"${log_file}.lock"
    else
        printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${log_file}"
    fi
}

# ============================================================================
# ERROR HANDLING (§48)
# ============================================================================

_error() {
    local code="${1:-E999}"
    local message="${2:-Unknown error}"
    local exit_status="${3:-0}"
    
    _write_log "ERROR" "[${code}] ${message}"
    printf 'ERROR [%s]: %s\n' "${code}" "${message}" >&2
    
    if [[ "${exit_status}" -gt 0 ]]; then
        exit "${exit_status}"
    fi
}

_warn() {
    local code="${1:-}"
    local message="${2:-Unknown warning}"
    
    if [[ -n "${code}" ]]; then
        _write_log "WARN" "[${code}] ${message}"
        printf 'WARNING [%s]: %s\n' "${code}" "${message}" >&2
    else
        _write_log "WARN" "${message}"
        printf 'WARNING: %s\n' "${message}" >&2
    fi
}

_info() {
    local message="${1:-}"
    if [[ "${DEVILS_MINIOS_DEBUG_MODE}" == true ]]; then
        _write_log "INFO" "${message}"
    fi
}

_debug() {
    local message="${1:-}"
    if [[ "${DEVILS_MINIOS_DEBUG_MODE}" == true ]]; then
        _write_log "DEBUG" "${message}"
    fi
}

# ============================================================================
# PLATFORM DETECTION (§8, §9, §10, §35)
# ============================================================================

_detect_platform() {
    DEVILS_MINIOS_PLATFORM="unknown"
    
    if [[ -n "${PREFIX:-}" ]] && [[ "${PREFIX}" == */com.termux/* ]]; then
        DEVILS_MINIOS_PLATFORM="termux"
        return 0
    fi
    
    if [[ -d "/data/data/com.termux" ]] || [[ -d "/data/data/com.termux.playstore" ]]; then
        DEVILS_MINIOS_PLATFORM="termux"
        return 0
    fi
    
    if [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]]; then
        if [[ -f "/system/build.prop" ]] || [[ -d "/system/app" ]]; then
            DEVILS_MINIOS_PLATFORM="android"
            return 0
        fi
    fi
    
    return 1
}

_detect_architecture() {
    local arch
    arch="$(uname -m 2>/dev/null || echo "unknown")"
    
    case "${arch}" in
        aarch64|arm64) DEVILS_MINIOS_ARCH="aarch64" ;;
        x86_64|amd64) DEVILS_MINIOS_ARCH="x86_64" ;;
        *)
            DEVILS_MINIOS_ARCH="${arch}"
            _error "E102" "Unsupported architecture: ${arch}. Supported: aarch64, x86_64" 1
            ;;
    esac
    
    local supported=false
    for supported_arch in "${DEVILS_MINIOS_SUPPORTED_ARCHS[@]}"; do
        if [[ "${DEVILS_MINIOS_ARCH}" == "${supported_arch}" ]]; then
            supported=true
            break
        fi
    done
    
    if [[ "${supported}" != true ]]; then
        _error "E102" "Architecture ${DEVILS_MINIOS_ARCH} not supported" 1
    fi
    
    _debug "Detected architecture: ${DEVILS_MINIOS_ARCH}"
    return 0
}

_detect_termux_source() {
    DEVILS_MINIOS_TERMUX_SOURCE="unknown"
    
    if [[ -n "${TERMUX_APK_RELEASE:-}" ]]; then
        case "${TERMUX_APK_RELEASE}" in
            github) DEVILS_MINIOS_TERMUX_SOURCE="github" ;;
            f-droid) DEVILS_MINIOS_TERMUX_SOURCE="f-droid" ;;
            playstore|play-store) DEVILS_MINIOS_TERMUX_SOURCE="play-store" ;;
            *) DEVILS_MINIOS_TERMUX_SOURCE="unknown" ;;
        esac
        _debug "Termux source from env: ${DEVILS_MINIOS_TERMUX_SOURCE}"
        return 0
    fi
    
    local prefix="${PREFIX:-}"
    if [[ "${prefix}" == *"/com.termux.playstore/"* ]]; then
        DEVILS_MINIOS_TERMUX_SOURCE="play-store"
    elif [[ "${prefix}" == *"/com.termux/"* ]]; then
        DEVILS_MINIOS_TERMUX_SOURCE="f-droid"
        _warn "" "Termux source ambiguous; assuming F-Droid. If issues occur, reinstall from F-Droid or GitHub."
    else
        DEVILS_MINIOS_TERMUX_SOURCE="unknown"
    fi
    
    _debug "Termux source inferred: ${DEVILS_MINIOS_TERMUX_SOURCE}"
    return 0
}

_warn_play_store() {
    if [[ "${DEVILS_MINIOS_TERMUX_SOURCE}" == "play-store" ]] || \
       [[ "${DEVILS_MINIOS_TERMUX_SOURCE}" == "unknown" && "${PREFIX:-}" == *"/com.termux.playstore/"* ]]; then
        printf '\n'
        printf '╔════════════════════════════════════════════════════════════════╗\n' >&2
        printf '║  WARNING: Play Store Termux Detected                          ║\n' >&2
        printf '║                                                                ║\n' >&2
        printf '║  Play Store builds of Termux are outdated and unsupported.     ║\n' >&2
        printf '║  Please install Termux from F-Droid or GitHub for full         ║\n' >&2
        printf '║  compatibility with Devil'\''s Mini OS Launcher.                  ║\n' >&2
        printf '║                                                                ║\n' >&2
        printf '║  F-Droid: https://f-droid.org/packages/com.termux/            ║\n' >&2
        printf '║  GitHub:  https://github.com/termux/termux-app/releases       ║\n' >&2
        printf '╚════════════════════════════════════════════════════════════════╝\n' >&2
        printf '\n'
    fi
}

# ============================================================================
# TERMINAL WIDTH DETECTION (§19.2)
# ============================================================================

_detect_terminal_width() {
    local width=80
    
    if [[ -n "${COLUMNS:-}" ]] && [[ "${COLUMNS}" =~ ^[0-9]+$ ]]; then
        width="${COLUMNS}"
    elif command -v tput &>/dev/null; then
        width="$(tput cols 2>/dev/null || echo 80)"
    fi
    
    if ! [[ "${width}" =~ ^[0-9]+$ ]] || [[ "${width}" -lt 1 ]]; then
        width=80
    fi
    
    DEVILS_MINIOS_TERMINAL_WIDTH="${width}"
    
    if [[ "${width}" -ge 60 ]]; then
        DEVILS_MINIOS_UI_MODE="full"
    elif [[ "${width}" -ge 40 ]]; then
        DEVILS_MINIOS_UI_MODE="compact"
    else
        DEVILS_MINIOS_UI_MODE="minimal"
    fi
    
    _debug "Terminal width: ${width}, UI mode: ${DEVILS_MINIOS_UI_MODE}"
    return 0
}

# ============================================================================
# INPUT VALIDATION (§22, §23)
# ============================================================================

_validate_no_metacharacters() {
    local input="${1:-}"
    if [[ "${input}" =~ [${DEVILS_MINIOS_SHELL_METACHARACTERS}] ]]; then
        return 1
    fi
    return 0
}

_validate_path() {
    local path="${1:-}"
    local base_dir="${2:-}"
    
    if [[ -z "${path}" ]]; then return 1; fi
    if [[ "${path}" == *".."* ]]; then return 1; fi
    
    if [[ -n "${base_dir}" ]]; then
        local resolved_path resolved_base
        
        if [[ ! -e "${path}" ]]; then
            local parent
            parent="$(dirname "${path}")"
            if [[ -d "${parent}" ]]; then
                resolved_path="$(cd "${parent}" && pwd)/$(basename "${path}")"
            else
                resolved_path="${path}"
            fi
        else
            resolved_path="$(cd "${path}" && pwd 2>/dev/null || realpath "${path}" 2>/dev/null || echo "${path}")"
        fi
        
        if [[ -d "${base_dir}" ]]; then
            resolved_base="$(cd "${base_dir}" && pwd)"
        else
            resolved_base="${base_dir}"
        fi
        
        if [[ "${resolved_path}" != "${resolved_base}"* ]]; then
            return 1
        fi
    fi
    
    return 0
}

_sanitize_input() {
    local input="${1:-}"
    local max_length="${2:-1024}"
    
    local sanitized
    sanitized="$(printf '%s' "${input}" | tr -d '\000-\010\013-\037\177')"
    
    if [[ "${#sanitized}" -gt "${max_length}" ]]; then
        sanitized="${sanitized:0:${max_length}}"
    fi
    
    printf '%s' "${sanitized}"
}

# ============================================================================
# STRUCTURED EXECUTION (§23.1)
# ============================================================================

execute_structured() {
    local executor="${1:-}"
    local action="${2:-}"
    shift 2 || true
    
    local -a args=("$@")
    
    local -a allowed_executors=("proot-distro" "pkg" "git" "tar" "sha256sum" "curl" "mkdir" "cp" "mv" "rm" "cat" "ls" "find" "grep" "sed" "awk" "chmod" "chown" "touch" "date" "uname" "df" "du" "stat" "test" "echo" "printf" "true" "false")
    
    local executor_allowed=false
    for allowed in "${allowed_executors[@]}"; do
        if [[ "${executor}" == "${allowed}" ]]; then
            executor_allowed=true
            break
        fi
    done
    
    if [[ "${executor_allowed}" != true ]]; then
        _error "E401" "Executor not allowlisted: ${executor}" 0
        return 1
    fi
    
    if ! _validate_no_metacharacters "${action}"; then
        _error "E401" "Action contains shell metacharacters: ${action}" 0
        return 1
    fi
    
    local i
    for i in "${!args[@]}"; do
        if ! _validate_no_metacharacters "${args[$i]}"; then
            _error "E401" "Argument ${i} contains shell metacharacters: ${args[$i]}" 0
            return 1
        fi
    done
    
    local -a cmd=("${executor}")
    if [[ -n "${action}" ]]; then
        cmd+=("${action}")
    fi
    cmd+=("${args[@]}")
    
    _debug "Executing: ${cmd[*]}"
    
    "${cmd[@]}"
    local exit_status=$?
    
    _debug "Exit status: ${exit_status}"
    return "${exit_status}"
}

# ============================================================================
# CORE INITIALIZATION
# ============================================================================

core_init() {
    _debug "Initializing core runtime..."
    
    if ! _detect_platform; then
        _error "E100" "Failed to detect platform" 1
    fi
    _debug "Platform: ${DEVILS_MINIOS_PLATFORM}"
    
    if ! _detect_architecture; then
        _error "E102" "Failed to detect architecture" 1
    fi
    
    _detect_termux_source
    _detect_terminal_width
    
    local dir
    for dir in "${DEVILS_MINIOS_CONFIG_DIR}" "${DEVILS_MINIOS_CACHE_DIR}" "${DEVILS_MINIOS_LOG_DIR}" \
               "${DEVILS_MINIOS_TMP_DIR}" "${DEVILS_MINIOS_PID_DIR}" "${DEVILS_MINIOS_CRASH_DIR}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}" 2>/dev/null || true
        fi
    done
    
    if [[ -d "${DEVILS_MINIOS_CONFIG_DIR}" ]]; then
        chmod 700 "${DEVILS_MINIOS_CONFIG_DIR}" 2>/dev/null || true
    fi
    
    _debug "Core initialization complete"
    return 0
}

# ============================================================================
# EXPORTS
# ============================================================================

export -f _write_log _error _warn _info _debug
export -f _detect_platform _detect_architecture _detect_termux_source _warn_play_store
export -f _detect_terminal_width
export -f _validate_no_metacharacters _validate_path _sanitize_input
export -f execute_structured
export -f core_init

export DEVILS_MINIOS_VERSION
export DEVILS_MINIOS_PLATFORM DEVILS_MINIOS_ARCH DEVILS_MINIOS_TERMUX_SOURCE
export DEVILS_MINIOS_TERMINAL_WIDTH DEVILS_MINIOS_UI_MODE
export DEVILS_MINIOS_DEBUG_MODE DEVILS_MINIOS_OFFLINE_MODE DEVILS_MINIOS_SAFE_MODE

# ============================================================================
# SCRIPT EXECUTION GUARD
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: core.sh is a module and should not be executed directly" >&2
    exit 1
fi