#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_config.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# PRD Reference: §17

# ============================================================================
# CONFIGURATION (§17) — strict grammar, atomic I/O, restore, import
# ============================================================================

_parse_strict_kv_file() {
    local file_path="$1"
    local -n target_ref="$2"
    local allowed_ref="$3"
    local -a allowed_keys=()
    local k
    for k in ${allowed_ref}; do
        allowed_keys+=("${k}")
    done

    [[ -f "${file_path}" ]] || return 1
    target_ref=()
    local -A seen=()
    local line_num=0 line key value
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line_num=$((line_num + 1))
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        if [[ ! "${line}" =~ ^[a-zA-Z0-9_]+=.*$ ]]; then
            _warn "E411" "Malformed key=value line ${line_num} in ${file_path}: ${line}"
            return 1
        fi
        key="${line%%=*}"
        value="${line#*=}"
        if [[ -n "${seen[${key}]:-}" ]]; then
            _warn "E411" "Duplicate key '${key}' on line ${line_num} in ${file_path}"
            return 1
        fi
        seen["${key}"]=1
        if ! _is_valid_key "${key}" "${allowed_keys[@]}"; then
            _warn "E411" "Unknown key '${key}' on line ${line_num} in ${file_path}"
            return 1
        fi
        if _is_valid_key "${key}" "${DEVILS_MINIOS_RUNTIME_CONTEXT_KEYS[@]}"; then
            _warn "E411" "Runtime context key '${key}' is forbidden in ${file_path}"
            return 1
        fi
        target_ref["${key}"]="${value}"
    done < "${file_path}"
    return 0
}

_validate_persisted_config_values() {
    local -n cfg_ref="$1"
    [[ "${cfg_ref[config_version]:-}" == "${DEVILS_MINIOS_CONFIG_VERSION}" ]] || {
        _warn "E411" "config_version must be ${DEVILS_MINIOS_CONFIG_VERSION}"
        return 1
    }
    [[ "${cfg_ref[language]:-}" == "en" ]] || {
        _warn "E411" "language is reserved and must remain 'en'"
        return 1
    }
    local key
    for key in banner_animation auto_launch check_updates; do
        _is_bool "${cfg_ref[${key}]:-}" || {
            _warn "E411" "Invalid boolean for ${key}: ${cfg_ref[${key}]:-}"
            return 1
        }
    done
    for key in health_check_interval network_timeout network_retries; do
        _is_int "${cfg_ref[${key}]:-}" || {
            _warn "E411" "Invalid integer for ${key}: ${cfg_ref[${key}]:-}"
            return 1
        }
    done
    _is_valid_key "${cfg_ref[log_level]:-}" ERROR WARN INFO DEBUG || {
        _warn "E411" "Invalid log_level: ${cfg_ref[log_level]:-}"
        return 1
    }
    _is_valid_key "${cfg_ref[theme]:-}" "${DEVILS_MINIOS_ALLOWED_THEMES[@]}" || {
        _warn "E411" "Invalid theme: ${cfg_ref[theme]:-}"
        return 1
    }
    _is_valid_key "${cfg_ref[banner]:-}" "${DEVILS_MINIOS_ALLOWED_BANNERS[@]}" || {
        _warn "E411" "Invalid banner: ${cfg_ref[banner]:-}"
        return 1
    }
    return 0
}

# _installed_manifest_tampered() - §48.2 E412 / §26.1 CFG-TAMPER: the
# actual PRD §30.5 integrity/manifest cross-check, performed as part of
# every configuration load. Per §26.1's CFG-TAMPER row, the trigger is a
# checksum mismatch against the *installed manifest* discovered while
# parsing config ("the update trust-anchor area of core.sh/devils-minios.sh
# itself reports a checksum mismatch against the installed manifest,
# §30.5") - i.e. this is an installation-integrity signal, not a property
# of the config file itself (unlike the old, insufficient permissions/
# symlink-only check this replaces). It reuses the same integrity
# mechanism already sanctioned for this purpose elsewhere (install.sh
# --verify's _run_verify(), devils_self_update.sh's release check):
# sha256sum -c against SHA256SUMS, dispatched only through
# execute_structured() (§23), never a direct subprocess call.
#
# A missing manifest is deliberately NOT treated as tampering: §30's
# install-time check already treats "no SHA256SUMS in source" as a valid,
# unverified-but-not-tampered state for a plain git-clone source, and this
# cross-check must not manufacture a false CFG-TAMPER for that same
# already-accepted case.
_installed_manifest_tampered() {
    local manifest="${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS"
    [[ -f "${manifest}" ]] || return 1
    if ( cd "${DEVILS_MINIOS_INSTALL_DIR}" && execute_structured sha256sum "-c" "SHA256SUMS" "--status" ); then
        return 1
    fi
    return 0
}

