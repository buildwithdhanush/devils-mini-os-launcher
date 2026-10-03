#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/linux_env.sh
# PRD Reference: §13.2, §18.1, §18.4, §23.1, §23.2, §35.3
#
# Public functions: linux_env_menu()  generate_xstartup(distro, startup_binary, startup_args)
# Private functions are prefixed with _.

_linux_env_list_distros() {
    local db_file
    db_file="$(data_file_path proot_distros.db)"
    load_database "${db_file}" 7 _validate_distro_record || return 1
    local line fields
    printf '%-12s %-16s %-10s %-10s\n' "ID" "NAME" "ARCH" "STATUS"
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        printf '%-12s %-16s %-10s %-10s\n' "${fields[0]}" "${fields[1]}" "${fields[3]}" "${fields[5]}"
    done
}

_linux_env_installed_p() {
    local proot_id="$1"
    [[ -d "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${proot_id}" ]]
}

_linux_env_install_distro() {
    if [[ "${DEVILS_MINIOS_OFFLINE_MODE:-false}" == true ]]; then
        _warn "" "Proot distro installation requires network access; --offline is set"
        return 1
    fi
    _has_command proot-distro || { _error "E900" "proot-distro is not installed" 0; return 2; }
    local distro_id
    distro_id="$(_prompt_default 'Distro id (from list)' '')"
    get_distro_record "${distro_id}" || { _error "E900" "Unknown distro: ${distro_id}" 0; return 2; }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_DISTRO_REQUIRED_BYTES}" || return 3
    check_battery_gate "distro install" || return $?
    if _confirm "Install ${d[1]} (proot-distro id: ${d[2]})"; then
        execute_structured "proot-distro" "install" "${d[2]}"
        if [[ -z "${DEVILS_MINIOS_STATE[primary_distro]:-}" ]]; then
            DEVILS_MINIOS_STATE[primary_distro]="${d[0]}"
            save_state
        fi
        # DEVILS_MINIOS_STATE is declared -gA in core.sh, which is sourced by
        # the loader before this module runs; ShellCheck analyzes this file
        # standalone and cannot see that dynamic-path source, so it flags a
        # false-positive undefined-variable reference here.
        # shellcheck disable=SC2154
        DEVILS_MINIOS_STATE[last_successful_workflow]="linux_env|install|${d[0]}"
        save_state
    fi
}

_linux_env_launch_distro() {
    _has_command proot-distro || { _error "E900" "proot-distro is not installed" 0; return 2; }
    local distro_id
    distro_id="$(_prompt_default 'Distro id to launch' "${DEVILS_MINIOS_STATE[primary_distro]:-}")"
    get_distro_record "${distro_id}" || { _error "E900" "Unknown distro: ${distro_id}" 0; return 2; }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    _linux_env_installed_p "${d[2]}" || { _error "E203" "${d[1]} is not installed" 0; return 3; }
    execute_structured "proot-distro" "login" "${d[2]}"
}

_linux_env_list_desktops() {
    local db_file
    db_file="$(data_file_path desktops.db)"
    load_database "${db_file}" 7 _validate_desktop_record || return 1
    local line fields
    printf '%-10s %-30s %-10s %-8s\n' "NAME" "DESCRIPTION" "SYSTEMD" "MIN_RAM"
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        printf '%-10s %-30s %-10s %-8s\n' "${fields[0]}" "${fields[1]}" "${fields[5]}" "${fields[6]}"
    done
}

# generate_xstartup(distro, startup_binary, startup_args)  (§13.2)
# Returns: 0 success; 2 unknown distro; 3 rootfs not installed; 4 startup_binary
# fails allowlist validation.
# Contract: generate_xstartup(distro, startup_binary, startup_args); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
generate_xstartup() {
    local distro="$1" startup_binary="$2" startup_args="${3:--}"
    local -a valid_binaries=("startxfce4" "startlxqt" "startlxde" "mate-session" "i3" "openbox-session" "startfluxbox" "jwm")
    # §48.2: E402's registered exit status is 2 (validation error), not 4
    # (user abort) — this is a malformed-catalog-record rejection, not a
    # user-declined confirmation.
    _is_valid_key "${startup_binary}" "${valid_binaries[@]}" || { _error "E402" "startup_binary not allowlisted: ${startup_binary}" 0; return 2; }

    get_distro_record "${distro}" || { _error "E900" "Unknown distro: ${distro}" 0; return 2; }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local proot_id="${d[2]}"
    local rootfs="${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${proot_id}"
    [[ -d "${rootfs}" ]] || { _error "E203" "Rootfs not installed for ${proot_id}" 0; return 3; }

    local vnc_dir="${rootfs}/root/.vnc"
    local xstartup="${vnc_dir}/xstartup"
    local tmp="${xstartup}.tmp.$$"
    mkdir -p "${vnc_dir}" 2>/dev/null || true
    {
        printf '#!/usr/bin/env bash\n'
        printf '%s' "${startup_binary}"
        if [[ "${startup_args}" != "-" && -n "${startup_args}" ]]; then
            local token
            local -a arg_tokens=()
            local IFS=","
            # shellcheck disable=SC2206
            arg_tokens=(${startup_args})
            for token in "${arg_tokens[@]}"; do
                [[ "${token}" =~ ^[A-Za-z0-9_.=-]{1,32}$ ]] || { _error "E403" "Invalid startup arg token: ${token}" 0; return 2; }
                printf ' %q' "${token}"
            done
        fi
        printf '\n'
    } > "${tmp}" 2>/dev/null || { _error "E900" "Could not write xstartup (rootfs writable via proot only)" 0; return 3; }
    chmod 755 "${tmp}" 2>/dev/null || true
    mv -f "${tmp}" "${xstartup}"
    return 0
}

