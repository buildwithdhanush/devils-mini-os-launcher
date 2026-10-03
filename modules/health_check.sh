#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/health_check.sh
# PRD Reference: §13.8, §25.3
# Public: health_check_menu()
# No background daemon; uses the diagnostic result cache.

_health_check_cache_file() { printf '%s/health_cache.json' "${DEVILS_MINIOS_CACHE_DIR}"; }

_health_check_cache_fresh() {
    local cache_file interval now mtime
    cache_file="$(_health_check_cache_file)"
    [[ -f "${cache_file}" ]] || return 1
    interval="${DEVILS_MINIOS_CONFIG[health_check_interval]:-1800}"
    now="$(date +%s)"
    mtime="$(stat -c '%Y' "${cache_file}" 2>/dev/null || stat -f '%m' "${cache_file}" 2>/dev/null || printf 0)"
    [[ $(( now - mtime )) -lt ${interval} ]]
}

_health_check_run() {
    local storage_line battery_line proot_line
    storage_line="$(df -h "${HOME}" 2>/dev/null | awk 'NR==2{print $4" free of "$2}')"
    if _has_command termux-battery-status; then
        battery_line="$(_get_battery_percent 2>/dev/null || printf 'unknown')%"
    else
        battery_line="Unavailable (Termux:API not installed)"
    fi
    if _has_command proot-distro; then
        proot_line="Available"
    else
        proot_line="Unavailable"
    fi
    # §25.3: the fresh run atomically replaces the cache — write to a
    # same-directory temp file and rename over the cache so a reader never
    # observes a partial cache and a failed run never corrupts the previous
    # cache contents.
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}" || return 1
    local _cache_file _tmp_file
    _cache_file="$(_health_check_cache_file)"
    _tmp_file="${_cache_file}.tmp.$$"
    {
        printf '{\n'
        printf '  "checked_at": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf '  "platform": "%s",\n' "${DEVILS_MINIOS_PLATFORM}"
        printf '  "android_version": "%s",\n' "${DEVILS_MINIOS_ANDROID_VERSION}"
        printf '  "architecture": "%s",\n' "${DEVILS_MINIOS_ARCH}"
        printf '  "storage": "%s",\n' "${storage_line}"
        printf '  "battery": "%s",\n' "${battery_line}"
        printf '  "proot_distro": "%s",\n' "${proot_line}"
        printf '  "config_valid": true\n'
        printf '}\n'
    } > "${_tmp_file}" || { rm -f "${_tmp_file}"; return 1; }
    mv -f "${_tmp_file}" "${_cache_file}" || { rm -f "${_tmp_file}"; return 1; }
}

_health_check_show() {
    local force="${1:-false}"
    if [[ "${force}" == true ]] || ! _health_check_cache_fresh; then
        _health_check_run
    else
        printf '(cached result; still fresh per health_check_interval)\n'
    fi
    cat "$(_health_check_cache_file)" 2>/dev/null
}

# Contract: health_check_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
health_check_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Health Check =="
        printf '%s\n' "1) Run diagnostics (use cache if fresh)"
        printf '%s\n' "2) Force fresh diagnostics"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _health_check_show false; _confirm "Continue" || true ;;
            2) _health_check_show true; _confirm "Continue" || true ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
