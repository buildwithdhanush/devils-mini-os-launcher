#!/usr/bin/env bash
# Devil's Mini OS Launcher - Core Runtime Module
# Version: v1.0.0
# PRD Reference: §13.1, §17, §18, §23, §24, §26, §39

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly DEVILS_MINIOS_VERSION="1.0.0"
# The following two are consumed by core/core_config.sh and core/core_state.sh
# respectively (config_version/state_version validation + persistence), both
# loaded dynamically by _load_core_split_files() below via a runtime-built
# path; ShellCheck cannot follow a dynamic `source "${path}"` even with -x,
# so it sees no reader of these two constants from core.sh's own file.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_CONFIG_VERSION="1"
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_STATE_VERSION="1"
# Consumed by devils-minios.sh (update-check, GitHub install source) and by
# test/test_update_all.sh, not within core.sh itself; ShellCheck's per-file
# view of core.sh alone cannot see those cross-file reads.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL="https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher"

if [[ -z "${DEVILS_MINIOS_INSTALL_DIR:-}" ]]; then
    readonly DEVILS_MINIOS_INSTALL_DIR="${PREFIX:-/data/data/com.termux/files/usr}/opt/devils-minios"
else
    readonly DEVILS_MINIOS_INSTALL_DIR
fi

readonly DEVILS_MINIOS_CONFIG_DIR="${HOME}/.config/devils-minios"
readonly DEVILS_MINIOS_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/devils-minios"
readonly DEVILS_MINIOS_LOG_DIR="${DEVILS_MINIOS_CONFIG_DIR}/logs"
readonly DEVILS_MINIOS_TMP_DIR="${DEVILS_MINIOS_CONFIG_DIR}/tmp"
readonly DEVILS_MINIOS_PID_DIR="${DEVILS_MINIOS_CONFIG_DIR}/pids"
readonly DEVILS_MINIOS_CRASH_DIR="${DEVILS_MINIOS_CONFIG_DIR}/crashes"
readonly DEVILS_MINIOS_WORKSPACE_ROOT="${HOME}/devils-minios/workspaces"

# DEVILS_MINIOS_CONFIG_FILE is read by core/core_config.sh (dynamically
# sourced) and directly by several test/*.sh files.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_CONFIG_FILE="${DEVILS_MINIOS_CONFIG_DIR}/config"
# DEVILS_MINIOS_CONFIG_BACKUP is read/written by core/core_config.sh
# (dynamically sourced), same dynamic-source blind spot as CONFIG_FILE above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_CONFIG_BACKUP="${DEVILS_MINIOS_CONFIG_DIR}/config.bak"
# DEVILS_MINIOS_STATE_FILE/STATE_BACKUP are read by core/core_state.sh
# (dynamically sourced, same reason as CONFIG_VERSION/STATE_VERSION above);
# CONFIG_FILE is additionally read directly by test/test_settings.sh.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_STATE_FILE="${DEVILS_MINIOS_CONFIG_DIR}/state"
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_STATE_BACKUP="${DEVILS_MINIOS_CONFIG_DIR}/state.bak"
# DEVILS_MINIOS_ONBOARDING_MARKER is read/written by devils-minios.sh and by
# core/core_state.sh (dynamically sourced); DEVILS_MINIOS_CRASH_FLAG likewise
# by core/core_state.sh. Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_ONBOARDING_MARKER="${DEVILS_MINIOS_CONFIG_DIR}/.onboarding-complete"
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_CRASH_FLAG="${DEVILS_MINIOS_CONFIG_DIR}/.crash-flag"

