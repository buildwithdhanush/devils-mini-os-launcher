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
    # DEVILS_MINIOS_CONFIG is first declared -gA in modules/core.sh; repeating
    # the attributes here lets ShellCheck (which analyzes this file standalone)
    # see the literal [key]= subscripts as associative keys, not variables.
    declare -gA DEVILS_MINIOS_CONFIG=(
        [config_version]="${DEVILS_MINIOS_CONFIG_VERSION}"
        [theme]="dracula"
        [banner]="devil"
        [banner_animation]="false"
        [auto_launch]="false"
        [health_check_interval]="1800"
        [log_level]="INFO"
        [check_updates]="false"
        [language]="en"
        [network_timeout]="30"
        [network_retries]="3"
        [termux_source]="${DEVILS_MINIOS_TERMUX_SOURCE}"
        [android_version]="${DEVILS_MINIOS_ANDROID_VERSION}"
        [architecture]="${DEVILS_MINIOS_ARCH}"
    )
}

# Contract: save_config(none); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
save_config() {
    mkdir -p "${DEVILS_MINIOS_CONFIG_DIR}"
    _refresh_runtime_facts
    local tmp_file="${DEVILS_MINIOS_CONFIG_FILE}.tmp.$$"
    local key
    {
        for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}" "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
            printf '%s=%s\n' "${key}" "${DEVILS_MINIOS_CONFIG[${key}]:-}"
        done
    } > "${tmp_file}"
    if [[ -f "${DEVILS_MINIOS_CONFIG_FILE}" ]]; then
        cp -f "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_CONFIG_BACKUP}"
    fi
    mv -f "${tmp_file}" "${DEVILS_MINIOS_CONFIG_FILE}"
    chmod 600 "${DEVILS_MINIOS_CONFIG_FILE}" 2>/dev/null || true
}

# Contract: validate_config(candidate_path); returns: 0 when valid, non-zero when rejected; side effects: none.
validate_config() {
    local candidate="${1:-${DEVILS_MINIOS_CONFIG_FILE}}"
    local -a allowed_keys=(
        "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"
        "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"
    )
    local -A parsed=()
    local allowed_flat="${allowed_keys[*]}"
    _parse_strict_kv_file "${candidate}" parsed "${allowed_flat}" || return 1
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
    mkdir -p "${DEVILS_MINIOS_CONFIG_DIR}"

    # §48.2 E412 / §26.1 CFG-TAMPER: the installed-manifest integrity
    # cross-check is independent of, and takes priority over, ordinary
    # missing/invalid-content handling below. Per §26.1, CFG-TAMPER is
    # "Auto-recover? NO" - it must not fall through to the CFG-MISSING/
    # CFG-BAD-VALUE self-heal path below under any circumstance, and the
    # caller (core_init()) is responsible for routing this return status
    # to Safe Mode entry (§26.1: "Enter SAFE_MODE immediately").
    if _installed_manifest_tampered; then
        _error "E412" "Installed manifest failed integrity verification (${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS) while loading configuration; configuration/installation tamper suspected" 0
        return 1
    fi

    local -A candidate=()
    local allowed_flat="${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]} ${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[*]}"

    if [[ -e "${DEVILS_MINIOS_CONFIG_FILE}" ]]; then
        if _parse_strict_kv_file "${DEVILS_MINIOS_CONFIG_FILE}" candidate "${allowed_flat}" && _validate_persisted_config_values candidate; then
            _copy_config_assoc candidate DEVILS_MINIOS_CONFIG
            _refresh_runtime_facts
            save_config
            DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
            _debug "Configuration loaded"
            return 0
        fi
        # §48.2 E411 / §26.1 CFG-BAD-VALUE / CFG-UNKNOWN-KEY: a known key
        # with an invalid value, an unknown key, or a runtime_context key
        # present in the file. Recovery is a whole-file restore from
        # defaults.conf merged with freshly detected persisted_runtime_facts;
        # per §26.1 "key-by-key partial repair is not attempted, because no
        # partial-config backup exists (only state.bak exists, for state,
        # §26.4)" - so, unlike state, no backup file is ever consulted here.
        _warn "E411" "Active configuration is invalid (bad value, unknown key, or forbidden runtime key); restoring defaults: ${DEVILS_MINIOS_CONFIG_FILE}"
    else
        # §48.2 E410 / §26.1 CFG-MISSING: no config file at the canonical
        # path. Recovery is direct regeneration from defaults.conf (§17.5) -
        # again, no backup is consulted (none exists for config).
        _warn "E410" "Configuration file missing; regenerating from defaults: ${DEVILS_MINIOS_CONFIG_FILE}"
    fi

    load_default_config
    _refresh_runtime_facts
    save_config
    DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
    return 0
}

# Contract: import_config(source_file); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
import_config() {
    local import_file="$1"
    local -A imported=()
    local -A old_facts=()
    local key
    local allowed_flat="${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[*]}"

    [[ -f "${import_file}" ]] || { _error "E411" "Import file not found" 0; return 2; }
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

    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        old_facts["${key}"]="${DEVILS_MINIOS_CONFIG[${key}]:-unknown}"
    done
    _copy_config_assoc imported DEVILS_MINIOS_CONFIG
    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        DEVILS_MINIOS_CONFIG["${key}"]="${old_facts[${key}]}"
    done
    save_config
    # DEVILS_MINIOS_LOG_LEVEL is declared -g in modules/core.sh and consumed
    # by core/core_logging.sh (both dynamically sourced); this is the last
    # write to it in this file with no subsequent read visible to
    # ShellCheck's per-file analysis, hence SC2034.
    # shellcheck disable=SC2034
    DEVILS_MINIOS_LOG_LEVEL="${DEVILS_MINIOS_CONFIG[log_level]}"
    return 0
}

