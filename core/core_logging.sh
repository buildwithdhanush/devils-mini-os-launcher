#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_logging.sh
# Split from modules/core.sh (PRD file-size limit, §-referenced sections
# preserved verbatim). Sourced by modules/core.sh (loaded from core/); not a standalone
# feature module and not part of DEVILS_MINIOS_FEATURE_MODULES.
# PRD Reference: §24, §48

# ============================================================================
# LOGGING (§24) — sole writer/rotation owner
# ============================================================================

_write_log_entry() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local log_file="${DEVILS_MINIOS_LOG_DIR}/launcher.log"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[${timestamp}] [${level}] ${message}"

    [[ -d "${DEVILS_MINIOS_LOG_DIR}" ]] || return 0

    if _has_command flock; then
        (
            flock -x 200
            printf '%s\n' "${entry}" >> "${log_file}"
        ) 200>"${log_file}.lock"
    else
        local lock_dir="${DEVILS_MINIOS_LOG_DIR}/.launcher.lock"
        local attempts=0
        while ! mkdir "${lock_dir}" 2>/dev/null; do
            attempts=$((attempts + 1))
            if [[ ${attempts} -ge 20 ]]; then
                printf '%s\n' "${entry}" >> "${log_file}"
                return 0
            fi
            sleep 0.05
        done
        local tmp_file="${DEVILS_MINIOS_LOG_DIR}/launcher.tmp.$$"
        printf '%s\n' "${entry}" > "${tmp_file}"
        cat "${log_file}" "${tmp_file}" > "${log_file}.new.$$" 2>/dev/null || true
        mv -f "${log_file}.new.$$" "${log_file}"
        rm -f "${tmp_file}"
        rmdir "${lock_dir}"
    fi
}

# Contract: write_log_file(level, message); returns: 0 on success, non-zero on failure; side effects: mutates launcher logs/diagnostic state.
write_log_file() {
    local level="${1:-INFO}"
    local message="${2:-}"
    case "${level}" in
        ERROR|WARN|INFO|DEBUG) ;;
        *) level="INFO" ;;
    esac

    local order=0
    case "${DEVILS_MINIOS_LOG_LEVEL}" in
        ERROR) order=0 ;;
        WARN) order=1 ;;
        INFO) order=2 ;;
        DEBUG) order=3 ;;
        *) order=2 ;;
    esac
    local threshold=2
    case "${level}" in
        ERROR) threshold=0 ;;
        WARN) threshold=1 ;;
        INFO) threshold=2 ;;
        DEBUG) threshold=3 ;;
    esac
    [[ ${threshold} -gt ${order} ]] && return 0

    _write_log_entry "${level}" "${message}"
}