# DEVILS_MINIOS_SUPPORTED_ARCHS is read by core/core_platform.sh and
# core/core_catalog.sh (both dynamically sourced). Same blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_SUPPORTED_ARCHS=("aarch64" "x86_64")
# Canonical enum of the Termux install sources _detect_termux_source() can
# report (§17.2 persisted_runtime_facts). Not consulted at runtime: the
# detector's own if/elif chain can only ever produce one of these exact
# literals by construction, so a validation call against this array would
# always pass — it exists as the single documented source of truth for the
# value set, matching the declaration pattern of the ALLOWED_*/SUPPORTED_*
# arrays around it.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_TERMUX_SOURCES=("f-droid" "github" "play-store" "unknown")
# DEVILS_MINIOS_ALLOWED_THEMES/BANNERS are read by core/core_config.sh and
# core/core_ui.sh (both dynamically sourced); DEVILS_MINIOS_ALLOWED_DESKTOPS
# by core/core_catalog.sh. Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_ALLOWED_THEMES=("dracula" "nord" "solarized" "gruvbox")
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_ALLOWED_BANNERS=("devil" "minimal" "retro" "cyber" "simple")
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_ALLOWED_DESKTOPS=("xfce4" "lxqt" "lxde" "mate" "i3wm" "openbox" "fluxbox" "jwm")

# DEVILS_MINIOS_PERSISTED_CONFIG_KEYS/RUNTIME_FACTS are read by
# core/core_config.sh and modules/settings.sh; DEVILS_MINIOS_STATE_KEYS by
# core/core_state.sh. Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_PERSISTED_CONFIG_KEYS=(
    "config_version" "theme" "banner" "banner_animation" "auto_launch"
    "health_check_interval" "log_level" "check_updates" "language"
    "network_timeout" "network_retries"
)
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS=(
    "termux_source" "android_version" "architecture"
)
# DEVILS_MINIOS_RUNTIME_CONTEXT_KEYS is read by core/core_config.sh
# (dynamically sourced). Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_RUNTIME_CONTEXT_KEYS=("terminal_width")
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_STATE_KEYS=(
    "state_version" "primary_distro" "last_successful_workflow" "onboarding_completion" "crash_loop_state"
)

# DEVILS_MINIOS_LOG_MAX_BYTES/ROTATIONS/RETENTION_DAYS are read by
# core/core_logging.sh (and test/test_core.sh); SAFETY_MARGIN_BYTES by
# core/core_state.sh. Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_LOG_MAX_BYTES=1048576
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_LOG_ROTATIONS=4
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_LOG_RETENTION_DAYS=30
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_SAFETY_MARGIN_BYTES=104857600
# Each consumed only by other modules (linux_env.sh, proot_apps.sh,
# termux_apps.sh, update_all.sh, devils-minios.sh), never within core.sh
# itself; ShellCheck's per-file view of core.sh alone cannot see those reads.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_DEFAULT_DISTRO_REQUIRED_BYTES=1073741824
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_DEFAULT_DESKTOP_REQUIRED_BYTES=314572800
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES=104857600
# DEVILS_MINIOS_PROOT_ROOTFS_DIR is read by modules/linux_env.sh,
# modules/update_all.sh and core/core_catalog.sh (dynamically sourced), never
# within core.sh itself. Same dynamic-source blind spot as above.
# shellcheck disable=SC2034
readonly DEVILS_MINIOS_PROOT_ROOTFS_DIR="${HOME}/.local/share/proot-distro/installed"

# Exact denylist from PRD §23.1. Primary defense is argv-array execution;
# this catches construction bugs before fixed executors are invoked.
# Single-quoted deliberately: this string must hold the literal characters
# `$` and `` ` `` themselves, not have them expanded/executed at declaration
# time — double-quoting would attempt command substitution/variable
# expansion on this literal pattern, the exact bug class this denylist
# exists to catch elsewhere. Consumed only by core/core_security.sh
# (dynamically sourced), never within core.sh itself, hence SC2034 as well.
# shellcheck disable=SC2016,SC2034
readonly DEVILS_MINIOS_SHELL_DENYLIST_PATTERN='[;&|$\`<>()]'

# ============================================================================
# RUNTIME STATE (in-memory only unless explicitly saved by contract)
# ============================================================================

