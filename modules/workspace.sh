#!/usr/bin/env bash
# Devil's Mini OS Launcher - modules/workspace.sh
# PRD Reference: §13.7, §22, D3
# Public: workspace_menu()
# Default allowed workspace root: $HOME/devils-minios/workspaces/ (D3)

_workspace_list() {
    mkdir -p "${DEVILS_MINIOS_WORKSPACE_ROOT}"
    local d
    for d in "${DEVILS_MINIOS_WORKSPACE_ROOT}"/*/; do
        [[ -d "${d}" ]] || continue
        printf '%s\n' "$(basename "${d}")"
    done
}

_workspace_create() {
    local name template
    name="$(_prompt_default 'Workspace name' 'my-project')"
    name="$(sanitize_input "${name}" 64)"
    [[ "${name}" =~ ^[A-Za-z0-9_.-]+$ ]] || { _error "E900" "Workspace name must be alphanumeric/./_/-" 0; return 2; }
    local target="${DEVILS_MINIOS_WORKSPACE_ROOT}/${name}"
    validate_path "${target}" "${DEVILS_MINIOS_WORKSPACE_ROOT}" || { _error "$(_path_validation_error_code)" "Workspace path escapes the allowed root" 0; return 2; }
    [[ -e "${target}" ]] && { _error "E900" "Workspace already exists: ${name}" 0; return 2; }

    template="$(_prompt_default 'Template (blank/node/python/bash)' 'blank')"
    # PRD §22.1 steps 6-8: immediately before the mutating mkdir, re-validate
    # the target and reject if it now exists as a symlink (broken symlinks
    # pass the `-e` check above since `-e` follows the link) — `mkdir -p`
    # on an existing symlinked path would silently create/write inside
    # whatever it points to rather than a launcher-owned workspace dir.
    validate_path "${target}" "${DEVILS_MINIOS_WORKSPACE_ROOT}" || {
        _error "$(_path_validation_error_code)" "Workspace path failed pre-creation revalidation" 0
        return 2
    }
    # PRD-22.1-07: operate on the resolved path this revalidation just
    # produced, not the original unresolved string (falls back to
    # "${target}" if, for any reason, nothing was resolved).
    local resolved="${DEVILS_MINIOS_PATH_RESOLVED:-${target}}"
    _reject_symlink_destination "${resolved}" || {
        _error "E434" "Refusing to create a workspace over an existing symlink: ${target}" 0
        return 2
    }
    mkdir -p "${resolved}"
    case "${template}" in
        node) printf '{\n  "name": "%s",\n  "version": "0.1.0"\n}\n' "${name}" > "${resolved}/package.json" ;;
        python) printf '' > "${resolved}/requirements.txt"; printf '#!/usr/bin/env python3\n' > "${resolved}/main.py" ;;
        bash) printf '#!/usr/bin/env bash\nset -euo pipefail\n' > "${resolved}/main.sh"; chmod +x "${resolved}/main.sh" ;;
        *) : ;;
    esac
    _info "Workspace created: ${resolved}"
}

_workspace_delete() {
    local name
    name="$(_prompt_default 'Workspace name to delete' '')"
    # Same sanitize + name-grammar check as _workspace_create(); a raw,
    # unvalidated name here was a spec deviation (both entry points into
    # the same workspace root must apply identical input discipline).
    name="$(sanitize_input "${name}" 64)"
    [[ "${name}" =~ ^[A-Za-z0-9_.-]+$ ]] || { _error "E900" "Workspace name must be alphanumeric/./_/-" 0; return 2; }
    local target="${DEVILS_MINIOS_WORKSPACE_ROOT}/${name}"
    validate_path "${target}" "${DEVILS_MINIOS_WORKSPACE_ROOT}" || { _error "$(_path_validation_error_code)" "Invalid workspace path" 0; return 2; }
    # PRD §22.1 step 6: `-d` follows symlinks, so a symlink dropped at this
    # exact path (pointing at a real directory elsewhere) would pass this
    # check even though it is not a launcher-created workspace. Require the
    # entry to be a real directory, not a symlink to one, before it is
    # accepted as a deletable workspace at all.
    [[ -d "${target}" && ! -L "${target}" ]] || { _error "E900" "No such workspace: ${name}" 0; return 2; }
    _confirm "Permanently delete workspace '${name}'" || return 0
    # PRD §22.1 step 7: revalidate immediately before the mutating rm -rf.
    validate_path "${target}" "${DEVILS_MINIOS_WORKSPACE_ROOT}" || { _error "E435" "Path failed pre-deletion revalidation" 0; return 2; }
    # PRD-22.1-07: delete the resolved path this revalidation just
    # produced, not the original unresolved string.
    local resolved="${DEVILS_MINIOS_PATH_RESOLVED:-${target}}"
    [[ -d "${resolved}" && ! -L "${resolved}" ]] || { _error "E434" "Workspace path changed to a symlink between checks; refusing to delete" 0; return 2; }
    execute_structured rm "-rf" "${resolved}"
}

# Contract: workspace_menu(none); returns: 0 on normal completion, non-zero on failure/abort where applicable; side effects: renders UI and may invoke delegated user actions.
workspace_menu() {
    local choice
    while true; do
        clear_screen
        printf '%s\n' "== Workspace =="
        printf 'Root: %s\n\n' "${DEVILS_MINIOS_WORKSPACE_ROOT}"
        printf '%s\n' "1) List workspaces"
        printf '%s\n' "2) Create workspace"
        printf '%s\n' "3) Delete workspace"
        printf '%s\n' "0) Back"
        choice="$(_prompt_default 'Choice' '0')"
        case "${choice}" in
            1) _workspace_list; _confirm "Continue" || true ;;
            2) _workspace_create ;;
            3) _workspace_delete ;;
            0) return 0 ;;
            *) printf 'Invalid selection.\n'; sleep 1 ;;
        esac
    done
}