_copy_config_assoc() {
    local -n source_ref="$1"
    # target_ref is a nameref to the caller's associative array (name given
    # in $2); ShellCheck cannot trace `-n` array-index writes through a
    # nameref back to the caller's array, so it misreads every write below
    # as dead (SC2034), including the final one on the loop's assignment
    # line. The narrow disable is required on that assignment itself, not
    # just the declaration/reset lines above it.
    # shellcheck disable=SC2178,SC2034
    local -n target_ref="$2"
    target_ref=()
    local k
    for k in "${!source_ref[@]}"; do
        # shellcheck disable=SC2034
        target_ref["${k}"]="${source_ref[${k}]}"
    done
}

_refresh_runtime_facts() {
    # DEVILS_MINIOS_CONFIG is declared -gA in modules/core.sh, which sources
    # this file; ShellCheck analyzes this file standalone and cannot see
    # that declaration, so it does not know the subscript is a string key
    # into an associative array and instead treats the bareword key as an
    # arithmetic-context variable reference, flagging it as SC2154
    # ("referenced but not assigned").
    # shellcheck disable=SC2154
    DEVILS_MINIOS_CONFIG[termux_source]="${DEVILS_MINIOS_TERMUX_SOURCE}"
    # shellcheck disable=SC2154
    DEVILS_MINIOS_CONFIG[android_version]="${DEVILS_MINIOS_ANDROID_VERSION}"
    # shellcheck disable=SC2154
    DEVILS_MINIOS_CONFIG[architecture]="${DEVILS_MINIOS_ARCH}"
}

# Contract: load_default_config(none); returns: 0 on success, non-zero on failure; side effects: loads or restores runtime/config/state data.
load_default_config() {
    local defaults_file="${DEVILS_MINIOS_INSTALL_DIR}/data/defaults.conf"
    local fallback_dir fallback_file
    local allowed_flat="${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]}"
    local key
    local -A defaults=()
    local -A candidate=()

    # If a self-update rollback failed and the active install directory was
    # moved aside, Safe Mode may still be running from already-loaded code.
    # In that one recovery condition only, use defaults.conf from a real
    # retained previous-install directory. Never fall back when the active
    # install exists but its defaults file is missing/invalid.
    if [[ ! -d "${DEVILS_MINIOS_INSTALL_DIR}" && ! -L "${DEVILS_MINIOS_INSTALL_DIR}" ]]; then
        for fallback_dir in "${DEVILS_MINIOS_INSTALL_DIR}".previous.*; do
            [[ -d "${fallback_dir}" && ! -L "${fallback_dir}" ]] || continue
            fallback_file="${fallback_dir}/data/defaults.conf"
            [[ -f "${fallback_file}" && -r "${fallback_file}" && ! -L "${fallback_file}" ]] || continue
            defaults_file="${fallback_file}"
            break
        done
    fi
    [[ -f "${defaults_file}" && -r "${defaults_file}" && ! -L "${defaults_file}" ]] || {
        _error "E900" "Default configuration file is missing or unreadable: ${defaults_file}" 0
        return 1
    }
    _parse_strict_kv_file "${defaults_file}" defaults "${allowed_flat}" || {
        _error "E900" "Default configuration file failed strict validation: ${defaults_file}" 0
        return 1
    }
    for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
        [[ -n "${defaults[${key}]+x}" ]] || {
            _error "E900" "Default configuration is missing required key: ${key}" 0
            return 1
        }
    done
    _validate_persisted_config_values defaults || {
        _error "E900" "Default configuration contains invalid values: ${defaults_file}" 0
        return 1
    }

    # Construct the entire candidate first so a bad/missing defaults file
    # never partially replaces the active in-memory configuration.
    _copy_config_assoc defaults candidate
    candidate[termux_source]="${DEVILS_MINIOS_TERMUX_SOURCE}"
    candidate[android_version]="${DEVILS_MINIOS_ANDROID_VERSION}"
    candidate[architecture]="${DEVILS_MINIOS_ARCH}"
    _copy_config_assoc candidate DEVILS_MINIOS_CONFIG
    return 0
}

