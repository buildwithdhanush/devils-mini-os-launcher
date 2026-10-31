#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/log_viewer.sh
# PRD Reference: §13.9, §24
# Public: log_viewer_menu()
# Boundary: this module NEVER rotates, truncates, or deletes log files.
# "Clear logs" and "Export archive" mutation is delegated to core.sh.

_log_viewer_view() {
    local n
    n="$(_prompt_default 'Number of recent lines' '50')"
    _is_int "${n}" || n=50
    tail -n "${n}" "$(get_log_file)" 2>/dev/null || printf 'No log entries yet.\n'
}

_log_viewer_filter() {
    local level
    level="$(_prompt_default 'Filter by level (ERROR/WARN/INFO/DEBUG)' 'ERROR')"
    grep -F "[${level}]" "$(get_log_file)" 2>/dev/null | tail -n 100
}

_log_viewer_search() {
    local term
    term="$(_prompt_default 'Search term' '')"
    grep -F -- "${term}" "$(get_log_file)" 2>/dev/null | tail -n 100
}

_log_viewer_tail_live() {
    printf 'Live tail - press Ctrl+C to stop and return.\n'
    # A brief, bounded live tail; SIGINT is handled by the top-level trap.
    tail -n 20 -f "$(get_log_file)" 2>/dev/null &
    local pid=$!
    sleep 5
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
}

_log_viewer_export() {
    local dest
    dest="$(_prompt_default 'Export archive to path' "${HOME}/devils-minios-logs-$(date +%Y%m%d-%H%M%S).tar.gz")"
    validate_path "${dest}" || { _error "$(_path_validation_error_code)" "Invalid destination path" 0; return 2; }
    execute_structured tar "-czf" "${dest}" "-C" "${DEVILS_MINIOS_LOG_DIR}" "."
    _info "Log archive exported to ${dest}"
}

_log_viewer_clear() {
    _confirm "Clear all logs (delegated to core.sh, the sole log writer)" || return 0
    clear_logs
}

# §49: redact paths/usernames/IP-like strings before the user pastes a log
# into a GitHub issue. Sanitization itself is centralized in core.sh
# (sanitize_log_for_upload, §13.1); this menu action only prompts for a
# destination and delegates to it - it never writes logs itself.
_log_viewer_export_sanitized() {
    local dest
    dest="$(_prompt_default 'Sanitized log destination' "${HOME}/devils-minios-log-sanitized-$(date +%Y%m%d-%H%M%S).txt")"
    validate_path "${dest}" || { _error "$(_path_validation_error_code)" "Invalid destination path" 0; return 2; }
    if sanitize_log_for_upload "$(get_log_file)" "${dest}"; then
        _info "Sanitized log written to ${dest} (safe to paste into a GitHub issue)"
    else
        _error "E900" "Failed to write sanitized log" 0
    fi
}

# Contract: log_viewer_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
log_viewer_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Log Viewer (read-only) =="
        printf '%s\n' "1) View recent entries"
        printf '%s\n' "2) Filter by level"
        printf '%s\n' "3) Search"
        printf '%s\n' "4) Live tail (5s)"
        printf '%s\n' "5) Export archive"
        printf '%s\n' "6) Export sanitized log (for GitHub issue)"
        printf '%s\n' "7) Clear logs (delegates to core.sh)"
        printf '%s\n' "0) Exit"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _log_viewer_view; _pause "Press Enter to return to the menu" ;;
            2) _log_viewer_filter; _pause "Press Enter to return to the menu" ;;
            3) _log_viewer_search; _pause "Press Enter to return to the menu" ;;
            4) _log_viewer_tail_live ;;
            5) _log_viewer_export ;;
            6) _log_viewer_export_sanitized; _pause "Press Enter to return to the menu" ;;
            7) _log_viewer_clear ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
