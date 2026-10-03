#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/customize.sh
# PRD Reference: §13.10, §17.6, §34, §38
# Public: customize_menu()
# Theme changes are idempotent; no duplicate shell configuration blocks.

_customize_theme() {
    local theme
    theme="$(_prompt_default 'Theme (dracula/nord/solarized/gruvbox)' "${DEVILS_MINIOS_CONFIG[theme]:-dracula}")"
    apply_theme "${theme}"
}

_customize_banner() {
    local banner
    banner="$(_prompt_default 'Banner (devil/minimal/retro/cyber/simple)' "${DEVILS_MINIOS_CONFIG[banner]:-devil}")"
    set_banner "${banner}"
}

_customize_banner_animation() {
    if [[ "${DEVILS_MINIOS_CONFIG[banner_animation]:-false}" == true ]]; then
        DEVILS_MINIOS_CONFIG[banner_animation]=false
        printf 'Banner animation disabled.\n'
    else
        DEVILS_MINIOS_CONFIG[banner_animation]=true
        printf 'Banner animation enabled.\n'
    fi
    save_config
}

_customize_preview() {
    show_banner
}

# Contract: customize_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
customize_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Customize =="
        printf 'Theme: %s   Banner: %s   Animation: %s\n\n' \
            "${DEVILS_MINIOS_CONFIG[theme]:-dracula}" "${DEVILS_MINIOS_CONFIG[banner]:-devil}" "${DEVILS_MINIOS_CONFIG[banner_animation]:-false}"
        printf '%s\n' "1) Change theme"
        printf '%s\n' "2) Change banner"
        printf '%s\n' "3) Toggle banner animation"
        printf '%s\n' "4) Preview banner"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _customize_theme ;;
            2) _customize_banner ;;
            3) _customize_banner_animation; sleep 1 ;;
            4) _customize_preview; _confirm "Continue" || true ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