# _config_storage_paths_valid() revalidates fixed config targets immediately
# before they are read or mutated (§22.1 step 7). The private config directory
# itself must not be a symlink, and neither the active file nor its backup may
# be a symlink destination.
_config_storage_paths_valid() {
    [[ ! -L "${DEVILS_MINIOS_CONFIG_DIR}" ]] || {
        _error "E703" "Configuration directory must not be a symlink" 0
        return 1
    }
    validate_path "${DEVILS_MINIOS_CONFIG_DIR}" "${HOME}/.config" || {
        _error "$(_path_validation_error_code)" "Configuration directory failed path validation" 0
        return 1
    }
    [[ -d "${DEVILS_MINIOS_CONFIG_DIR}" ]] || {
        _error "E900" "Configuration directory is unavailable" 0
        return 1
    }
    validate_path "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        _error "$(_path_validation_error_code)" "Configuration file target failed path validation" 0
        return 1
    }
    _reject_symlink_destination "${DEVILS_MINIOS_CONFIG_FILE}" || {
        _error "E434" "Configuration file target must not be a symlink" 0
        return 1
    }
    validate_path "${DEVILS_MINIOS_CONFIG_BACKUP}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        _error "$(_path_validation_error_code)" "Configuration backup target failed path validation" 0
        return 1
    }
    _reject_symlink_destination "${DEVILS_MINIOS_CONFIG_BACKUP}" || {
        _error "E434" "Configuration backup target must not be a symlink" 0
        return 1
    }
    return 0
}

# _save_config_atomic_locked() requires the caller to hold the config mutex.
# It validates the complete staged document before atomically replacing config;
# every failure before the final rename leaves the active config untouched.
_save_config_atomic_locked() {
    local tmp_file=""
    local bak_tmp=""
    local key
    local resolved_tmp=""
    local resolved_backup=""
    local resolved_active=""

    _config_storage_paths_valid || return 1
    tmp_file="$(mktemp "${DEVILS_MINIOS_CONFIG_FILE}.tmp.XXXXXX")" || return 1
    if ! (
        for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}" "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
            printf '%s=%s\n' "${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}" || exit 1
        done
    ) > "${tmp_file}"; then
        rm -f -- "${tmp_file}"
        return 1
    fi
    chmod 600 "${tmp_file}" || { rm -f -- "${tmp_file}"; return 1; }
    validate_config "${tmp_file}" || { rm -f -- "${tmp_file}"; return 1; }

    if [[ -e "${DEVILS_MINIOS_CONFIG_FILE}" ]]; then
        bak_tmp="$(mktemp "${DEVILS_MINIOS_CONFIG_BACKUP}.tmp.XXXXXX")" || {
            rm -f -- "${tmp_file}"
            return 1
        }
        if ! cp -f -- "${DEVILS_MINIOS_CONFIG_FILE}" "${bak_tmp}"; then
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        fi
        chmod 600 "${bak_tmp}" || {
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        }
        validate_path "${bak_tmp}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        }
        resolved_backup="${DEVILS_MINIOS_PATH_RESOLVED:-${bak_tmp}}"
        validate_path "${DEVILS_MINIOS_CONFIG_BACKUP}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        }
        _reject_symlink_destination "${DEVILS_MINIOS_CONFIG_BACKUP}" || {
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        }
        resolved_active="${DEVILS_MINIOS_PATH_RESOLVED:-${DEVILS_MINIOS_CONFIG_BACKUP}}"
        if ! mv -f -- "${resolved_backup}" "${resolved_active}"; then
            rm -f -- "${tmp_file}" "${bak_tmp}"
            return 1
        fi
    fi

    # Step 7: repeat validation immediately before the active-file rename.
    validate_path "${tmp_file}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        rm -f -- "${tmp_file}"
        return 1
    }
    resolved_tmp="${DEVILS_MINIOS_PATH_RESOLVED:-${tmp_file}}"
    _config_storage_paths_valid || { rm -f -- "${tmp_file}"; return 1; }
    # _config_storage_paths_valid() checks several paths, so resolve the
    # active destination one more time immediately before the mutating rename.
    validate_path "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        rm -f -- "${tmp_file}"
        return 1
    }
    _reject_symlink_destination "${DEVILS_MINIOS_CONFIG_FILE}" || {
        rm -f -- "${tmp_file}"
        return 1
    }
    resolved_active="${DEVILS_MINIOS_PATH_RESOLVED:-${DEVILS_MINIOS_CONFIG_FILE}}"
    if ! mv -f -- "${resolved_tmp}" "${resolved_active}"; then
        rm -f -- "${tmp_file}"
        return 1
    fi
    return 0
}

