#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/android_tools.sh
# PRD Reference: §13.6, §25.2, §38
# Public: android_tools_menu()

_android_tools_adb() {
    _has_command adb || { _warn "" "adb is not installed; install via Termux Apps (package: android-tools)"; return 1; }
    execute_structured adb devices || true
}

_android_tools_fastboot() {
    _has_command fastboot || { _warn "" "fastboot is not installed; install via Termux Apps (package: android-tools)"; return 1; }
    execute_structured fastboot devices || true
}

_android_tools_termux_api_status() {
    if _has_command termux-battery-status; then
        printf 'Termux:API: Available\n'
    else
        printf 'Termux:API: Unavailable (install the Termux:API app and package for full functionality)\n'
    fi
}

_android_tools_info() {
    printf 'Android version: %s (API level detection is best-effort)\n' "${DEVILS_MINIOS_ANDROID_VERSION}"
    printf 'Architecture: %s\n' "${DEVILS_MINIOS_ARCH}"
    printf 'Termux source: %s\n' "${DEVILS_MINIOS_TERMUX_SOURCE}"
}

# Contract: android_tools_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
android_tools_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Android Tools =="
        printf '%s\n' "1) adb devices"
        printf '%s\n' "2) fastboot devices"
        printf '%s\n' "3) Termux:API status"
        printf '%s\n' "4) Android/device info"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _android_tools_adb; _confirm "Continue" || true ;;
            2) _android_tools_fastboot; _confirm "Continue" || true ;;
            3) _android_tools_termux_api_status; _confirm "Continue" || true ;;
            4) _android_tools_info; _confirm "Continue" || true ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
