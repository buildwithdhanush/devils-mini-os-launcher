#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/proot_apps.sh
# PRD Reference: §13.5, §18.2, §23.1
# Public: proot_apps_menu()

declare -g DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH=false

_proot_apps_load() {
    local db_file
    db_file="$(data_file_path proot_apps.db)"
    load_database "${db_file}" 7 _validate_proot_app_record
}

_proot_apps_arch_compatible() {
    local arch_field="$1"
    [[ "${arch_field}" == "all" ]] && return 0
    local a
    while IFS= read -r a; do
        [[ "${a}" == "${DEVILS_MINIOS_ARCH}" ]] && return 0
    done < <(printf '%s\n' "${arch_field}" | tr ',' '\n')
    return 1
}

_proot_apps_list() {
    local category="${1:-}"
    _proot_apps_load || return 1
    local line fields compatible
    printf '%-14s %-20s %-14s %-10s\n' "ID" "NAME" "CATEGORY" "ARCH"
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        [[ -n "${category}" && "${fields[2]}" != "${category}" ]] && continue
        if _proot_apps_arch_compatible "${fields[5]}"; then
            compatible=yes
        else
            compatible=no
            [[ "${DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH}" != true ]] && continue
        fi
        printf '%-14s %-20s %-14s %-10s%s\n' "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[5]}" \
            "$([[ ${compatible} == no ]] && printf ' [INCOMPATIBLE: %s]' "${DEVILS_MINIOS_ARCH}")"
    done
}

_proot_apps_toggle_incompatible() {
    if [[ "${DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH}" == true ]]; then
        DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH=false
        printf 'Incompatible architectures are now hidden.\n'
    else
        DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH=true
        printf 'Incompatible architectures are now shown.\n'
    fi
}

_proot_apps_install() {
    local app_id distro_id
    app_id="$(_prompt_default 'App id to install' '')"
    _proot_apps_load || return 1
    find_catalog_record "${app_id}" || { _error "E900" "Unknown proot app id: ${app_id}" 0; return 2; }
    local -a f=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local name="${f[1]}" install_target="${f[4]}" arch_field="${f[5]}" distro_scope="${f[6]}"

    if ! _proot_apps_arch_compatible "${arch_field}"; then
        _warn "" "${name} targets architecture(s) '${arch_field}'; this device is '${DEVILS_MINIOS_ARCH}'"
        _confirm "Install anyway despite the architecture mismatch" || return 0
    fi

    distro_id="$(_prompt_default 'Target proot distro id' "${DEVILS_MINIOS_STATE[primary_distro]:-}")"
    if [[ "${distro_scope}" != "any" ]]; then
        local ok=false d
        while IFS= read -r d; do [[ "${d}" == "${distro_id}" ]] && ok=true; done < <(printf '%s\n' "${distro_scope}" | tr ',' '\n')
        [[ "${ok}" == true ]] || { _error "E900" "${name} is not offered for distro '${distro_id}'" 0; return 2; }
    fi

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}" || return 3
    if install_proot_package "${distro_id}" "${install_target}"; then
        _info "Installed ${name} into ${distro_id}"
        # DEVILS_MINIOS_STATE is declared -gA in core.sh, which is sourced by
        # the loader before this module runs; ShellCheck analyzes this file
        # standalone and cannot see that dynamic-path source, so it flags a
        # false-positive undefined-variable reference here.
        # shellcheck disable=SC2154
        DEVILS_MINIOS_STATE[last_successful_workflow]="proot_apps|install|${app_id}"
        save_state
    else
        _warn "" "Install failed for ${name}"
        return 1
    fi
}

# Contract: proot_apps_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
proot_apps_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Proot Apps =="
        printf '%s\n' "1) List all apps"
        printf '%s\n' "2) List by category"
        printf '%s\n' "3) Install an app"
        printf "4) Toggle 'show incompatible architectures' (currently: %s)\n" "${DEVILS_MINIOS_SHOW_INCOMPATIBLE_ARCH}"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _proot_apps_list; _confirm "Continue" || true ;;
            2)
                local cat
                cat="$(_prompt_default 'Category (dev-proot/browser/office/graphics/media/communication/security/networking/games/system/education/science/utilities)' 'dev-proot')"
                _proot_apps_list "${cat}"; _confirm "Continue" || true
                ;;
            3) _proot_apps_install ;;
            4) _proot_apps_toggle_incompatible; sleep 1 ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
