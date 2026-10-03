#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_catalog.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# Covers data catalog helpers and command contracts.
# PRD Reference: §18, §18.2, §18.3, §18.4, §23.2, §23.3

# ============================================================================
# DATA CATALOG HELPERS (§18)
# ============================================================================

# Contract: data_file_path(name); returns: value/path or non-zero on invalid input; side effects: none.
data_file_path() {
    local name="$1"
    case "${name}" in
        proot_distros.db|desktops.db|proot_apps.db|termux_apps.db|defaults.conf)
            printf '%s/data/%s' "${DEVILS_MINIOS_INSTALL_DIR}" "${name}"
            ;;
        *)
            _error "E900" "Unknown data file requested: ${name}" 0
            return 2
            ;;
    esac
}

_split_pipe_line() {
    local line="$1"
    DEVILS_MINIOS_RECORD_FIELDS=()
    # Use IFS-based split (no process substitution — portable under nested bash -s)
    local IFS='|'
    # shellcheck disable=SC2206
    local -a parts=(${line})
    local field
    for field in "${parts[@]}"; do
        DEVILS_MINIOS_RECORD_FIELDS+=("${field}")
    done
}

_validate_architecture_field() {
    local value="${1:-}"
    if [[ "${value}" == "all" ]]; then
        return 0
    fi
    local arch
    local -a parts=()
    local IFS=','
    # shellcheck disable=SC2206
    parts=(${value})
    [[ ${#parts[@]} -gt 0 ]] || return 1
    for arch in "${parts[@]}"; do
        _is_valid_key "${arch}" "${DEVILS_MINIOS_SUPPORTED_ARCHS[@]}" || return 1
    done
    return 0
}

_validate_desktop_record() {
    local -a f=("$@")
    [[ ${#f[@]} -eq 7 ]] || return 1
    _is_valid_key "${f[0]}" "${DEVILS_MINIOS_ALLOWED_DESKTOPS[@]}" || return 1
    [[ -n "${f[1]}" && "${f[1]}" != *"|"* ]] || return 1
    [[ -n "${f[2]}" && "${f[2]}" != *"|"* ]] || return 1
    local -a valid_startup_binaries=("startxfce4" "startlxqt" "startlxde" "mate-session" "i3" "openbox-session" "startfluxbox" "jwm")
    _is_valid_key "${f[3]}" "${valid_startup_binaries[@]}" || return 1
    local token
    if [[ "${f[4]}" != "-" ]]; then
        local -a args=()
        local IFS=','
        # shellcheck disable=SC2206
        args=(${f[4]})
        [[ ${#args[@]} -gt 0 ]] || return 1
        for token in "${args[@]}"; do
            [[ "${token}" =~ ^[A-Za-z0-9_.=-]{1,32}$ ]] || return 1
        done
    fi
    _is_bool "${f[5]}" || return 1
    _is_int "${f[6]}" || return 1
    return 0
}

_validate_distro_record() {
    local -a f=("$@")
    [[ ${#f[@]} -eq 7 ]] || return 1
    [[ "${f[0]}" =~ ^[a-z0-9-]+$ ]] || return 1
    [[ -n "${f[1]}" && -n "${f[2]}" ]] || return 1
    _validate_architecture_field "${f[3]}" || return 1
    _is_int "${f[4]}" || return 1
    _is_valid_key "${f[5]}" supported disabled || return 1
    _is_valid_key "${f[6]}" apt pacman dnf apk xbps || return 1
    return 0
}

_validate_proot_app_record() {
    local -a f=("$@")
    [[ ${#f[@]} -eq 7 ]] || return 1
    [[ "${f[0]}" =~ ^[a-z0-9-]+$ && -n "${f[1]}" && -n "${f[3]}" ]] || return 1
    [[ ${#f[3]} -le 120 && "${f[3]}" != *"|"* ]] || return 1
    _is_valid_key "${f[2]}" dev-proot browser office graphics media communication security networking games system education science utilities || return 1
    [[ "${f[4]}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$ ]] || return 1
    _validate_architecture_field "${f[5]}" || return 1
    if [[ "${f[6]}" != "any" ]]; then
        local distro
        local -a dparts=()
        local IFS=','
        # shellcheck disable=SC2206
        dparts=(${f[6]})
        for distro in "${dparts[@]}"; do
            [[ "${distro}" =~ ^[a-z0-9-]+$ ]] || return 1
        done
    fi
    return 0
}

_validate_termux_app_record() {
    local -a f=("$@")
    [[ ${#f[@]} -eq 11 ]] || return 1
    [[ "${f[0]}" =~ ^[a-z0-9-]+$ && -n "${f[1]}" && -n "${f[3]}" ]] || return 1
    [[ ${#f[3]} -le 120 && "${f[3]}" != *"|"* ]] || return 1
    # DEVILS_MINIOS_TERMUX_APP_CATEGORIES is declared -a readonly in
    # termux_apps.sh, which is always sourced before this validator runs (its
    # only callers are termux_apps.sh's own loader and tests that source it
    # first); ShellCheck's single-file analysis of core.sh cannot see that.
    # shellcheck disable=SC2154
    _is_valid_key "${f[2]}" "${DEVILS_MINIOS_TERMUX_APP_CATEGORIES[@]}" || return 1
    _is_valid_key "${f[5]}" pkg github || return 1
    if [[ "${f[5]}" == "pkg" ]]; then
        [[ "${f[4]}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$ ]] || return 1
        [[ "${f[7]}" == "-" && "${f[8]}" == "-" && "${f[9]}" == "-" && "${f[10]}" == "-" ]] || return 1
    else
        [[ "${f[4]}" == "-" ]] || return 1
        [[ "${f[7]}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 1
        if [[ ! "${f[8]}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ && ! "${f[8]}" =~ ^[0-9a-f]{40}$ ]]; then
            return 1
        fi
        [[ -n "${f[9]}" && "${f[9]}" != "-" ]] || return 1
        [[ "${f[10]}" =~ ^[0-9a-f]{64}$ ]] || return 1
    fi
    return 0
}

# Contract: load_database(file, field_count, validator, strict); returns: 0 on success, non-zero on failure; side effects: loads or restores runtime/config/state data.
load_database() {
    local db_file="$1"
    local expected_fields="$2"
    local validator="${3:-}"
    local strict="${4:-false}"

    DEVILS_MINIOS_CATALOG=()
    DEVILS_MINIOS_CATALOG_TOTAL=0
    DEVILS_MINIOS_CATALOG_MALFORMED=0

    [[ -f "${db_file}" ]] || {
        _error "E900" "Database file not found: ${db_file}" 0
        return 1
    }

    local line_num=0 line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line_num=$((line_num + 1))
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        DEVILS_MINIOS_CATALOG_TOTAL=$((DEVILS_MINIOS_CATALOG_TOTAL + 1))
        _split_pipe_line "${line}"
        local malformed_reason=""
        if [[ ${#DEVILS_MINIOS_RECORD_FIELDS[@]} -ne ${expected_fields} ]]; then
            malformed_reason="expected ${expected_fields} fields, got ${#DEVILS_MINIOS_RECORD_FIELDS[@]}"
        else
            local field
            for field in "${DEVILS_MINIOS_RECORD_FIELDS[@]}"; do
                [[ -n "${field}" ]] || malformed_reason="empty field"
            done
            if [[ -z "${malformed_reason}" && -n "${validator}" ]]; then
                "${validator}" "${DEVILS_MINIOS_RECORD_FIELDS[@]}" || malformed_reason="schema validation failed"
            fi
        fi
        if [[ -n "${malformed_reason}" ]]; then
            DEVILS_MINIOS_CATALOG_MALFORMED=$((DEVILS_MINIOS_CATALOG_MALFORMED + 1))
            _warn "Malformed database record in ${db_file} line ${line_num}: ${malformed_reason}"
            continue
        fi
        DEVILS_MINIOS_CATALOG+=("${line}")
    done < "${db_file}"

    local threshold=$(( DEVILS_MINIOS_CATALOG_TOTAL * 5 / 100 ))
    [[ ${threshold} -eq 0 && ${DEVILS_MINIOS_CATALOG_TOTAL} -gt 0 ]] && threshold=0
    if [[ ${DEVILS_MINIOS_CATALOG_MALFORMED} -gt ${threshold} ]]; then
        _error "E900" "Database ${db_file} exceeds malformed-record tolerance (${DEVILS_MINIOS_CATALOG_MALFORMED}/${DEVILS_MINIOS_CATALOG_TOTAL}); entering safe degradation" 0
        DEVILS_MINIOS_CATALOG=()
        [[ "${strict}" == "true" ]] && return 1
    fi
    return 0
}

# Contract: find_catalog_record(file, key, value); returns: value/path or non-zero on invalid input; side effects: none.
find_catalog_record() {
    local record_id="$1"
    local -a fields=()
    local line
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        if [[ "${fields[0]}" == "${record_id}" ]]; then
            DEVILS_MINIOS_RECORD_FIELDS=("${fields[@]}")
            return 0
        fi
    done
    return 1
}

# ============================================================================
# COMMAND CONTRACTS (§18.2, §18.3, §18.4, §23.2, §23.3)
# ============================================================================

# Contract: get_distro_record(distro_id); returns: value/path or non-zero on invalid input; side effects: none.
get_distro_record() {
    local distro_id="$1"
    local db_file
    db_file="$(data_file_path proot_distros.db)"
    load_database "${db_file}" 7 _validate_distro_record true || return 1
    find_catalog_record "${distro_id}" && return 0
    local line fields proot_id
    for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
        _split_pipe_line "${line}"
        fields=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
        proot_id="${fields[2]}"
        if [[ "${proot_id}" == "${distro_id}" ]]; then
            DEVILS_MINIOS_RECORD_FIELDS=("${fields[@]}")
            return 0
        fi
    done
    return 1
}

# Contract: get_desktop_record(desktop_id); returns: value/path or non-zero on invalid input; side effects: none.
get_desktop_record() {
    local desktop_name="$1"
    local db_file
    db_file="$(data_file_path desktops.db)"
    load_database "${db_file}" 7 _validate_desktop_record true || return 1
    find_catalog_record "${desktop_name}"
}

# Contract: install_proot_package(distro_id, package_id); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
install_proot_package() {
    local distro_id="$1"
    if [[ "${DEVILS_MINIOS_OFFLINE_MODE:-false}" == true ]]; then
        _warn "" "Proot package installation requires network access; --offline is set"
        return 1
    fi
    local package_id="$2"
    [[ "${package_id}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$ ]] || {
        _error "E900" "Invalid proot package identifier: ${package_id}" 0
        return 2
    }
    get_distro_record "${distro_id}" || {
        _error "E900" "Unknown proot distro: ${distro_id}" 0
        return 2
    }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local proot_id="${d[2]}"
    local package_manager="${d[6]}"
    local -a argv=()
    case "${package_manager}" in
        apt) argv=("install" "-y" "${package_id}") ;;
        pacman) argv=("-S" "--noconfirm" "${package_id}") ;;
        dnf) argv=("install" "-y" "${package_id}") ;;
        apk) argv=("add" "${package_id}") ;;
        xbps) argv=("-y" "${package_id}") ;;
        *) _error "E900" "Unsupported package manager: ${package_manager}" 0; return 2 ;;
    esac
    execute_structured "proot-distro" "login" "${proot_id}" "--" "${package_manager}" "${argv[@]}"
}

# Contract: run_desktop_startup(distro_id, startup_binary, startup_args); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
run_desktop_startup() {
    local distro_id="$1"
    local startup_binary="$2"
    local startup_args="${3:--}"
    local -a valid_binaries=("startxfce4" "startlxqt" "startlxde" "mate-session" "i3" "openbox-session" "startfluxbox" "jwm")
    _is_valid_key "${startup_binary}" "${valid_binaries[@]}" || {
        _error "E402" "Unknown startup binary: ${startup_binary}" 0
        return 2
    }

    get_distro_record "${distro_id}" || {
        _error "E900" "Unknown distro for desktop startup: ${distro_id}" 0
        return 2
    }
    local -a d=("${DEVILS_MINIOS_RECORD_FIELDS[@]}")
    local proot_id="${d[2]}"
    local rootfs="${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/${proot_id}"
    [[ -d "${rootfs}" ]] || {
        _error "E203" "Distro rootfs is not installed: ${proot_id}" 0
        return 3
    }

    local -a run_args=("${proot_id}" "--" "${startup_binary}")
    if [[ "${startup_args}" != "-" && -n "${startup_args}" ]]; then
        local token
        local -a arg_tokens=()
        local IFS=","
        # shellcheck disable=SC2206
        arg_tokens=(${startup_args})
        for token in "${arg_tokens[@]}"; do
            [[ "${token}" =~ ^[A-Za-z0-9_.=-]{1,32}$ ]] || {
                _error "E403" "Invalid desktop startup argument token: ${token}" 0
                return 2
            }
            run_args+=("${token}")
        done
    fi
    execute_structured "proot-distro" "login" "${run_args[@]}"
}

# Contract: install_github_artifact(repository, ref, artifact, sha256); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
install_github_artifact() {
    local repository="$1"
    if [[ "${DEVILS_MINIOS_OFFLINE_MODE:-false}" == true ]]; then
        _warn "" "GitHub artifact installation requires network access; --offline is set"
        return 1
    fi
    local ref="$2"
    local artifact="$3"
    local sha256="$4"

    [[ "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { _error "E900" "Invalid GitHub repository" 0; return 2; }
    if [[ ! "${ref}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ && ! "${ref}" =~ ^[0-9a-f]{40}$ ]]; then
        _error "E900" "GitHub ref must be a pinned tag or commit SHA" 0
        return 2
    fi
    [[ -n "${artifact}" && "${artifact}" != "-" ]] || { _error "E900" "GitHub artifact is required" 0; return 2; }
    [[ "${sha256}" =~ ^[0-9a-f]{64}$ ]] || { _error "E900" "GitHub artifact requires a 64-character lowercase SHA-256" 0; return 2; }

    local download_url="https://github.com/${repository}/releases/download/${ref}/${artifact}"
    local tmp_file="${DEVILS_MINIOS_TMP_DIR}/github-artifact.$$"
    mkdir -p "${DEVILS_MINIOS_TMP_DIR}"
    if ! execute_structured "curl" "-fL" "--fail" "--proto" "=" "https" "--tlsv1.2" "-o" "${tmp_file}" "${download_url}"; then
        rm -f "${tmp_file}"
        _error "E404" "GitHub artifact download failed" 0
        return 2
    fi
    # §23.3 step 5: checksum the downloaded (network-derived) artifact via
    # execute_structured(), not a direct subprocess call — this is exactly
    # the class of call §23.1 centralizes (a subprocess "derived from
    # catalog or configuration data": here, a file that arrived over the
    # network at a URL built from catalog fields).
    local sha256sum_out actual
    sha256sum_out="$(execute_structured sha256sum "" "${tmp_file}" 2>/dev/null)" || {
        rm -f "${tmp_file}"
        _error "E404" "Could not compute checksum of downloaded artifact" 0
        return 2
    }
    actual="${sha256sum_out%% *}"
    if [[ "${actual}" != "${sha256}" ]]; then
        rm -f "${tmp_file}"
        _error "E404" "Downloaded file failed verification; install aborted" 0
        return 2
    fi
    local target_dir="${DEVILS_MINIOS_INSTALL_DIR}/apps"
    mkdir -p "${target_dir}"
    mv -f "${tmp_file}" "${target_dir}/${artifact}"
    chmod 755 "${target_dir}/${artifact}" 2>/dev/null || true
    return 0
}

