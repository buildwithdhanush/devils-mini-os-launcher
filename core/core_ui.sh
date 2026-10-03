#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_ui.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# Covers UI primitives and theme/module helpers.
# PRD Reference: §19

# ============================================================================
# UI PRIMITIVES (§19)
# ============================================================================

_apply_ansi() {
    if _has_command tput; then
        tput "$@" 2>/dev/null || true
    fi
}

# Contract: clear_screen(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
clear_screen() {
    if _has_command tput; then
        tput clear 2>/dev/null || printf '\033[2J\033[H'
    else
        printf '\033[2J\033[H'
    fi
}

# Contract: draw_box_top(width, label); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
draw_box_top() {
    local width="${1:-60}"
    local label="${2:-}"
    local inner=$((width - 2))
    printf '╔'
    printf '%*s' "$((inner))" '' | tr ' ' '═'
    printf '╗\n'
}

# Contract: draw_box_line(width, text); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
draw_box_line() {
    local width="${1:-60}"
    local text="${2:-}"
    local padding=$((width - 2 - ${#text}))
    [[ ${padding} -lt 0 ]] && padding=0
    printf '║ %s' "${text}"
    printf '%*s' "${padding}" ''
    printf '║\n'
}

# Contract: draw_box_bottom(width); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
draw_box_bottom() {
    local width="${1:-60}"
    local inner=$((width - 2))
    printf '╚'
    printf '%*s' "$((inner))" '' | tr ' ' '═'
    printf '╝\n'
}

# Contract: show_banner(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
show_banner() {
    local banner="${DEVILS_MINIOS_CONFIG[banner]:-devil}"
    [[ "${DEVILS_MINIOS_UI_MODE}" == "minimal" ]] && return 0
    case "${banner}" in
        devil)
            printf '  ____             _ _  _       _   __  __ _      ___   \n'
            printf ' |  _ \\  _____   _| (_)(_) __ _| | |  \\/  (_)_  _/___|  \n'
            printf ' | | | |/ _ \\ \\ / / | || |/ _` | | | |\\/| | \\ \\/ / _ \\ \n'
            printf ' | |_| |  __/\\ V /| | || | (_| | | | |  | | |>  < (_) |\n'
            printf ' |____/ \\___| \\_/ |_|_|/ |_|\\__,_|_| |_|  |_|_/_/\\___/ \n'
            printf '                     |__/                              \n'
            ;;
        minimal)
            printf "Devil's Mini OS Launcher\n"
            ;;
        retro)
            printf '+--------------------------------------------+\n'
            printf '|  DEVIL'\''S MINI OS LAUNCHER v%-18s |\n' "${DEVILS_MINIOS_VERSION}"
            printf '+--------------------------------------------+\n'
            ;;
        cyber)
            printf '>> DEVILS://MINI-OS :: LAUNCHER v%s\n' "${DEVILS_MINIOS_VERSION}"
            ;;
        simple|*)
            printf "Devil's Mini OS Launcher v%s\n" "${DEVILS_MINIOS_VERSION}"
            ;;
    esac
    printf '\n'
}

# Canonical ordered module list for the interactive menu (§12, §15).
readonly -a DEVILS_MINIOS_MAIN_MENU_MODULES=(
    "linux_env:Linux Environment (proot distros/desktops)"
    "file_mgr:File Manager"
    "termux_apps:Termux Apps"
    "proot_apps:Proot Apps"
    "android_tools:Android Tools"
    "workspace:Workspace"
    "health_check:Health Check"
    "logs:Log Viewer"
    "customize:Customize (theme/banner)"
    "system_tools:System Tools"
    "system_info:System Info"
    "update:Update All"
    "settings:Settings"
)

# Contract: show_main_menu_full(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
show_main_menu_full() {
    local width="${DEVILS_MINIOS_TERMINAL_WIDTH}"
    [[ ${width} -lt 40 ]] && width=60
    clear_screen
    show_banner
    draw_box_top "${width}" "Main Menu"
    local i=1 entry label
    for entry in "${DEVILS_MINIOS_MAIN_MENU_MODULES[@]}"; do
        label="${entry#*:}"
        draw_box_line "${width}" "$(printf '%2d) %s' "${i}" "${label}")"
        i=$((i + 1))
    done
    draw_box_line "${width}" " 0) Exit"
    draw_box_bottom "${width}"
}

# Contract: show_main_menu_compact(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
show_main_menu_compact() {
    clear_screen
    show_banner
    printf '%s\n' "Main Menu - Devil's Mini OS Launcher"
    printf '%s\n' '----------------------------------------'
    local i=1 entry label
    for entry in "${DEVILS_MINIOS_MAIN_MENU_MODULES[@]}"; do
        label="${entry#*:}"
        printf '%2d) %s\n' "${i}" "${label}"
        i=$((i + 1))
    done
    printf ' 0) Exit\n'
}

# Contract: show_main_menu_minimal(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
show_main_menu_minimal() {
    clear_screen
    printf '%s\n' 'MINI OS MENU'
    local i=1 entry mod
    for entry in "${DEVILS_MINIOS_MAIN_MENU_MODULES[@]}"; do
        mod="${entry%%:*}"
        printf '%d %s\n' "${i}" "${mod}"
        i=$((i + 1))
    done
    printf '0 exit\n'
}

