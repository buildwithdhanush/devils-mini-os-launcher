#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/system_tools.sh
# PRD Reference: §13.11, §23.4
# Public: system_tools_menu()
# Dangerous process operations require explicit confirmation; never uses
# unsafe blanket kill commands without controlled targeting.

_system_tools_backup() {
    local dest
    dest="$(_prompt_default 'Backup destination' "${HOME}/devils-minios-backup-$(date +%Y%m%d-%H%M%S).tar.gz")"
    validate_path "${dest}" || { _error "$(_path_validation_error_code)" "Invalid destination path" 0; return 2; }
    execute_structured tar "-czf" "${dest}" "-C" "${DEVILS_MINIOS_CONFIG_DIR}" "config" "state"
    _info "Backup written to ${dest}"
}

_system_tools_restore() {
    local src
    src="$(_prompt_default 'Backup archive to restore from' '')"
    validate_path "${src}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    [[ -f "${src}" ]] || { _error "E900" "Not a file: ${src}" 0; return 2; }
    _confirm "Restore configuration and state from '${src}' (overwrites current)" || return 0
    execute_structured tar "-xzf" "${src}" "-C" "${DEVILS_MINIOS_CONFIG_DIR}"
    load_config
    load_state
    _info "Restore complete from ${src}"
}

_system_tools_process_list() {
    ps -o pid,pcpu,pmem,comm 2>/dev/null | sed -n '1,60p'
}

_system_tools_kill_process() {
    local pid
    pid="$(_prompt_default 'PID to terminate' '')"
    _is_int "${pid}" || { _error "E900" "PID must be numeric" 0; return 2; }
    [[ "${pid}" == "$$" || "${pid}" == "1" ]] && { _error "E900" "Refusing to target this shell or PID 1" 0; return 2; }
    ps -p "${pid}" >/dev/null 2>&1 || { _error "E900" "No such process: ${pid}" 0; return 2; }
    _confirm "Send SIGTERM to PID ${pid}" || return 0
    execute_structured kill "-TERM" "${pid}" || _warn "" "Failed to terminate PID ${pid} (permission denied or already exited)"
}

_system_tools_maintenance() {
    _confirm "Clear diagnostic cache (${DEVILS_MINIOS_CACHE_DIR})" || return 0
    local cache_dir="${DEVILS_MINIOS_CACHE_DIR}" entry
    validate_path "${cache_dir}" "${HOME}/.cache" || { _error "$(_path_validation_error_code)" "Invalid cache directory" 0; return 2; }
    [[ -d "${cache_dir}" && ! -L "${cache_dir}" ]] || { _error "E703" "Cache directory is invalid or symlinked" 0; return 2; }
    shopt -s nullglob dotglob
    local -a entries=("${cache_dir}"/*)
    shopt -u dotglob nullglob
    for entry in "${entries[@]}"; do
        validate_path "${entry}" "${cache_dir}" || { _error "$(_path_validation_error_code)" "Invalid cache entry" 0; return 2; }
        # Revalidate immediately before mutation (§22.1 step 7). A symlink
        # is removed as an object, never recursively followed.
        validate_path "${entry}" "${cache_dir}" || { _error "$(_path_validation_error_code)" "Cache entry changed before deletion" 0; return 2; }
        if [[ -L "${entry}" ]]; then
            execute_structured rm "-f" "${entry}" || return 1
        else
            execute_structured rm "-rf" "${entry}" || return 1
        fi
    done
    _info "Cache cleared"
}

# Contract: system_tools_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
system_tools_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== System Tools =="
        printf '%s\n' "1) Backup config + state"
        printf '%s\n' "2) Restore config + state"
        printf '%s\n' "3) List processes"
        printf '%s\n' "4) Terminate a process (confirmed, targeted)"
        printf '%s\n' "5) Maintenance: clear cache"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _system_tools_backup ;;
            2) _system_tools_restore ;;
            3) _system_tools_process_list; _confirm "Continue" || true ;;
            4) _system_tools_kill_process ;;
            5) _system_tools_maintenance ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
