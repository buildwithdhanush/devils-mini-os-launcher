#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/update_all.sh
# PRD Reference: §13.13
# Public: update_all_menu()
# Selective updates of Termux packages and installed Proot distro packages;
# dry-run mode; ordered update operations; failure reporting; asks for
# proot or Termux scope. This module updates *installed content*, not the
# launcher itself -- self-update (`devils-minios --update`) is a distinct
# lifecycle command owned by devils-minios.sh/core.sh (§30.4-§30.6).
# All execution goes through core.sh::execute_structured() (§23.1); no
# package-manager command is ever built via string interpolation.

declare -g DEVILS_MINIOS_UPDATE_DRY_RUN=false

_update_all_toggle_dry_run() {
    if [[ "${DEVILS_MINIOS_UPDATE_DRY_RUN}" == true ]]; then
        DEVILS_MINIOS_UPDATE_DRY_RUN=false
        printf 'Dry-run mode disabled; updates will be applied.\n'
    else
        DEVILS_MINIOS_UPDATE_DRY_RUN=true
        printf 'Dry-run mode enabled; updates will only be previewed.\n'
    fi
}

# Returns, via the DEVILS_MINIOS_UPDATE_ARGV array, the argv[] for the given
# package manager and mode ("refresh"|"apply"). Mirrors the fixed per-manager
# argument shapes already established in core.sh::install_proot_package().
declare -g -a DEVILS_MINIOS_UPDATE_ARGV=()
_update_all_argv_for() {
    local package_manager="$1"
    local mode="$2"
    case "${package_manager}" in
        apt)
            [[ "${mode}" == "refresh" ]] && DEVILS_MINIOS_UPDATE_ARGV=("update") \
                || DEVILS_MINIOS_UPDATE_ARGV=("upgrade" "-y")
            ;;
        pacman)
            DEVILS_MINIOS_UPDATE_ARGV=("-Syu" "--noconfirm")
            ;;
        dnf)
            DEVILS_MINIOS_UPDATE_ARGV=("upgrade" "-y")
            ;;
        apk)
            [[ "${mode}" == "refresh" ]] && DEVILS_MINIOS_UPDATE_ARGV=("update") \
                || DEVILS_MINIOS_UPDATE_ARGV=("upgrade")
            ;;
        xbps)
            DEVILS_MINIOS_UPDATE_ARGV=("-Suy")
            ;;
        *)
            DEVILS_MINIOS_UPDATE_ARGV=()
            return 1
            ;;
    esac
    return 0
}

# Updates Termux's own packages (§25.1 does not list a fixed size for
# updates; the storage/battery gates below use the app-install defaults as a
# conservative floor for this heavy operation).
_update_all_termux() {
    check_battery_gate "Termux package update" || return $?
    if [[ "${DEVILS_MINIOS_UPDATE_DRY_RUN}" == true ]]; then
        printf 'Dry run - packages with available updates:\n'
        execute_structured pkg "list-upgradable" || printf '(none, or pkg does not support list-upgradable on this build)\n'
        return 0
    fi
    _confirm "Update all Termux packages now (pkg update && pkg upgrade -y)" || return 0
    if execute_structured pkg "update" -y && execute_structured pkg "upgrade" -y; then
        _info "Termux packages updated"
        # DEVILS_MINIOS_STATE is declared -gA in core.sh, which is sourced by
        # the loader before this module runs; ShellCheck analyzes this file
        # standalone and cannot see that dynamic-path source, so it flags a
        # false-positive undefined-variable reference here.
        # shellcheck disable=SC2154
        DEVILS_MINIOS_STATE[last_successful_workflow]="update_all|termux|all"
        save_state
        return 0
    fi
    _warn "" "Termux package update reported a failure"
    return 1
}

# Updates one installed Proot distro's packages via its own package manager.
_update_all_one_distro() {
    local distro_id="$1"
    get_distro_record "${distro_id}" || { _error "E900" "Unknown proot distro: ${distro_id}" 0; return 2; }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local proot_id="${d[2]}" package_manager="${d[6]}" name="${d[1]}"
    [[ -d "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${proot_id}" ]] || { _error "E203" "${name} is not installed" 0; return 3; }

    if [[ "${DEVILS_MINIOS_UPDATE_DRY_RUN}" == true ]]; then
        _update_all_argv_for "${package_manager}" "apply"
        printf 'Dry run - would run: proot-distro login %s -- %s %s\n' \
            "${proot_id}" "${package_manager}" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
        return 0
    fi

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}" || return 3

    local rc=0
    case "${package_manager}" in
        apt|apk)
            _update_all_argv_for "${package_manager}" "refresh"
            execute_structured "proot-distro" "login" "${proot_id}" "--" "${package_manager}" "${DEVILS_MINIOS_UPDATE_ARGV[@]}" || rc=1
            ;;
    esac
    _update_all_argv_for "${package_manager}" "apply" || { _error "E900" "Unsupported package manager: ${package_manager}" 0; return 2; }
    execute_structured "proot-distro" "login" "${proot_id}" "--" "${package_manager}" "${DEVILS_MINIOS_UPDATE_ARGV[@]}" || rc=1

    if [[ ${rc} -eq 0 ]]; then
        _info "${name} packages updated"
        DEVILS_MINIOS_STATE[last_successful_workflow]="update_all|proot|${distro_id}"
        save_state
    else
        _warn "" "Update failed for ${name}"
    fi
    return ${rc}
}

_update_all_single_proot() {
    local distro_id
    distro_id="$(_prompt_default 'Distro id to update' "${DEVILS_MINIOS_STATE[primary_distro]:-}")"
    _update_all_one_distro "${distro_id}"
}

# Ordered update of every currently-installed proot distro, with per-item
# failure reporting; one failure never stops the remaining items.
_update_all_installed_proot() {
    local db_file
    db_file="$(data_file_path proot_distros.db)"
    load_database "${db_file}" 7 _validate_distro_record || return 1

    local -a results=()
    local line fields proot_id distro_id status
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        distro_id="${fields[0]}"
        proot_id="${fields[2]}"
        [[ -d "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${proot_id}" ]] || continue
        if _update_all_one_distro "${distro_id}"; then
            status="OK"
        else
            status="FAILED"
        fi
        results+=("${distro_id}: ${status}")
    done

    if [[ ${#results[@]} -eq 0 ]]; then
        printf 'No installed proot distros found.\n'
        return 0
    fi
    printf '\n-- Update summary --\n'
    printf '%s\n' "${results[@]}"
}

# Contract: update_all_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
update_all_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Update All =="
        printf 'Dry-run mode: %s\n\n' "${DEVILS_MINIOS_UPDATE_DRY_RUN}"
        printf '%s\n' "1) Update Termux packages"
        printf '%s\n' "2) Update a single proot distro"
        printf '%s\n' "3) Update all installed proot distros (ordered, failure report)"
        printf '%s\n' "4) Toggle dry-run mode"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _update_all_termux; _pause "Press Enter to return to the menu" ;;
            2) _update_all_single_proot; _pause "Press Enter to return to the menu" ;;
            3) _update_all_installed_proot; _pause "Press Enter to return to the menu" ;;
            4) _update_all_toggle_dry_run; sleep 1 ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
