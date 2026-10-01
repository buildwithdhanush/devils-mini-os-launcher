#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/devils_self_update.sh
# Split from devils-minios.sh (PRD file-size limit). Sourced by
# devils-minios.sh immediately after modules/core.sh, before CLI
# parsing/dispatch, so _self_update()/_semver_gt()/_self_update_abort()
# are available wherever devils-minios.sh calls them (--update dispatch
# and the startup update-notice check). Not a feature module: not in
# DEVILS_MINIOS_FEATURE_MODULES, not reachable via --run-module.
# PRD Reference: §30.4, §30.5, §30.6

# ============================================================================
# SELF-UPDATE (§30.4-§30.6) - hardcoded trust anchor, pinned-tag selection,
# checksum verification, staged/atomic activation with rollback.
# ============================================================================

# Strict SemVer comparison: returns 0 (true) iff $1 > $2. Both args may be
# "vX.Y.Z" or "X.Y.Z".
_semver_gt() {
    local a="${1#v}" b="${2#v}"
    local -a av bv
    IFS='.' read -ra av <<< "${a}"
    IFS='.' read -ra bv <<< "${b}"
    local i ai bi
    for i in 0 1 2; do
        ai="${av[${i}]:-0}"
        bi="${bv[${i}]:-0}"
        [[ "${ai}" =~ ^[0-9]+$ ]] || ai=0
        [[ "${bi}" =~ ^[0-9]+$ ]] || bi=0
        if [[ ${ai} -gt ${bi} ]]; then return 0; fi
        if [[ ${ai} -lt ${bi} ]]; then return 1; fi
    done
    return 1
}

# §22.1 step 7: "any recursive deletion" is security-sensitive and must be
# revalidated immediately before the mutating rm, never on a value merely
# constructed or checked earlier in the operation. These paths are always
# launcher-constructed (never user input), but are still guarded here
# against the shape they were built with — a defense-in-depth check that
# catches a corrupted/reassigned variable before it reaches `rm -rf`,
# consistent with file_mgr.sh/workspace.sh's revalidation of user paths.
_self_update_path_shape_ok() {
    local path="${1:-}" parent
    [[ -n "${path}" && "${path}" != "/" ]] || return 1
    case "${path}" in
        "${DEVILS_MINIOS_INSTALL_DIR}".update-staging.*|"${DEVILS_MINIOS_INSTALL_DIR}".previous.*) ;;
        */devils-minios-update-*) ;;
        *) return 1 ;;
    esac
    parent="$(dirname -- "${path}")"
    validate_path "${path}" "${parent}" || return 1
    [[ "${DEVILS_MINIOS_PATH_RESOLVED:-}" == "${path}" ]] || return 1
    return 0
}

# Cleans up a temp checkout/staging dir and returns the launcher to IDLE
# after a failed or aborted update; never touches the active installation.
_self_update_abort() {
    local tmp1="${1:-}" tmp2="${2:-}"
    if [[ -n "${tmp1}" ]]; then
        _self_update_path_shape_ok "${tmp1}" && rm -rf "${tmp1}" 2>/dev/null || true
    fi
    if [[ -n "${tmp2}" ]]; then
        _self_update_path_shape_ok "${tmp2}" && rm -rf "${tmp2}" 2>/dev/null || true
    fi
    record_state_transition "IDLE" 2>/dev/null || _enter_idle_state
}

# _self_update_rollback(previous_dir, staging_dir, checkout_dir) - §30.4/
# §30.6 step 10, §48.2 E702/E703. Restores the previous installation after
# a failed activation. Returns 0 if the previous installation was restored
# (caller logs E702 and continues, non-fatal); returns 1 if the restoring
# mv itself also failed (caller logs E703 and must route to Safe Mode).
# On a double failure, staging_dir/previous_dir are deliberately left on
# disk rather than cleaned up: one of them is likely the only remaining
# copy of a working installation, needed for manual recovery.
_self_update_rollback() {
    local previous_dir="$1" staging_dir="$2" checkout_dir="$3"
    if mv "${previous_dir}" "${DEVILS_MINIOS_INSTALL_DIR}" 2>/dev/null; then
        # §22.1 step 7: revalidate immediately before each mutating rm -rf.
        _self_update_path_shape_ok "${staging_dir}" && rm -rf "${staging_dir}" 2>/dev/null || true
        _self_update_path_shape_ok "${checkout_dir}" && rm -rf "${checkout_dir}" 2>/dev/null || true
        return 0
    fi
    return 1
}

