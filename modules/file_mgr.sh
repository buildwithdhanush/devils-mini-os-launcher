#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/file_mgr.sh
# PRD Reference: §13.3, §22
# Public: file_mgr_menu()

_file_mgr_confirm_external() {
    local path="$1"
    if is_external_storage_path "${path}"; then
        _confirm "Path '${path}' is on external storage. Allow file access (execution remains blocked)" || return 1
    fi
    return 0
}

_file_mgr_browse() {
    local dir
    dir="$(_prompt_default 'Directory to browse' "${HOME}")"
    validate_path "${dir}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    _file_mgr_confirm_external "${dir}" || return 0
    [[ -d "${dir}" ]] || { _error "E900" "Not a directory: ${dir}" 0; return 2; }
    # ls -la output here is displayed directly to the user (permissions,
    # owner, size, date, name) and is never parsed or looped over by this
    # script, so SC2012's filename-safety concern (word-splitting output fed
    # back into logic) does not apply. `find` would lose the human-readable
    # long-format columns this view depends on.
    # shellcheck disable=SC2012
    ls -la -- "${dir}" 2>/dev/null | sed -n '1,200p'
}

_file_mgr_search() {
    local dir pattern
    dir="$(_prompt_default 'Search under directory' "${HOME}")"
    pattern="$(_prompt_default 'Filename pattern (glob)' '*')"
    validate_path "${dir}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    _file_mgr_confirm_external "${dir}" || return 0
    find "${dir}" -iname "${pattern}" 2>/dev/null | sed -n '1,200p'
}

_file_mgr_read() {
    local file
    file="$(_prompt_default 'File to read' '')"
    validate_path "${file}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    _file_mgr_confirm_external "${file}" || return 0
    [[ -f "${file}" ]] || { _error "E900" "Not a file: ${file}" 0; return 2; }
    sed -n '1,200p' -- "${file}"
}

_file_mgr_copy() {
    local src dst
    src="$(_prompt_default 'Source' '')"
    dst="$(_prompt_default 'Destination' '')"
    if ! validate_path "${src}" || ! validate_path "${dst}"; then
        _error "$(_path_validation_error_code)" "Invalid path" 0
        return 2
    fi
    _file_mgr_confirm_external "${src}" || return 0
    # PRD §22.1 steps 6-8: immediately before the mutating call, re-validate
    # both paths and reject a destination that currently exists as a
    # symlink (writing "through" it would silently affect whatever it
    # points to rather than the path the user typed).
    if ! validate_path "${src}" || ! validate_path "${dst}"; then
        _error "$(_path_validation_error_code)" "Path failed pre-copy revalidation" 0
        return 2
    fi
    _reject_symlink_destination "${dst}" || {
        _error "E434" "Refusing to copy onto an existing symlink: ${dst}" 0
        return 2
    }
    execute_structured cp "-a" "${src}" "${dst}"
}

_file_mgr_move_rename() {
    local src dst
    src="$(_prompt_default 'Source' '')"
    dst="$(_prompt_default 'New path/name' '')"
    if ! validate_path "${src}" || ! validate_path "${dst}"; then
        _error "$(_path_validation_error_code)" "Invalid path" 0
        return 2
    fi
    _confirm "Move/rename '${src}' to '${dst}'" || return 0
    # PRD §22.1 steps 6-8: immediately before the mutating call, re-validate
    # both paths and reject a destination that currently exists as a
    # symlink (see _reject_symlink_destination()).
    if ! validate_path "${src}" || ! validate_path "${dst}"; then
        _error "$(_path_validation_error_code)" "Path failed pre-move revalidation" 0
        return 2
    fi
    _reject_symlink_destination "${dst}" || {
        _error "E434" "Refusing to move onto an existing symlink: ${dst}" 0
        return 2
    }
    execute_structured mv "${src}" "${dst}"
}

_file_mgr_symlink() {
    local target link
    target="$(_prompt_default 'Link target' '')"
    link="$(_prompt_default 'Link path to create' '')"
    if ! validate_path "${target}" || ! validate_path "${link}"; then
        _error "$(_path_validation_error_code)" "Invalid path" 0
        return 2
    fi
    # PRD §22.1 step 7: revalidate immediately before the mutating call.
    # No symlink-destination check is needed here beyond what `ln -s`
    # itself already guarantees: with no `-f` in this executor's
    # allowlisted action set, `ln -s` refuses outright if `link` already
    # exists (of any type, symlink included), so it can never silently
    # write through or replace an existing path.
    if ! validate_path "${target}" || ! validate_path "${link}"; then
        _error "$(_path_validation_error_code)" "Path failed pre-symlink revalidation" 0
        return 2
    fi
    execute_structured ln "-s" "${target}" "${link}"
}

_file_mgr_delete() {
    local path
    path="$(_prompt_default 'Path to delete' '')"
    validate_path "${path}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    [[ -e "${path}" ]] || { _error "E900" "Path does not exist: ${path}" 0; return 2; }
    _confirm "PERMANENTLY delete '${path}'" || return 0
    # PRD §22.1 step 7: security-sensitive revalidation immediately before
    # the mutating syscall, using a freshly re-resolved check rather than
    # trusting the result from the prompt above (closes the validate/use
    # race window for this destructive operation).
    validate_path "${path}" || { _error "E435" "Path failed pre-deletion revalidation" 0; return 2; }
    if [[ -d "${path}" ]]; then
        execute_structured rm "-rf" "${path}"
    else
        execute_structured rm "-f" "${path}"
    fi
}

_file_mgr_bulk_delete() {
    local dir pattern
    dir="$(_prompt_default 'Directory' '')"
    pattern="$(_prompt_default 'Glob pattern of files to delete' '*.tmp')"
    validate_path "${dir}" || { _error "$(_path_validation_error_code)" "Invalid path" 0; return 2; }
    local -a matches=()
    local f
    while IFS= read -r f; do matches+=("${f}"); done < <(find "${dir}" -maxdepth 1 -iname "${pattern}" 2>/dev/null)
    [[ ${#matches[@]} -eq 0 ]] && { printf 'No matches.\n'; return 0; }
    printf '%s\n' "${matches[@]}"
    _confirm "Delete these ${#matches[@]} file(s)" || return 0
    for f in "${matches[@]}"; do
        # PRD §22.1 step 7: revalidate each target immediately before its
        # own mutating call rather than relying on the earlier `find` pass.
        validate_path "${f}" || { _error "E435" "Skipped (failed revalidation): ${f}" 0; continue; }
        execute_structured rm "-f" "${f}"
    done
}

# Contract: file_mgr_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
file_mgr_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== File Manager =="
        printf '%s\n' "1) Browse directory"
        printf '%s\n' "2) Search files"
        printf '%s\n' "3) Read a file"
        printf '%s\n' "4) Copy"
        printf '%s\n' "5) Move / rename"
        printf '%s\n' "6) Symlink"
        printf '%s\n' "7) Delete (single, confirmed)"
        printf '%s\n' "8) Bulk delete by pattern (confirmed)"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _file_mgr_browse; _pause "Press Enter to return to the menu" ;;
            2) _file_mgr_search; _pause "Press Enter to return to the menu" ;;
            3) _file_mgr_read; _pause "Press Enter to return to the menu" ;;
            4) _file_mgr_copy ;;
            5) _file_mgr_move_rename ;;
            6) _file_mgr_symlink ;;
            7) _file_mgr_delete ;;
            8) _file_mgr_bulk_delete ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