# Contract: save_config(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
save_config() {
    [[ ! -L "${DEVILS_MINIOS_CONFIG_DIR}" ]] || {
        _error "E703" "Configuration directory must not be a symlink" 0
        return 1
    }
    mkdir -p "${HOME}/.config" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        _error "E900" "Cannot create configuration directory" 0
        return 1
    }
    _config_storage_paths_valid || return 1
    _refresh_runtime_facts || return 1

    local lock_file="${DEVILS_MINIOS_CONFIG_DIR}/.config.lock"
    local lock_dir="${DEVILS_MINIOS_CONFIG_FILE}.lockdir"
    local rc=0

    if command -v flock >/dev/null 2>&1; then
        # flock is the primary mutex. Append-open avoids truncating a lock file;
        # the descriptor stays open for the entire atomic write transaction.
        (
            umask 077
            _config_storage_paths_valid || exit 1
            [[ ! -L "${lock_file}" ]] || exit 1
            validate_path "${lock_file}" "${DEVILS_MINIOS_CONFIG_DIR}" || exit 1
            exec 200>>"${lock_file}" || exit 1
            flock -x 200 || exit 1
            _save_config_atomic_locked
        ) || rc=$?
    else
        # Termux fallback when flock is unavailable: atomic mkdir mutex with
        # bounded retries. Never write unlocked if the lock cannot be acquired.
        [[ ! -L "${lock_dir}" ]] || {
            _error "E900" "Configuration lock path is a symlink" 0
            return 1
        }
        validate_path "${lock_dir}" "${DEVILS_MINIOS_CONFIG_DIR}" || {
            _error "$(_path_validation_error_code)" "Configuration lock failed path validation" 0
            return 1
        }
        local attempts=0
        while ! mkdir "${lock_dir}" 2>/dev/null; do
            attempts=$((attempts + 1))
            if [[ ${attempts} -ge 20 ]]; then
                _error "E900" "Timed out acquiring configuration write lock" 0
                return 1
            fi
            sleep 0.05
        done
        _save_config_atomic_locked || rc=$?
        rmdir "${lock_dir}" 2>/dev/null || {
            [[ ${rc} -ne 0 ]] || rc=1
        }
    fi

    if [[ ${rc} -ne 0 ]]; then
        _error "E900" "Configuration write failed; active configuration file was preserved" 0
        return 1
    fi
    return 0
}

# Contract: validate_config(candidate_path); returns: 0 when valid, non-zero when rejected; side effects: none.
validate_config() {
    local candidate_path="${1:-${DEVILS_MINIOS_CONFIG_FILE}}"
    local -a allowed_keys=(
        "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"
        "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"
    )
    local -A parsed=()
    local allowed_flat="${allowed_keys[*]}"
    _parse_strict_kv_file "${candidate_path}" parsed "${allowed_flat}" || return 1
    _validate_persisted_config_values parsed || return 1
    local key
    for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}" "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        [[ -n "${parsed[${key}]+x}" ]] || {
            _warn "E411" "Missing required configuration key: ${key}"
            return 1
        }
    done
    return 0
}