# Resolves a main-menu numeric choice (1-13) to a canonical module name for
# dispatch_module(). Returns 1 (and prints nothing) if out of range.
# Contract: main_menu_module_for_choice(choice); returns: value/path or non-zero on invalid input; side effects: none.
main_menu_module_for_choice() {
    local choice="$1"
    _is_int "${choice}" || return 1
    local idx=$((choice - 1))
    [[ ${idx} -ge 0 && ${idx} -lt ${#DEVILS_MINIOS_MAIN_MENU_MODULES[@]} ]] || return 1
    printf '%s' "${DEVILS_MINIOS_MAIN_MENU_MODULES[${idx}]%%:*}"
}

# Contract: show_main_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
show_main_menu() {
    case "${DEVILS_MINIOS_UI_MODE}" in
        full) show_main_menu_full ;;
        compact) show_main_menu_compact ;;
        minimal) show_main_menu_minimal ;;
        *) show_main_menu_compact ;;
    esac
}

# ============================================================================
# THEME / MODULE HELPERS
# ============================================================================

# Contract: apply_theme(theme); returns: 0 on success, non-zero on invalid input; side effects: updates and persists user customization.
apply_theme() {
    local theme="${1:-${DEVILS_MINIOS_CONFIG[theme]:-dracula}}"
    _is_valid_key "${theme}" "${DEVILS_MINIOS_ALLOWED_THEMES[@]}" || {
        _error "E900" "Unknown theme: ${theme}" 0
        return 2
    }
    DEVILS_MINIOS_CONFIG[theme]="${theme}"
    if [[ "${DEVILS_MINIOS_PLATFORM}" == "termux" ]]; then
        mkdir -p "${HOME}/.termux"
        case "${theme}" in
            dracula) printf '%s\n' 'background=#282a36' 'foreground=#f8f8f2' 'color0=#21222c' 'color7=#f8f8f2' > "${HOME}/.termux/colors.properties" ;;
            nord) printf '%s\n' 'background=#2e3440' 'foreground=#d8dee9' 'color0=#3b4252' 'color7=#eceff4' > "${HOME}/.termux/colors.properties" ;;
            solarized) printf '%s\n' 'background=#002b36' 'foreground=#839496' 'color0=#073642' 'color7=#eee8d5' > "${HOME}/.termux/colors.properties" ;;
            gruvbox) printf '%s\n' 'background=#282828' 'foreground=#ebdbb2' 'color0=#282828' 'color7=#ebdbb2' > "${HOME}/.termux/colors.properties" ;;
        esac
        if _has_command termux-reload-settings; then
            termux-reload-settings >/dev/null 2>&1 || true
        fi
    fi
    save_config
}

# Contract: set_banner(banner); returns: 0 on success, non-zero on invalid input; side effects: updates and persists user customization.
set_banner() {
    local banner="$1"
    _is_valid_key "${banner}" "${DEVILS_MINIOS_ALLOWED_BANNERS[@]}" || {
        _error "E900" "Unknown banner: ${banner}" 0
        return 2
    }
    DEVILS_MINIOS_CONFIG[banner]="${banner}"
    save_config
}

# Contract: dispatch_module(module); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
dispatch_module() {
    local module="$1"
    # §26.1 MOD-INIT-FAIL: a module disabled at load time is reported as
    # Unavailable (§38) instead of failing with "command not found".
    local module_file="${module}"
    case "${module}" in
        desktop_env|desktops) module_file="linux_env" ;;
        files) module_file="file_mgr" ;;
        android) module_file="android_tools" ;;
        doctor) module_file="health_check" ;;
        logs) module_file="log_viewer" ;;
        theme) module_file="customize" ;;
        tools) module_file="system_tools" ;;
        info) module_file="system_info" ;;
        update) module_file="update_all" ;;
        *) : ;;
    esac
    if declare -F _module_is_disabled >/dev/null 2>&1 && _module_is_disabled "${module_file}"; then
        _warn "E900" "Module unavailable (disabled for this session): ${module_file}" || true
        return 1
    fi
    case "${module}" in
        linux_env|desktop_env|desktops)
            linux_env_menu
            ;;
        file_mgr|files)
            file_mgr_menu
            ;;
        termux_apps)
            termux_apps_menu
            ;;
        proot_apps)
            proot_apps_menu
            ;;
        android_tools|android)
            android_tools_menu
            ;;
        workspace)
            workspace_menu
            ;;
        health_check|doctor)
            health_check_menu
            ;;
        logs)
            log_viewer_menu
            ;;
        customize|theme)
            customize_menu
            ;;
        system_tools|tools)
            system_tools_menu
            ;;
        system_info|info)
            system_info_menu
            ;;
        update)
            update_all_menu
            ;;
        settings)
            settings_menu
            ;;
        *)
            _error "E900" "Unknown module: ${module}" 0
            return 2
            ;;
    esac
}