_self_update() {
    record_state_transition "UPDATING" || { _error "E400" "Cannot update from state ${DEVILS_MINIOS_CURRENT_STATE}" 0; exit 2; }

    if [[ "${DEVILS_MINIOS_OFFLINE_MODE}" == true ]]; then
        _warn "" "--update requires network access; --offline is set"
        _self_update_abort
        exit 1
    fi
    _has_command git || { _warn "" "git is required for --update"; _self_update_abort; exit 1; }
    check_battery_gate "self-update" || { _self_update_abort; exit 3; }

    # Hardcoded trust anchor (§30.4): never read from config, env, or a flag.
    local repo_url="${DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL}"
    if [[ "${repo_url}" != https://github.com/* ]]; then
        _error "E900" "Trust anchor is not an HTTPS github.com URL" 0
        _self_update_abort
        exit 1
    fi

    _info "Checking ${repo_url} for updates..."
    local raw_tags
    if ! raw_tags="$(execute_structured git "ls-remote" "--tags" "${repo_url}" 2>/dev/null)"; then
        _warn "" "Network failure while checking for updates; active installation untouched"
        _self_update_abort
        exit 1
    fi

    # Stable-tag rule (§30.4): strict vMAJOR.MINOR.PATCH only; pre-release
    # suffixes and build metadata are excluded from automatic selection.
    local -a candidates=()
    local line tag
    while IFS= read -r line; do
        tag="${line##*refs/tags/}"
        tag="${tag%\^\{\}}"
        [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && candidates+=("${tag}")
    done <<< "${raw_tags}"

    if [[ ${#candidates[@]} -eq 0 ]]; then
        _info "No stable release tags found; nothing to update"
        _self_update_abort
        exit 0
    fi

    local current="v${DEVILS_MINIOS_VERSION}"
    local best="" c
    for c in "${candidates[@]}"; do
        if _semver_gt "${c}" "${current}" && { [[ -z "${best}" ]] || _semver_gt "${c}" "${best}"; }; then
            best="${c}"
        fi
    done

    if [[ -z "${best}" ]]; then
        _info "Already up to date (${current})"
        _self_update_abort
        exit 0
    fi
    _info "Selected release ${best} (current ${current})"

    check_storage_threshold "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}" || { _self_update_abort; exit 3; }

    # Installer-owned temporary checkout, tracked by this captured variable
    # only (§30.1, applied identically to the updater per §30.6).
    local tmp_root="${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}"
    mkdir -p "${tmp_root}"
    local checkout_dir
    checkout_dir="$(mktemp -d "${tmp_root}/devils-minios-update-XXXXXXXX" 2>/dev/null || true)"
    if [[ -z "${checkout_dir}" ]]; then
        _error "E900" "Could not create temporary update checkout directory" 0
        _self_update_abort
        exit 1
    fi
    local release_dir="${checkout_dir}/src"

    if ! execute_structured git "clone" "--depth" "1" "--branch" "${best}" "${repo_url}" "${release_dir}"; then
        _warn "" "Failed to fetch release ${best}; active installation untouched"
        _self_update_abort "${checkout_dir}"
        exit 1
    fi

    if [[ -f "${release_dir}/SHA256SUMS" ]]; then
        # §23.3/§30.5: verify the fetched (network-derived) release via
        # execute_structured(), not a direct subprocess call. `cd` is a
        # shell builtin (no subprocess spawned) used only to scope the
        # manifest's relative paths to the release checkout it describes;
        # the actual sha256sum dispatch still goes through the sole
        # sanctioned executor boundary.
        if ! ( cd "${release_dir}" && execute_structured sha256sum "-c" "SHA256SUMS" "--status" ); then
            # §48.2 E701: update-release verification failure. (E404 is the
            # generic download-checksum code used for catalog app artifacts
            # in core_catalog.sh; this is the launcher's own release, which
            # §48.2 registers separately.)
            # §48.2 E701: registry-required exit status is 2 (INSTALL-HASH
            # recovery eligibility, never auto-recovered), not the generic 1.
            _error "E701" "Release ${best} failed checksum verification; aborting update, no partial state" 0
            _self_update_abort "${checkout_dir}"
            exit 2
        fi
        _info "Release manifest verified (integrity only, §30.5)"
    else
        _warn "" "Release ${best} ships no SHA256SUMS; integrity check skipped"
    fi

    local -a required_modules=(
        core linux_env file_mgr termux_apps proot_apps android_tools workspace
        health_check log_viewer customize system_tools system_info update_all settings
    )
    local m ok=true
    [[ -f "${release_dir}/devils-minios.sh" ]] || ok=false
    # core/ holds the internal components sourced at startup (install.sh
    # REQUIRED_CORE_FILES); a release without them cannot start.
    [[ -f "${release_dir}/core/devils_self_update.sh" && -f "${release_dir}/core/core_state.sh" ]] || ok=false
    for m in "${required_modules[@]}"; do
        [[ -f "${release_dir}/modules/${m}.sh" ]] || ok=false
    done
    if [[ "${ok}" != true ]]; then
        # §48.2 E701 (§30.6 step 4 "Verify the release manifest and required files"):
        # registry exit status is 2.
        _error "E701" "Fetched release ${best} is missing required files; update failed verification, no changes made" 0
        _self_update_abort "${checkout_dir}"
        exit 2
    fi

    # §32.1 pre-update backup: manifest + per-file SHA-256 (core/core_backup.sh).
    local backup_file=""
    if backup_create; then
        backup_file="${DEVILS_MINIOS_BACKUP_PATH}"
    else
        _warn "" "Could not create pre-update backup; continuing"
    fi

    # Stage the new installation beside the active one; only swap after the
    # staged copy validates (§30.6 steps 5-8).
    local staging_dir="${DEVILS_MINIOS_INSTALL_DIR}.update-staging.$$"
    # §22.1 step 7: revalidate immediately before the mutating rm -rf.
    if _self_update_path_shape_ok "${staging_dir}"; then
        rm -rf "${staging_dir}" 2>/dev/null || true
    fi
    mkdir -p "${staging_dir}"
    cp -r "${release_dir}/devils-minios.sh" "${staging_dir}/" 2>/dev/null || true
    cp -r "${release_dir}/modules" "${staging_dir}/" 2>/dev/null || true
    cp -r "${release_dir}/core" "${staging_dir}/" 2>/dev/null || true
    [[ -d "${release_dir}/data" ]] && cp -r "${release_dir}/data" "${staging_dir}/"
    [[ -f "${release_dir}/SHA256SUMS" ]] && cp "${release_dir}/SHA256SUMS" "${staging_dir}/"
    chmod 755 "${staging_dir}/devils-minios.sh" 2>/dev/null || true
    find "${staging_dir}/modules" "${staging_dir}/core" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

    if [[ ! -f "${staging_dir}/devils-minios.sh" || ! -f "${staging_dir}/modules/core.sh" || ! -f "${staging_dir}/core/core_state.sh" ]]; then
        _error "E900" "Staged update failed validation; active installation untouched" 0
        _self_update_abort "${checkout_dir}" "${staging_dir}"
        exit 1
    fi

    local previous_dir="${DEVILS_MINIOS_INSTALL_DIR}.previous.$$"
    if ! mv "${DEVILS_MINIOS_INSTALL_DIR}" "${previous_dir}"; then
        _error "E900" "Could not move aside the active installation; aborting" 0
        _self_update_abort "${checkout_dir}" "${staging_dir}"
        exit 1
    fi
    if mv "${staging_dir}" "${DEVILS_MINIOS_INSTALL_DIR}"; then
        # §22.1 step 7: revalidate immediately before each mutating rm -rf.
        _self_update_path_shape_ok "${previous_dir}" && rm -rf "${previous_dir}" 2>/dev/null || true
        _self_update_path_shape_ok "${checkout_dir}" && rm -rf "${checkout_dir}" 2>/dev/null || true
        _info "Updated to ${best}. Configuration and state preserved; pre-update backup at ${backup_file}"
        record_state_transition "IDLE" 2>/dev/null || _enter_idle_state
        exit 0
    fi

    # Rollback (§30.4 "Rollback", §30.6 step 10): restore the previous
    # installation on any activation failure.
    if _self_update_rollback "${previous_dir}" "${staging_dir}" "${checkout_dir}"; then
        # §48.2 E702: update activation failure, rollback succeeded - the
        # active installation is back to its pre-update state.
        _error "E702" "Activation failed; restored previous installation" 0
        record_state_transition "IDLE" 2>/dev/null || _enter_idle_state
        exit 1
    else
        # §48.2 E703: update/migration failure where rollback ALSO failed -
        # the launcher may now have no working installation on disk. Route
        # to Safe Mode (§40.1: Safe Mode Core never depends on
        # Proot/Desktop availability) rather than exiting silently, since
        # this is exactly the disaster-recovery case Safe Mode exists for.
        _error "E703" "Activation failed and rollback also failed; previous installation retained at ${previous_dir}, staged copy at ${staging_dir}" 0
        trigger_safe_mode "E703: self-update activation and rollback both failed"
        exit 1
    fi
}

