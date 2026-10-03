#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_recovery.sh
# Internal continuation of core.sh; not a feature module.
# PRD Reference: §26.1, §33.2, §40

# _safe_mode_primary_distro_valid_p() — PRD §40.1. Safe Mode may offer a
# Proot relaunch only when the recorded distro is catalog-valid and its rootfs
# is a real, contained directory. The final check is repeated immediately
# before execution by the caller to reduce the check/use window.
_safe_mode_primary_distro_valid_p() {
    local distro_id="${DEVILS_MINIOS_STATE[primary_distro]:-}"
    local -a distro=()
    local rootfs resolved_rootfs
    [[ -n "${distro_id}" ]] || return 1
    get_distro_record "${distro_id}" || return 1
    distro=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    rootfs="${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${distro[2]}"
    [[ -d "${rootfs}" && ! -L "${rootfs}" ]] || return 1
    validate_path "${rootfs}" "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}" || return 1
    resolved_rootfs="${DEVILS_MINIOS_PATH_RESOLVED:-}"
    [[ -n "${resolved_rootfs}" && -d "${resolved_rootfs}" && ! -L "${resolved_rootfs}" ]] || return 1
    return 0
}

# nuclear_reset() — PRD §33.2. Safe Mode-only disaster recovery:
# quarantine the entire configuration directory, regenerate clean defaults,
# restore only individually validated banners/templates, then transition
# through RECOVERY to FIRST_BOOT. The quarantine is intentionally retained as
# local evidence rather than silently deleted.
# Contract: nuclear_reset(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
nuclear_reset() {
    [[ "${DEVILS_MINIOS_CURRENT_STATE}" == SAFE_MODE ]] || {
        _error "E400" "Nuclear reset is available only from Safe Mode" 0
        return 2
    }

    local cfg="${DEVILS_MINIOS_CONFIG_DIR}"
    local parent ts quarantine
    parent="$(dirname -- "${cfg}")"
    ts="$(date +%Y%m%d-%H%M%S)"
    quarantine="${parent}/devils-minios-corrupted-${ts}"

    [[ -d "${cfg}" && ! -L "${cfg}" ]] || {
        _error "E703" "Configuration directory is missing or unsafe for nuclear reset" 0
        return 2
    }
    validate_path "${cfg}" "${parent}" || {
        _error "$(_path_validation_error_code)" "Configuration directory failed pre-reset validation" 0
        return 2
    }
    local resolved_cfg="${DEVILS_MINIOS_PATH_RESOLVED:-${cfg}}"
    validate_path "${quarantine}" "${parent}" || {
        _error "$(_path_validation_error_code)" "Nuclear-reset quarantine path is invalid" 0
        return 2
    }
    [[ ! -e "${quarantine}" && ! -L "${quarantine}" ]] || {
        _error "E703" "Nuclear-reset quarantine already exists; refusing to overwrite evidence" 0
        return 2
    }

    if ! execute_structured mv "${resolved_cfg}" "${quarantine}"; then
        _error "E703" "Nuclear reset could not quarantine the existing configuration directory" 0
        return 2
    fi

    mkdir -p -- "${cfg}/banners" "${cfg}/templates" "${cfg}/logs" "${cfg}/tmp" "${cfg}/pids" "${cfg}/crashes" || {
        _error "E703" "Nuclear reset could not create a clean configuration directory" 0
        return 2
    }
    chmod 700 "${cfg}" 2>/dev/null || true

    load_default_config
    if ! save_config || ! validate_config; then
        _error "E703" "Nuclear reset could not persist and validate default configuration" 0
        return 2
    fi
    default_state
    if ! save_state || ! validate_state; then
        _error "E703" "Nuclear reset could not persist and validate default state" 0
        return 2
    fi
    rm -f -- "${DEVILS_MINIOS_ONBOARDING_MARKER}" "${DEVILS_MINIOS_CRASH_FLAG}" 2>/dev/null || true

    local asset source dest
    for asset in banners templates; do
        source="${quarantine}/${asset}"
        dest="${cfg}/${asset}"
        if [[ -d "${source}" && ! -L "${source}" ]]; then
            local resolved_source resolved_dest
            if validate_path "${source}" "${quarantine}"; then
                resolved_source="${DEVILS_MINIOS_PATH_RESOLVED:-${source}}"
            else
                write_log_file "WARN" "Nuclear reset: skipped invalid ${asset} source"
                continue
            fi
            if validate_path "${dest}" "${cfg}"; then
                resolved_dest="${DEVILS_MINIOS_PATH_RESOLVED:-${dest}}"
            else
                write_log_file "WARN" "Nuclear reset: skipped invalid ${asset} destination"
                continue
            fi
            # cp -a preserves validated user assets without dereferencing
            # symlink entries inside them. Both source and destination were
            # resolved and contained immediately before this mutation.
            execute_structured cp "-a" "${resolved_source}/." "${resolved_dest}/" || {
                write_log_file "WARN" "Nuclear reset: could not restore validated ${asset}"
            }
        fi
    done

    if ! record_state_transition "RECOVERY"; then
        _error "E703" "Nuclear reset could not enter RECOVERY state" 0
        return 2
    fi
    if ! record_state_transition "FIRST_BOOT"; then
        _error "E703" "Nuclear reset could not enter FIRST_BOOT state" 0
        return 2
    fi
    write_log_file "WARN" "Nuclear reset complete; corrupted configuration quarantined at ${quarantine}"
    return 0
}