declare -g DEVILS_MINIOS_PLATFORM="unknown"
declare -g DEVILS_MINIOS_ARCH="unknown"
declare -g DEVILS_MINIOS_ANDROID_VERSION="unknown"
declare -g DEVILS_MINIOS_ANDROID_API="unknown"
declare -g DEVILS_MINIOS_TERMUX_SOURCE="unknown"
declare -g DEVILS_MINIOS_TERMINAL_WIDTH=80
declare -g DEVILS_MINIOS_UI_MODE="full"
# DEVILS_MINIOS_LOG_LEVEL is read/written by core/core_config.sh,
# core/core_logging.sh and modules/settings.sh (dynamically sourced), and by
# devils-minios.sh; unlike PLATFORM/ARCH/etc. above it is not in the
# `export` list below, so ShellCheck's per-file view of core.sh has no
# visible reader.
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_LOG_LEVEL="INFO"
declare -g DEVILS_MINIOS_DEBUG_MODE=false
declare -g DEVILS_MINIOS_OFFLINE_MODE=false
declare -g DEVILS_MINIOS_NO_CHECKS=false
declare -g DEVILS_MINIOS_SAFE_MODE=false
# DEVILS_MINIOS_BATTERY_WARNED/CURRENT_STATE/LAST_STATE are read/written by
# core/core_state.sh and devils-minios.sh (dynamically sourced); not part of
# the `export` list below, so core.sh's own scope has no visible reader.
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_BATTERY_WARNED=false
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_CURRENT_STATE="UNINSTALLED"
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_LAST_STATE=""
# Session-only crash marker: true once this process records a new serious crash.
# It is intentionally never persisted; §26.5 stage 5 may clear the on-disk
# crash flag only when the current session reached IDLE without a new crash.
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_SESSION_CRASH_RECORDED=false

# DEVILS_MINIOS_CONFIG/STATE are read/written across core/core_config.sh,
# core/core_state.sh and several modules/*.sh (all dynamically sourced).
# Associative arrays cannot be exported in bash, so unlike the scalars above
# they can never appear in the `export` list; same dynamic-source blind spot.
# shellcheck disable=SC2034
declare -gA DEVILS_MINIOS_CONFIG=()
# shellcheck disable=SC2034
declare -gA DEVILS_MINIOS_STATE=()
# DEVILS_MINIOS_CATALOG_TOTAL/MALFORMED are read/written entirely within
# core/core_catalog.sh (dynamically sourced), never referenced in core.sh
# itself.
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_CATALOG_TOTAL=0
# shellcheck disable=SC2034
declare -g DEVILS_MINIOS_CATALOG_MALFORMED=0
# DEVILS_MINIOS_CATALOG/RECORD_FIELDS are populated by core/core_catalog.sh
# and consumed by modules/proot_apps.sh, linux_env.sh, termux_apps.sh and
# update_all.sh (all dynamically sourced). Indexed arrays cannot be exported
# either, so the same blind spot applies.
# shellcheck disable=SC2034
declare -g -a DEVILS_MINIOS_CATALOG=()
# shellcheck disable=SC2034
declare -g -a DEVILS_MINIOS_RECORD_FIELDS=()

# ============================================================================
# PATH ACCESSORS (§13.1 required-functions list)
# ============================================================================

# Contract: get_config_dir(none); returns: value/path or non-zero on invalid input; side effects: none.
get_config_dir() { printf '%s' "${DEVILS_MINIOS_CONFIG_DIR}"; }
get_cache_dir()  { printf '%s' "${DEVILS_MINIOS_CACHE_DIR}"; }
get_bin_dir()    { printf '%s' "${DEVILS_MINIOS_INSTALL_DIR}/bin"; }
get_tmp_dir()    { printf '%s' "${DEVILS_MINIOS_TMP_DIR}"; }
get_etc_dir()    { printf '%s' "${DEVILS_MINIOS_INSTALL_DIR}/data"; }
get_log_file()   { printf '%s' "${DEVILS_MINIOS_LOG_DIR}/launcher.log"; }

# ============================================================================
# BASIC INTERNAL HELPERS
# ============================================================================

_is_valid_key() {
    local key="$1"
    shift
    local candidate
    for candidate in "$@"; do
        [[ "${key}" == "${candidate}" ]] && return 0
    done
    return 1
}

