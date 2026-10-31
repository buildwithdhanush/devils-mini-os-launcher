#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/termux_apps.sh
# PRD Reference: §13.4, §18.3, §23.3
# Public: termux_apps_menu()

readonly -a DEVILS_MINIOS_TERMUX_APP_CATEGORIES=(development browsers desktop cli system security media networking)

_termux_apps_load() {
    local db_file
    db_file="$(data_file_path termux_apps.db)"
    load_database "${db_file}" 11 _validate_termux_app_record
}

_is_termux_app_category() {
    local candidate="$1" c
    for c in "${DEVILS_MINIOS_TERMUX_APP_CATEGORIES[@]}"; do
        [[ "${c}" == "${candidate}" ]] && return 0
    done
    return 1
}

_termux_apps_list() {
    local category="${1:-}"
    if [[ -n "${category}" ]] && ! _is_termux_app_category "${category}"; then
        _error "E900" "Unknown category: ${category}" 0
        return 2
    fi
    _termux_apps_load || return 1
    local line fields
    printf '%-14s %-22s %-14s %-8s\n' "ID" "NAME" "CATEGORY" "SOURCE"
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        [[ -n "${category}" && "${fields[2]}" != "${category}" ]] && continue
        printf '%-14s %-22s %-14s %-8s\n' "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[5]}"
    done
}

_termux_apps_install() {
    local app_id
    app_id="$(_prompt_default 'App id to install' '')"
    _termux_apps_load || return 1
    find_catalog_record "${app_id}" || { _error "E900" "Unknown app id: ${app_id}" 0; return 2; }
    local -a f=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local name="${f[1]}" package_name="${f[4]}" install_source="${f[5]}" note="${f[6]}"
    local gh_repo="${f[7]}" gh_ref="${f[8]}" gh_artifact="${f[9]}" gh_sha256="${f[10]}"

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}" || return 3

    case "${install_source}" in
        pkg)
            if [[ "${DEVILS_MINIOS_OFFLINE_MODE:-false}" == true ]]; then
                _warn "" "Termux pkg installation requires network access; --offline is set"
                return 1
            fi
            _has_command pkg || { _error "E900" "pkg command unavailable" 0; return 2; }
            if execute_structured pkg install "-y" "${package_name}"; then
                _info "Installed ${name} via pkg"
                # DEVILS_MINIOS_STATE is declared -gA in core.sh, which is
                # sourced by the loader before this module runs; ShellCheck
                # analyzes this file standalone (the loader's source path is
                # built at runtime, so even -x cannot follow it) and cannot
                # see the global declaration, so it flags this read/write as
                # SC2154 ("referenced but not assigned"), not SC2034.
                # shellcheck disable=SC2154
                DEVILS_MINIOS_STATE[last_successful_workflow]="termux_apps|pkg|${app_id}"
                save_state
            else
                _warn "" "pkg install failed or package unavailable for ${name}; skipping (graceful degradation)"
                return 1
            fi
            ;;
        github)
            if install_github_artifact "${gh_repo}" "${gh_ref}" "${gh_artifact}" "${gh_sha256}"; then
                _info "Installed ${name} from GitHub release ${gh_repo}@${gh_ref}"
                # DEVILS_MINIOS_STATE is declared -gA in core.sh, which is
                # sourced by the loader before this module runs; ShellCheck
                # analyzes this file standalone (the loader's source path is
                # built at runtime, so even -x cannot follow it) and cannot
                # see the global declaration. This is the only
                # DEVILS_MINIOS_STATE write in this file's github branch, so
                # ShellCheck additionally has no other reference to treat the
                # array as used, flagging it as unused (SC2034) alongside the
                # unknown-key reference (SC2154).
                # shellcheck disable=SC2154,SC2034
                DEVILS_MINIOS_STATE[last_successful_workflow]="termux_apps|github|${app_id}"
                save_state
            else
                _warn "" "GitHub artifact install failed for ${name}"
                return 1
            fi
            ;;
        *)
            _error "E900" "Unsupported install_source: ${install_source}" 0
            return 2
            ;;
    esac
    [[ "${note}" != "-" && -n "${note}" ]] && printf 'Note: %s\n' "${note}"
}

# Contract: termux_apps_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
termux_apps_menu() {
    local choice categories_display
    categories_display="$(
        local IFS='/'
        printf '%s' "${DEVILS_MINIOS_TERMUX_APP_CATEGORIES[*]}"
    )"
    while true; do
        clear_screen
        printf '%s\n' "== Termux Apps =="
        printf '%s\n' "1) List all apps"
        printf '2) List by category (%s)\n' "${categories_display}"
        printf '%s\n' "3) Install an app"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _termux_apps_list; _pause "Press Enter to return to the menu" ;;
            2)
                local cat
                cat="$(_prompt_default 'Category' 'development')"
                _termux_apps_list "${cat}"; _pause "Press Enter to return to the menu"
                ;;
            3) _termux_apps_install ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
