#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/core_backup.sh
# Internal continuation of core.sh; not a feature module (not in
# DEVILS_MINIOS_FEATURE_MODULES, not reachable via --run-module).
# PRD Reference: §32.1 (pre-migration/pre-update backup manifest)
#
# Backup = a directory: <backups>/pre-update-<ts>-<pid>/{manifest,payload/}
#   payload/launcher/  launcher files (devils-minios.sh, SHA256SUMS,
#                      modules/*.sh, core/*.sh, data catalogs + defaults)
#   payload/config/    user configuration (config) + persistent state (state)
#   payload/meta/      launcher version metadata + migration metadata
# NOT included: workspaces, Proot user data, user files, caches, temp files.
#
# Manifest (key=value header, then one "entry=<sha256> <relative path>" line
# per payload file): backup_version, created_at, launcher_version,
# config_version, state_version, hash_algorithm=SHA-256, entries_count.

readonly DEVILS_MINIOS_BACKUP_VERSION="1"
declare -g DEVILS_MINIOS_BACKUP_PATH=""
declare -g -A _BK_HDR=()
declare -g -a _BK_ENTRIES=()

_backup_hash() {
    local out
    out="$(execute_structured sha256sum "" "$1" 2>/dev/null)" || return 1
    printf '%s' "${out%% *}"
}