_trim() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "${value}"
}

_confirm() {
    local prompt="${1:-Continue?}"
    local answer
    printf '%s [y/N]: ' "${prompt}"
    if ! IFS= read -r answer; then
        return 4
    fi
    case "${answer}" in
        y|Y|yes|YES) return 0 ;;
        *) return 4 ;;
    esac
}

_prompt_default() {
    local prompt="${1:-Value}"
    local default="${2:-}"
    local answer
    if [[ -n "${default}" ]]; then
        printf '%s [%s]: ' "${prompt}" "${default}" >&2
    else
        printf '%s: ' "${prompt}" >&2
    fi
    if ! IFS= read -r answer; then
        printf '%s' "${default}"
        return 4
    fi
    if [[ -z "${answer}" ]]; then
        printf '%s' "${default}"
        return 0
    fi
    printf '%s' "${answer}"
    return 0
}

_is_int() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

_is_bool() {
    [[ "${1:-}" == "true" || "${1:-}" == "false" ]]
}

_has_command() {
    command -v "$1" >/dev/null 2>&1
}


# ============================================================================
# INTERNAL CORE SPLIT MODULES
# ============================================================================
# core.sh exceeded the PRD's 500-line-per-file limit, so its body was split
# into core/core_*.sh files along its own existing section boundaries
# (each section's own PRD § references are preserved in that file's header).
# These are internal continuations of core.sh, sourced immediately below in
# their original top-to-bottom order (logging/error handling, platform
# facts, validation + execute_structured(), configuration, persistent
# state/state machine/resource gates/signal handling, data catalog +
# command contracts, UI primitives + theme/module helpers) so that
# initialization order and function/variable availability are identical to
# the pre-split single file. They are NOT feature modules: they are not
# listed in DEVILS_MINIOS_FEATURE_MODULES and are not reachable via
# --run-module/dispatch_module.
readonly -a _DEVILS_MINIOS_CORE_SPLIT_FILES=(
    core_logging core_platform core_security core_executor core_config core_state
    core_recovery core_backup core_catalog core_ui
)

_load_core_split_files() {
    local part path
    for part in "${_DEVILS_MINIOS_CORE_SPLIT_FILES[@]}"; do
        path="${DEVILS_MINIOS_INSTALL_DIR}/core/${part}.sh"
        if [[ ! -f "${path}" ]]; then
            printf '%s\n' "ERROR: Required core component missing: ${part}.sh" >&2
            exit 1
        fi
        # shellcheck disable=SC1090
        source "${path}"
    done
}
_load_core_split_files

# ============================================================================
# CORE INITIALIZATION
# ============================================================================

# Loads exactly the 14 module files (§12, §14 step 4). core.sh is already
# sourced by the entry point; this loads the 13 feature modules.
readonly -a DEVILS_MINIOS_FEATURE_MODULES=(
    linux_env file_mgr termux_apps proot_apps android_tools workspace
    health_check log_viewer customize system_tools system_info update_all settings
)

# §26.1 MOD-INIT-FAIL: a module whose file is missing or whose load/init
# returns non-zero is disabled for the current session; the remaining modules
# keep loading, and Safe Mode is NOT forced solely on its account.
declare -ga DEVILS_MINIOS_DISABLED_MODULES=()

_module_is_disabled() {
    local m
    for m in "${DEVILS_MINIOS_DISABLED_MODULES[@]}"; do
        [[ "${m}" == "$1" ]] && return 0
    done
    return 1
}

_load_modules() {
    local mod path
    for mod in "${DEVILS_MINIOS_FEATURE_MODULES[@]}"; do
        path="${DEVILS_MINIOS_INSTALL_DIR}/modules/${mod}.sh"
        if [[ ! -f "${path}" ]]; then
            DEVILS_MINIOS_DISABLED_MODULES+=("${mod}")
            _warn "E900" "Required module missing: ${mod}.sh; disabled for this session" || true
            continue
        fi
        # shellcheck disable=SC1090
        if ! source "${path}"; then
            DEVILS_MINIOS_DISABLED_MODULES+=("${mod}")
            _warn "E900" "Module failed to load: ${mod}.sh; disabled for this session" || true
        fi
    done
}