# Contract: load_config(none); returns: 0 on success, non-zero on failure; side effects: loads or restores runtime/config/state data.
load_config() {
    DEVILS_MINIOS_CONFIG_LOAD_FAILURE_REASON="configuration integrity/recovery/persistence failed"
    [[ ! -L "${DEVILS_MINIOS_CONFIG_DIR}" ]] || {
        _error "E703" "Configuration directory must not be a symlink" 0
        return 1
    }
    mkdir -p "${HOME}/.config" "${DEVILS_MINIOS_CONFIG_DIR}" || {
        _error "E900" "Cannot create configuration directory" 0
        return 1
    }
    _config_storage_paths_valid || return 1

    # §48.2 E412 / §26.1 CFG-TAMPER is an installation-integrity signal.
    # It has priority over ordinary missing/invalid-config self-healing.
    if _installed_manifest_tampered; then
        # shellcheck disable=SC2034
        DEVILS_MINIOS_CONFIG_LOAD_FAILURE_REASON="configuration/installation tamper detected (E412)"
        _error "E412" "Installed manifest failed integrity verification (${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS); configuration recovery is forbidden" 0
        return 1
    fi
    # shellcheck disable=SC2034
    local -A candidate=() # Passed by name to parser/validator helpers.
    local allowed_flat="${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]} ${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[*]}"

    if [[ -e "${DEVILS_MINIOS_CONFIG_FILE}" ]]; then
        if _parse_strict_kv_file "${DEVILS_MINIOS_CONFIG_FILE}" candidate "${allowed_flat}" && _validate_persisted_config_values candidate; then
            _copy_config_assoc candidate DEVILS_MINIOS_CONFIG
            _refresh_runtime_facts
            if ! save_config || ! validate_config; then
                _error "E900" "Could not persist/validate refreshed configuration" 0
                return 1
            fi
            DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
            _debug "Configuration loaded"
            return 0
        fi
        _warn "E411" "Active configuration is invalid (bad value, unknown key, or forbidden runtime key); restoring defaults: ${DEVILS_MINIOS_CONFIG_FILE}"
    else
        _warn "E410" "Configuration file missing; regenerating from defaults: ${DEVILS_MINIOS_CONFIG_FILE}"
    fi

    # §17.5/§26.1: defaults.conf is the authoritative source, not duplicated
    # Bash literals. Regeneration is only successful after persisted write and
    # full post-write validation succeed.
    if ! load_default_config || ! _refresh_runtime_facts || ! save_config || ! validate_config; then
        _error "E900" "Configuration recovery failed; entering Safe Mode is required" 0
        return 1
    fi
    DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
    return 0
}

# Contract: import_config(source_file); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
import_config() {
    local import_file="${1:-}"
    local key
    local allowed_flat="${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]}"
    local -A imported=()
    # This snapshot is read/written through the _copy_config_assoc nameref.
    # shellcheck disable=SC2034
    local -A old_config=()

    [[ -f "${import_file}" && -r "${import_file}" ]] || { _error "E411" "Import file not found or unreadable" 0; return 2; }
    _parse_strict_kv_file "${import_file}" imported "${allowed_flat}" || { _error "E411" "Import rejected by strict grammar validation" 0; return 2; }

    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}" "${DEVILS_MINIOS_RUNTIME_CONTEXT_KEYS[@]}"; do
        if [[ -n "${imported[${key}]+x}" ]]; then
            _error "E411" "Import contains forbidden runtime key: ${key}" 0
            return 2
        fi
    done
    for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
        [[ -n "${imported[${key}]+x}" ]] || { _error "E411" "Import is missing required key: ${key}" 0; return 2; }
    done
    _validate_persisted_config_values imported || { _error "E411" "Import contains invalid values" 0; return 2; }

    # Hold a rollback snapshot of the active in-memory configuration. The
    # candidate becomes active only if the atomic disk replacement succeeds.
    _copy_config_assoc DEVILS_MINIOS_CONFIG old_config
    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        imported["${key}"]="${DEVILS_MINIOS_CONFIG[${key}]:-unknown}"
    done
    _copy_config_assoc imported DEVILS_MINIOS_CONFIG
    if ! save_config || ! validate_config; then
        _copy_config_assoc old_config DEVILS_MINIOS_CONFIG
        _error "E900" "Configuration import could not be committed; active configuration was preserved" 0
        return 1
    fi
    # DEVILS_MINIOS_LOG_LEVEL is declared -g in modules/core.sh and consumed
    # by core/core_logging.sh (both dynamically sourced).
    # shellcheck disable=SC2034
    DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
    return 0
}
