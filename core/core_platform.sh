#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_platform.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# PRD Reference: §9, §10, §19, §35

# ============================================================================
# PLATFORM, SOURCE, WIDTH (§9, §10, §19, §35)
# ============================================================================

_termux_app_directory_present() {
    [[ -d "/data/data/com.termux" || -d "/data/data/com.termux.playstore" ]]
}

_detect_platform() {
    DEVILS_MINIOS_PLATFORM="unknown"
    if [[ -n "${PREFIX:-}" && "${PREFIX}" == */com.termux/* ]]; then
        DEVILS_MINIOS_PLATFORM="termux"
    elif _termux_app_directory_present; then
        DEVILS_MINIOS_PLATFORM="termux"
    elif [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]]; then
        DEVILS_MINIOS_PLATFORM="linux"
    fi
    _debug "Platform: ${DEVILS_MINIOS_PLATFORM}"
}

_detect_architecture() {
    local machine
    machine="$(uname -m 2>/dev/null || printf 'unknown')"
    case "${machine}" in
        aarch64|arm64) DEVILS_MINIOS_ARCH="aarch64" ;;
        x86_64|amd64) DEVILS_MINIOS_ARCH="x86_64" ;;
        *) DEVILS_MINIOS_ARCH="${machine}" ;;
    esac
    _debug "Architecture: ${DEVILS_MINIOS_ARCH}"
}

_detect_android_version() {
    DEVILS_MINIOS_ANDROID_VERSION="unknown"
    DEVILS_MINIOS_ANDROID_API="unknown"
    if _has_command getprop; then
        DEVILS_MINIOS_ANDROID_VERSION="$(getprop ro.build.version.release 2>/dev/null || printf 'unknown')"
        DEVILS_MINIOS_ANDROID_API="$(getprop ro.build.version.sdk 2>/dev/null || printf 'unknown')"
    fi
    if [[ ! "${DEVILS_MINIOS_ANDROID_API}" =~ ^[0-9]+$ ]]; then
        # DEVILS_MINIOS_ANDROID_VERSION is exported by modules/core.sh and
        # consumed by core/core_config.sh; this reset is the last write to
        # it in this file with no subsequent read visible to ShellCheck's
        # per-file analysis, hence SC2034 (the earlier writes above are not
        # flagged since this one shadows them).
        # shellcheck disable=SC2034
        DEVILS_MINIOS_ANDROID_VERSION="unknown"
        DEVILS_MINIOS_ANDROID_API="unknown"
    fi
}

# Contract: detect_platform(none); returns: 0 on success, non-zero on unsupported/invalid input; side effects: updates runtime facts/UI mode.
detect_platform() {
    _detect_platform
    _detect_architecture
    _detect_android_version
    if [[ "${DEVILS_MINIOS_PLATFORM}" != "termux" ]]; then
        _warn "E900" "Supported host is Termux on Android; detected '${DEVILS_MINIOS_PLATFORM}'. Launching in diagnostics-only mode."
        # DEVILS_MINIOS_SAFE_MODE is declared -g in modules/core.sh and
        # exported there, but exported vars are only visible to ShellCheck
        # as "used" from the declaring file itself; this file's own scope
        # has no read of it, hence SC2034.
        # shellcheck disable=SC2034
        DEVILS_MINIOS_SAFE_MODE=true
    fi
    if ! _is_valid_key "${DEVILS_MINIOS_ARCH}" "${DEVILS_MINIOS_SUPPORTED_ARCHS[@]}"; then
        _error "E900" "Unsupported architecture '${DEVILS_MINIOS_ARCH}'. Supported: aarch64, x86_64" 5
    fi
    if [[ "${DEVILS_MINIOS_ANDROID_API}" =~ ^[0-9]+$ && "${DEVILS_MINIOS_ANDROID_API}" -lt 29 ]]; then
        _error "E900" "Android API ${DEVILS_MINIOS_ANDROID_API} is below the supported API 29 floor" 5
    fi
}

_detect_termux_source() {
    DEVILS_MINIOS_TERMUX_SOURCE="unknown"
    if [[ -n "${TERMUX_APK_RELEASE:-}" ]]; then
        case "${TERMUX_APK_RELEASE}" in
            github) DEVILS_MINIOS_TERMUX_SOURCE="github" ;;
            f-droid) DEVILS_MINIOS_TERMUX_SOURCE="f-droid" ;;
            playstore|play-store) DEVILS_MINIOS_TERMUX_SOURCE="play-store" ;;
        esac
    elif [[ "${PREFIX:-}" == *"/com.termux.playstore/"* ]]; then
        DEVILS_MINIOS_TERMUX_SOURCE="play-store"
    elif [[ "${PREFIX:-}" == *"/com.termux/"* ]]; then
        DEVILS_MINIOS_TERMUX_SOURCE="f-droid"
    fi
}

# Contract: detect_termux_source(none); returns: 0 on success, non-zero on unsupported/invalid input; side effects: updates runtime facts/UI mode.
detect_termux_source() {
    _detect_termux_source
    _debug "Termux source: ${DEVILS_MINIOS_TERMUX_SOURCE}"
}

# Contract: warn_play_store(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
warn_play_store() {
    if [[ "${DEVILS_MINIOS_TERMUX_SOURCE}" == "play-store" || "${DEVILS_MINIOS_TERMUX_SOURCE}" == "unknown" ]]; then
        printf '\n'
        printf 'WARNING: Play Store or unknown Termux source detected.\n' >&2
        printf 'Play Store Termux builds are outdated and unsupported. Install Termux from F-Droid or GitHub.\n' >&2
        printf 'Continuing without blocking; compatibility issues may occur.\n' >&2
        printf '\n'
    fi
}

# Contract: warn_proot_limits(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
warn_proot_limits() {
    cat <<'EOF'
Proot compatibility notice:
- Proot is a userspace compatibility layer, not kernel virtualization.
- systemd services, kernel modules, FUSE, low-level networking, and some device access are unavailable.
- GUI desktops depend on Termux X11 or VNC and may have input/performance limits.
- Operations requiring root are rejected by design.
EOF
}

# Contract: detect_terminal_width(none); returns: 0 on success, non-zero on unsupported/invalid input; side effects: updates runtime facts/UI mode.
detect_terminal_width() {
    local width="${COLUMNS:-}"
    if [[ ! "${width}" =~ ^[0-9]+$ ]] && _has_command tput; then
        width="$(tput cols 2>/dev/null || printf '80')"
    fi
    [[ "${width}" =~ ^[0-9]+$ && "${width}" -ge 1 ]] || width=80
    # DEVILS_MINIOS_TERMINAL_WIDTH is exported by modules/core.sh; this
    # file's own scope has no read of it, hence SC2034.
    # shellcheck disable=SC2034
    DEVILS_MINIOS_TERMINAL_WIDTH="${width}"
    if [[ "${width}" -ge 60 ]]; then
        DEVILS_MINIOS_UI_MODE="full"
    elif [[ "${width}" -ge 40 ]]; then
        DEVILS_MINIOS_UI_MODE="compact"
    else
        # DEVILS_MINIOS_UI_MODE is exported by modules/core.sh and consumed
        # by core/core_ui.sh; this is the last write to it in this file with
        # no subsequent read visible to ShellCheck's per-file analysis,
        # hence SC2034 (the earlier branches above are not flagged since
        # only one branch executes and this one is the final candidate).
        # shellcheck disable=SC2034
        DEVILS_MINIOS_UI_MODE="minimal"
    fi
}

# Contract: build_runtime_context(none); returns: 0 on success, non-zero on unsupported/invalid input; side effects: updates runtime facts/UI mode.
build_runtime_context() {
    detect_terminal_width
    # terminal_width is deliberately not present here as a persisted value; it
    # exists only as DEVILS_MINIOS_TERMINAL_WIDTH for this process.
}