# Manifest paths must be plain relative paths: no absolute form, no "."/".."
# segments, no shell metacharacters (§22.1-style lexical rule).
_backup_rel_ok() {
    local r="$1"
    [[ "${r}" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] || return 1
    [[ "/${r}/" != *"/../"* && "/${r}/" != *"/./"* ]] || return 1
    return 0
}

_backup_rm_staging() {
    [[ "$1" == *".staging-"* || "$1" == *".restore-staging."* ]] && rm -rf -- "$1" 2>/dev/null
    return 0
}

# backup_create — builds the backup in a staging dir, then renames it into
# place so a partial backup never appears under its final name. On success
# sets DEVILS_MINIOS_BACKUP_PATH and returns 0.
# Contract: backup_create(destination, label); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
backup_create() {
    local backups="${DEVILS_MINIOS_CONFIG_DIR}/backups"
    local stage="${backups}/.staging-$$"
    local final ts
    ts="$(date -u '+%Y%m%d-%H%M%S')"
    final="${backups}/pre-update-${ts}-$$"
    local inst="${DEVILS_MINIOS_INSTALL_DIR}" f rel
    DEVILS_MINIOS_BACKUP_PATH=""
    mkdir -p "${backups}" || return 1
    _backup_rm_staging "${stage}"
    mkdir -p "${stage}/payload/launcher" "${stage}/payload/config" "${stage}/payload/meta" || return 1

    for f in "${inst}/devils-minios.sh" "${inst}/SHA256SUMS" "${inst}"/modules/*.sh \
             "${inst}"/core/*.sh "${inst}"/data/*.db "${inst}/data/defaults.conf"; do
        [[ -f "${f}" && ! -L "${f}" ]] || continue
        rel="${f#"${inst}/"}"
        mkdir -p "${stage}/payload/launcher/$(dirname -- "${rel}")"
        cp -p "${f}" "${stage}/payload/launcher/${rel}" || { _backup_rm_staging "${stage}"; return 1; }
    done
    [[ -f "${stage}/payload/launcher/devils-minios.sh" ]] || {
        _warn "" "Backup skipped: launcher files not found under ${inst}"
        _backup_rm_staging "${stage}"; return 1
    }
    for f in "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_STATE_FILE}"; do
        [[ -f "${f}" && ! -L "${f}" ]] || continue
        cp -p "${f}" "${stage}/payload/config/$(basename -- "${f}")" || { _backup_rm_staging "${stage}"; return 1; }
    done
    printf 'launcher_version=%s\n' "${DEVILS_MINIOS_VERSION}" > "${stage}/payload/meta/launcher_version"
    printf 'migration_schema=1\nsource_launcher_version=%s\nsource_config_version=%s\nsource_state_version=%s\n' \
        "${DEVILS_MINIOS_VERSION}" "${DEVILS_MINIOS_CONFIG_VERSION}" "${DEVILS_MINIOS_STATE_VERSION}" \
        > "${stage}/payload/meta/migration"

    local -a files=() lines=()
    local h
    while IFS= read -r f; do files+=("${f}"); done < <(cd "${stage}/payload" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
    for rel in "${files[@]}"; do
        h="$(_backup_hash "${stage}/payload/${rel}")" || { _backup_rm_staging "${stage}"; return 1; }
        lines+=("entry=${h} ${rel}")
    done
    {
        printf 'backup_version=%s\ncreated_at=%s\nlauncher_version=%s\nconfig_version=%s\nstate_version=%s\nhash_algorithm=SHA-256\nentries_count=%d\n' \
            "${DEVILS_MINIOS_BACKUP_VERSION}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${DEVILS_MINIOS_VERSION}" \
            "${DEVILS_MINIOS_CONFIG_VERSION}" "${DEVILS_MINIOS_STATE_VERSION}" "${#files[@]}"
        printf '%s\n' "${lines[@]}"
    } > "${stage}/manifest.tmp" || { _backup_rm_staging "${stage}"; return 1; }
    mv -f "${stage}/manifest.tmp" "${stage}/manifest" || { _backup_rm_staging "${stage}"; return 1; }
    mv "${stage}" "${final}" || { _backup_rm_staging "${stage}"; return 1; }
    # shellcheck disable=SC2034  # output variable; read in core/devils_self_update.sh
    DEVILS_MINIOS_BACKUP_PATH="${final}"
    return 0
}

# _backup_check_tree <manifest> <payload_dir> — every manifest entry exists as
# a regular non-symlink file whose SHA-256 matches, and nothing else is there.
_backup_check_tree() {
    local payload="$2" e h rel actual n
    for e in "${_BK_ENTRIES[@]}"; do
        h="${e%% *}"; rel="${e#* }"
        [[ -f "${payload}/${rel}" && ! -L "${payload}/${rel}" ]] || { _warn "" "Backup entry missing: ${rel}"; return 1; }
        actual="$(_backup_hash "${payload}/${rel}")" || return 1
        [[ "${actual}" == "${h}" ]] || { _warn "" "Backup hash mismatch: ${rel}"; return 1; }
    done
    n="$(find "${payload}" -type f | wc -l)"
    [[ "${n//[[:space:]]/}" == "${#_BK_ENTRIES[@]}" ]] || { _warn "" "Backup payload has files not listed in manifest"; return 1; }
    [[ -z "$(find "${payload}" -type l | head -n 1)" ]] || { _warn "" "Backup payload contains a symlink"; return 1; }
    return 0
}

# backup_verify <backup_dir> — validate manifest structure, then hashes.
# Contract: backup_verify(backup_dir); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
backup_verify() {
    local dir="${1:-}" line key val seen
    local m="${dir}/manifest"
    _BK_HDR=(); _BK_ENTRIES=()
    [[ -n "${dir}" && -d "${dir}" && ! -L "${dir}" && -f "${m}" && ! -L "${m}" ]] \
        || { _warn "" "Backup manifest not found"; return 1; }
    while IFS= read -r line || [[ -n "${line}" ]]; do
        key="${line%%=*}"; val="${line#*=}"
        case "${key}" in
            entry)
                [[ "${val}" =~ ^[0-9a-f]{64}\ (.+)$ ]] || { _warn "" "Malformed manifest entry"; return 1; }
                _backup_rel_ok "${BASH_REMATCH[1]}" || { _warn "" "Unsafe manifest path: ${BASH_REMATCH[1]}"; return 1; }
                for seen in "${_BK_ENTRIES[@]}"; do
                    [[ "${seen#* }" != "${BASH_REMATCH[1]}" ]] || { _warn "" "Duplicate manifest path"; return 1; }
                done
                _BK_ENTRIES+=("${val}") ;;
            backup_version|created_at|launcher_version|config_version|state_version|hash_algorithm|entries_count)
                [[ -z "${_BK_HDR[${key}]+x}" && "${line}" == *=* ]] || { _warn "" "Duplicate/malformed manifest field: ${key}"; return 1; }
                _BK_HDR[${key}]="${val}" ;;
            *) _warn "" "Unknown manifest line"; return 1 ;;
        esac
    done < "${m}"
    for key in backup_version created_at launcher_version config_version state_version hash_algorithm entries_count; do
        [[ -n "${_BK_HDR[${key}]:-}" ]] || { _warn "" "Manifest missing ${key}"; return 1; }
    done
    [[ "${_BK_HDR[backup_version]}" == "${DEVILS_MINIOS_BACKUP_VERSION}" ]] || { _warn "" "Unsupported backup_version"; return 1; }
    [[ "${_BK_HDR[hash_algorithm]}" == "SHA-256" ]] || { _warn "" "Unsupported hash_algorithm"; return 1; }
    [[ "${_BK_HDR[entries_count]}" == "${#_BK_ENTRIES[@]}" && ${#_BK_ENTRIES[@]} -gt 0 ]] || { _warn "" "Manifest entries_count mismatch"; return 1; }
    _backup_check_tree "${m}" "${dir}/payload"
}

# backup_restore <backup_dir> — validate manifest -> verify hashes -> restore
# into staging -> validate restored config/state/files -> atomically activate.
# Nothing live is touched before every check passes. Launcher activation is a
# directory rename with rollback; config/state activation is per-file rename.
# Contract: backup_restore(backup_dir); returns: 0 on success, non-zero on failure; side effects: writes, replaces, backs up, restores, or removes persistent data as applicable.
backup_restore() {
    local dir="${1:-}" inst="${DEVILS_MINIOS_INSTALL_DIR}" cfgdir="${DEVILS_MINIOS_CONFIG_DIR}"
    local stage="${cfgdir}/.restore-staging.$$" istage="${inst}.restore-staging.$$" iprev="${inst}.restore-prev.$$"
    local e rel f
    backup_verify "${dir}" || return 1
    _backup_rm_staging "${stage}"; _backup_rm_staging "${istage}"
    mkdir -p "${stage}/old" || return 1
    cp -a "${inst}" "${istage}" || { _backup_rm_staging "${stage}"; return 1; }
    for e in "${_BK_ENTRIES[@]}"; do
        rel="${e#* }"
        case "${rel}" in
            launcher/*) mkdir -p "${istage}/$(dirname -- "${rel#launcher/}")"
                        cp -p "${dir}/payload/${rel}" "${istage}/${rel#launcher/}" ;;
            config/*)   cp -p "${dir}/payload/${rel}" "${stage}/$(basename -- "${rel}")" ;;
        esac || { _backup_rm_staging "${stage}"; _backup_rm_staging "${istage}"; return 1; }
    done
    # Validate the restored (staged) files before anything is activated.
    local ok=true
    for e in "${_BK_ENTRIES[@]}"; do
        rel="${e#* }"
        [[ "${rel}" == launcher/* ]] && [[ "$(_backup_hash "${istage}/${rel#launcher/}")" != "${e%% *}" ]] && ok=false
    done
    [[ -f "${istage}/devils-minios.sh" && -f "${istage}/modules/core.sh" ]] || ok=false
    [[ ! -f "${stage}/config" ]] || validate_config "${stage}/config" || ok=false
    [[ ! -f "${stage}/state" ]] || validate_state "${stage}/state" || ok=false
    if [[ "${ok}" != true ]]; then
        _warn "" "Restore validation failed; active installation untouched"
        _backup_rm_staging "${stage}"; _backup_rm_staging "${istage}"; return 1
    fi
    # Atomic activation.
    mv "${inst}" "${iprev}" || { _backup_rm_staging "${stage}"; _backup_rm_staging "${istage}"; return 1; }
    if ! mv "${istage}" "${inst}"; then
        mv "${iprev}" "${inst}"; _backup_rm_staging "${stage}"; return 1
    fi
    for f in config state; do
        [[ -f "${stage}/${f}" ]] || continue
        [[ -f "${cfgdir}/${f}" ]] && cp -p "${cfgdir}/${f}" "${stage}/old/${f}"
        if ! mv -f "${stage}/${f}" "${cfgdir}/${f}"; then
            for e in config state; do [[ -f "${stage}/old/${e}" ]] && mv -f "${stage}/old/${e}" "${cfgdir}/${e}"; done
            mv "${inst}" "${istage}" && mv "${iprev}" "${inst}"
            _backup_rm_staging "${stage}"; _backup_rm_staging "${istage}"
            _warn "" "Restore activation failed; previous installation restored"
            return 1
        fi
        chmod 600 "${cfgdir}/${f}" 2>/dev/null || true
    done
    rm -rf -- "${iprev}" 2>/dev/null || true
    _backup_rm_staging "${stage}"
    return 0
}