_purge_log_file_by_age() {
    local log_file="$1"
    local cutoff
    cutoff="$(date -d "${DEVILS_MINIOS_LOG_RETENTION_DAYS} days ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    [[ -n "${cutoff}" ]] || return 0
    [[ -f "${log_file}" ]] || return 0

    local tmp_file="${log_file}.purge.$$"
    local line ts
    while IFS= read -r line || [[ -n "${line}" ]]; do
        ts="${line:1:19}"
        if [[ "${ts}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ && "${ts}" < "${cutoff}" ]]; then
            continue
        fi
        printf '%s\n' "${line}"
    done < "${log_file}" > "${tmp_file}"
    mv -f "${tmp_file}" "${log_file}"
}

# Contract: rotate_and_purge_logs(none); returns: 0 on success, non-zero on failure; side effects: mutates launcher logs/diagnostic state.
rotate_and_purge_logs() {
    local log_file="${DEVILS_MINIOS_LOG_DIR}/launcher.log"
    [[ -d "${DEVILS_MINIOS_LOG_DIR}" ]] || return 0

    local size=0
    if [[ -f "${log_file}" ]]; then
        size="$(wc -c < "${log_file}" 2>/dev/null || printf '0')"
        [[ "${size}" =~ ^[0-9]+$ ]] || size=0
    fi

    if [[ ${size} -gt ${DEVILS_MINIOS_LOG_MAX_BYTES} ]]; then
        local i
        for ((i=DEVILS_MINIOS_LOG_ROTATIONS; i>=2; i--)); do
            if [[ -f "${log_file}.$((i-1))" ]]; then
                mv -f "${log_file}.$((i-1))" "${log_file}.${i}"
            fi
        done
        if [[ -f "${log_file}" ]]; then
            mv -f "${log_file}" "${log_file}.1"
        fi
        : > "${log_file}"
    fi

    local candidate
    for candidate in "${log_file}" "${log_file}.1" "${log_file}.2" "${log_file}.3" "${log_file}.4"; do
        _purge_log_file_by_age "${candidate}"
    done
    return 0
}

# sanitize_log_for_upload(source_file[, dest_file]) - §13.1/§49. Strips
# paths, usernames, and IP-like strings from a log before manual copy-paste
# to a GitHub issue. No network or telemetry is involved: this only produces
# a redacted copy for the user to paste themselves. Reads `source_file`
# (defaults to the active log file); writes to `dest_file` if given,
# otherwise prints the sanitized text to stdout. Never fatal.
# Contract: sanitize_log_for_upload(source_file, dest_file); returns: 0 on success, non-zero on failure; side effects: may mutate launcher state according to the function purpose.
sanitize_log_for_upload() {
    local source_file="${1:-$(get_log_file)}"
    local dest_file="${2:-}"

    if [[ ! -f "${source_file}" ]]; then
        _warn "E900" "sanitize_log_for_upload: no such file: ${source_file}"
        return 1
    fi

    local home_dir="${HOME:-}"
    local home_user
    home_user="$(basename "${home_dir:-/unknown}" 2>/dev/null || printf 'unknown')"

    # Order matters: redact the full HOME path before the bare username, and
    # redact known Termux path prefixes before generic ones, so a shorter
    # replacement never masks a longer one.
    local -a sed_args=()
    [[ -n "${home_dir}" ]] && sed_args+=(-e "s#${home_dir//\#/\\#}#<HOME>#g")
    sed_args+=(-e 's#/data/data/com\.termux/files/home[^[:space:]"'\'']*#<HOME_PATH>#g')
    sed_args+=(-e 's#/data/data/com\.termux/files/usr[^[:space:]"'\'']*#<PREFIX_PATH>#g')
    [[ -n "${home_user}" && "${home_user}" != "/" ]] && sed_args+=(-e "s#${home_user//\#/\\#}#<USER>#g")
    sed_args+=(-e 's#([0-9]{1,3}\.){3}[0-9]{1,3}#<IP>#g')
    sed_args+=(-e 's#([0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}#<IP>#g')

    local sed_result
    sed_result="$(sed -E "${sed_args[@]}" "${source_file}" 2>/dev/null)"

    if [[ -n "${dest_file}" ]]; then
        printf '%s\n' "${sed_result}" > "${dest_file}" 2>/dev/null || {
            _warn "E900" "sanitize_log_for_upload: could not write ${dest_file}"
            return 1
        }
    else
        printf '%s\n' "${sed_result}"
    fi
    return 0
}

# ============================================================================
# ERROR HANDLING (§48)
# ============================================================================

_error() {
    # §48.2 E900: generic/unclassified-failure fallback. Only applies when a
    # call site omits its own code entirely; every call site that already
    # passes a specific registered code (the overwhelming majority) is
    # completely unaffected by this default. Previously defaulted to the
    # unregistered "E999", which is not a §48.2 code at all.
    local code="${1:-E900}"
    local message="${2:-Unknown error}"
    local exit_status="${3:-0}"
    write_log_file "ERROR" "[${code}] ${message}"
    printf 'ERROR [%s]: %s\n' "${code}" "${message}" >&2
    if [[ "${exit_status}" != "0" ]]; then
        exit "${exit_status}"
    fi
    return 1
}

_warn() {
    local code="${1:-}"
    local message="${2:-Unknown warning}"
    if [[ -n "${code}" ]]; then
        write_log_file "WARN" "[${code}] ${message}"
        printf 'WARNING [%s]: %s\n' "${code}" "${message}" >&2
    else
        write_log_file "WARN" "${message}"
        printf 'WARNING: %s\n' "${message}" >&2
    fi
}

_info() {
    write_log_file "INFO" "$1"
}

_debug() {
    if [[ "${DEVILS_MINIOS_DEBUG_MODE}" == true ]]; then
        write_log_file "DEBUG" "$1"
    fi
}

# Contract: error_handler(code, message); returns: 0 on success, non-zero on failure; side effects: mutates launcher logs/diagnostic state.
error_handler() {
    # §48.2 E900 fallback; see _error() above for rationale.
    local code="${1:-E900}"
    local message="${2:-Unknown error}"
    write_log_file "ERROR" "[${code}] ${message}"
    printf 'ERROR [%s]: %s\n' "${code}" "${message}" >&2
    return 1
}