_linux_env_setup_desktop() {
    local desktop_name
    desktop_name="$(_prompt_default 'Desktop (xfce4/lxqt/lxde/mate/i3wm/openbox/fluxbox/jwm)' 'xfce4')"
    get_desktop_record "${desktop_name}" || { _error "E900" "Unknown desktop: ${desktop_name}" 0; return 2; }
    local -a de=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local packages="${de[2]}" startup_binary="${de[3]}" startup_args="${de[4]}" systemd_flag="${de[5]}"

    if [[ "${systemd_flag}" == "true" ]]; then
        _warn "" "${desktop_name} depends on systemd, which is not available under proot. Expect limited functionality."
        # §48.2 E440: systemd acknowledgement/decline condition. A decline is
        # a deliberate user choice, not a failure, so it is logged (for
        # traceability of the acknowledgement) rather than treated as fatal;
        # it uses the same exit status (4) as every other user-declined
        # confirmation in this codebase (e.g. _confirm() itself, the battery
        # gate in core_state.sh) instead of silently returning success (0).
        if ! _confirm "Continue anyway"; then
            # §48.2 E440: INFO level (a decline is a deliberate user choice,
            # not a warning-worthy condition) - only the exit status (4) and
            # retryable-after-acknowledgement behavior are error-like.
            _info "[E440] ${desktop_name} systemd dependency acknowledged and declined by user"
            return 4
        fi
        _info "${desktop_name} systemd dependency acknowledged; continuing"
    fi

    local distro_id
    distro_id="$(_prompt_default 'Target distro id' "${DEVILS_MINIOS_STATE[primary_distro]:-}")"
    get_distro_record "${distro_id}" || { _error "E900" "Unknown distro: ${distro_id}" 0; return 2; }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    _linux_env_installed_p "${d[2]}" || { _error "E203" "${d[1]} is not installed" 0; return 3; }

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_DESKTOP_REQUIRED_BYTES}" || return 3
    check_battery_gate "desktop install" || return $?
    warn_proot_limits

    local pkg
    while IFS= read -r pkg; do
        [[ -n "${pkg}" ]] || continue
        install_proot_package "${d[0]}" "${pkg}" || _warn "" "Failed to install package: ${pkg}"
    done < <(printf '%s\n' "${packages}" | tr ',' '\n')

    if generate_xstartup "${d[0]}" "${startup_binary}" "${startup_args}"; then
        _info "xstartup generated for ${desktop_name} on ${d[1]}"
    else
        _warn "" "xstartup generation failed"
    fi
}

_linux_env_start_desktop() {
    local distro_id desktop_name
    distro_id="$(_prompt_default 'Distro id' "${DEVILS_MINIOS_STATE[primary_distro]:-}")"
    desktop_name="$(_prompt_default 'Desktop name' 'xfce4')"
    get_desktop_record "${desktop_name}" || { _error "E900" "Unknown desktop: ${desktop_name}" 0; return 2; }
    local -a de=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    run_desktop_startup "${distro_id}" "${de[3]}" "${de[4]}"
}

# Contract: linux_env_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
linux_env_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Linux Environment =="
        printf '%s\n' "1) List proot distros"
        printf '%s\n' "2) Install a distro"
        printf '%s\n' "3) Launch a distro shell"
        printf '%s\n' "4) List desktops"
        printf '%s\n' "5) Install/configure a desktop"
        printf '%s\n' "6) Start a desktop (proot login + startup binary)"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _linux_env_list_distros; _confirm "Continue" || true ;;
            2) _linux_env_install_distro ;;
            3) _linux_env_launch_distro ;;
            4) _linux_env_list_desktops; _confirm "Continue" || true ;;
            5) _linux_env_setup_desktop ;;
            6) _linux_env_start_desktop ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
