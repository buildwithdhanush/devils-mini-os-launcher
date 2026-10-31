#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/system_info.sh
# PRD Reference: §13.12
# Public: system_info_menu()
# On-demand, read-only diagnostics: platform, Android version, architecture,
# Bash version, terminal width, storage information, environment information.
# No background daemon; no mutation of config/state.

_system_info_storage_line() {
    df -h "${HOME}" 2>/dev/null | awk 'NR==2 {print $4" free of "$2" ("$5" used)"}' || printf 'unavailable'
}

_system_info_battery_line() {
    if _has_command termux-battery-status; then
        local pct
        pct="$(_get_battery_percent 2>/dev/null || true)"
        if [[ -n "${pct}" ]]; then
            printf '%s%%' "${pct}"
        else
            printf 'unavailable'
        fi
    else
        printf 'Unavailable (Termux:API not installed)'
    fi
}

_system_info_proot_line() {
    if _has_command proot-distro; then
        printf 'Available'
    else
        printf 'Unavailable'
    fi
}

_system_info_show() {
    local width="${DEVILS_MINIOS_TERMINAL_WIDTH}"
    [[ ${width} -lt 40 ]] && width=60
    draw_box_top "${width}" "System Info"
    draw_box_line "${width}" "Launcher version : v${DEVILS_MINIOS_VERSION}"
    draw_box_line "${width}" "Platform         : ${DEVILS_MINIOS_PLATFORM}"
    draw_box_line "${width}" "Termux source    : ${DEVILS_MINIOS_TERMUX_SOURCE}"
    draw_box_line "${width}" "Android version  : ${DEVILS_MINIOS_ANDROID_VERSION}"
    draw_box_line "${width}" "Android API      : ${DEVILS_MINIOS_ANDROID_API}"
    draw_box_line "${width}" "Architecture     : ${DEVILS_MINIOS_ARCH}"
    draw_box_line "${width}" "Bash version     : ${BASH_VERSION}"
    draw_box_line "${width}" "Terminal width   : ${DEVILS_MINIOS_TERMINAL_WIDTH} (${DEVILS_MINIOS_UI_MODE} mode)"
    draw_box_line "${width}" "Storage (\$HOME)  : $(_system_info_storage_line)"
    draw_box_line "${width}" "Battery          : $(_system_info_battery_line)"
    draw_box_line "${width}" "proot-distro     : $(_system_info_proot_line)"
    draw_box_line "${width}" "Safe Mode        : ${DEVILS_MINIOS_SAFE_MODE}"
    draw_box_bottom "${width}"
}

_system_info_environment() {
    local width="${DEVILS_MINIOS_TERMINAL_WIDTH}"
    [[ ${width} -lt 40 ]] && width=60
    draw_box_top "${width}" "Environment"
    draw_box_line "${width}" "HOME             : ${HOME}"
    draw_box_line "${width}" "PREFIX           : ${PREFIX:-unset}"
    draw_box_line "${width}" "SHELL            : ${SHELL:-unset}"
    draw_box_line "${width}" "Install dir      : ${DEVILS_MINIOS_INSTALL_DIR}"
    draw_box_line "${width}" "Config dir       : ${DEVILS_MINIOS_CONFIG_DIR}"
    draw_box_line "${width}" "Cache dir        : ${DEVILS_MINIOS_CACHE_DIR}"
    draw_box_line "${width}" "Workspace root   : ${DEVILS_MINIOS_WORKSPACE_ROOT}"
    draw_box_bottom "${width}"
}

_system_info_storage_detail() {
    printf 'Filesystem detail for %s:\n' "${HOME}"
    df -h "${HOME}" 2>/dev/null || printf 'Storage information unavailable.\n'
    printf '\n'
    local du_line
    du_line="$(du -sh "${DEVILS_MINIOS_CONFIG_DIR}" 2>/dev/null | awk '{print $1}')"
    printf 'Launcher config/state/logs size: %s\n' "${du_line:-unknown}"
}

# Contract: system_info_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
system_info_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== System Info =="
        printf '%s\n' "1) Full system report"
        printf '%s\n' "2) Storage details"
        printf '%s\n' "3) Environment info"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _system_info_show; _pause "Press Enter to return to the menu" ;;
            2) _system_info_storage_detail; _pause "Press Enter to return to the menu" ;;
            3) _system_info_environment; _pause "Press Enter to return to the menu" ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