# Contract: core_init(none); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
core_init() {
    # shellcheck disable=SC2034  # session-wide flag; read in core/core_state.sh
    DEVILS_MINIOS_SESSION_CRASH_RECORDED=false
    DEVILS_MINIOS_STATE_RECOVERY_REINITIALIZED=false

    # §14 steps 5–8: detect platform/source once, then load/validate persistent
    # state and configuration before constructing the process-local runtime
    # context. Nothing in this phase depends on session CLI modifiers.
    detect_platform
    detect_termux_source

    local dir
    for dir in \
        "${DEVILS_MINIOS_CONFIG_DIR}" \
        "${DEVILS_MINIOS_CACHE_DIR}" \
        "${DEVILS_MINIOS_LOG_DIR}" \
        "${DEVILS_MINIOS_TMP_DIR}" \
        "${DEVILS_MINIOS_PID_DIR}" \
        "${DEVILS_MINIOS_CRASH_DIR}" \
        "${DEVILS_MINIOS_WORKSPACE_ROOT}"; do
        mkdir -p "${dir}"
    done
    chmod 700 "${DEVILS_MINIOS_CONFIG_DIR}" 2>/dev/null || true

    load_state || {
        trigger_safe_mode "persistent state recovery failed"
    }
    if [[ "${DEVILS_MINIOS_STATE_RECOVERY_REINITIALIZED:-false}" == true ]]; then
        DEVILS_MINIOS_CURRENT_STATE="FIRST_BOOT"
    fi
    if ! load_config; then
        # §48.2 E412 / §26.1 CFG-TAMPER: load_config() returns non-zero
        # only for the manifest-tamper signal (never for CFG-MISSING/
        # CFG-BAD-VALUE, which it self-heals and returns 0 for). Per §26.1
        # this is never auto-recovered - route directly to Safe Mode.
        trigger_safe_mode "configuration/installation tamper detected (E412)"
    fi

    # Runtime context is deliberately process-local and is built only after
    # persistent facts have been loaded/validated (§17.4).
    build_runtime_context
    if ! [[ "${DEVILS_MINIOS_TERMINAL_WIDTH:-}" =~ ^[0-9]+$ ]] ||
       [[ "${DEVILS_MINIOS_TERMINAL_WIDTH}" -lt 1 ]] ||
       [[ ! "${DEVILS_MINIOS_UI_MODE:-}" =~ ^(minimal|compact|full)$ ]]; then
        recover_runtime_temp_corrupt "runtime_context" || {
            trigger_safe_mode "RUNTIME-TEMP-CORRUPT: runtime context rebuild failed"
        }
    fi

    rotate_and_purge_logs
    _load_modules
    write_log_file "INFO" "Core runtime initialized (platform=${DEVILS_MINIOS_PLATFORM}, arch=${DEVILS_MINIOS_ARCH}, width=${DEVILS_MINIOS_TERMINAL_WIDTH})"
}

# ============================================================================
# EXPORTS
# ============================================================================

export DEVILS_MINIOS_VERSION
export DEVILS_MINIOS_PLATFORM DEVILS_MINIOS_ARCH DEVILS_MINIOS_ANDROID_VERSION DEVILS_MINIOS_ANDROID_API
export DEVILS_MINIOS_TERMUX_SOURCE DEVILS_MINIOS_TERMINAL_WIDTH DEVILS_MINIOS_UI_MODE
export DEVILS_MINIOS_DEBUG_MODE DEVILS_MINIOS_OFFLINE_MODE DEVILS_MINIOS_SAFE_MODE DEVILS_MINIOS_NO_CHECKS

# ============================================================================
# SOURCE GUARD
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf '%s\n' "ERROR: core.sh is a module and must be sourced by devils-minios.sh" >&2
    exit 1
fi
