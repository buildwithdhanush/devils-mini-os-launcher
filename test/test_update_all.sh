#!/usr/bin/env bash
# test_update_all.sh - PRD §43.1: Updates, dry-run, trust-anchor constant
# immutability, tag/SemVer validation, checksum verification (§30.4, §30.5).
# This file's test snippets are intentionally single-quoted (see
# test/lib/harness.sh: run_core/run_module embed the snippet verbatim
# into a heredoc evaluated by a separate inner `bash -s`, so it must
# NOT be expanded by this outer shell). File-wide, not per-line, since
# nearly every assertion in this file uses the pattern.
# shellcheck disable=SC2016
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/harness.sh
source "${SCRIPT_DIR}/lib/harness.sh"
SBOX="$(new_sandbox)"
section "update_all module loads"
out="$(run_module "${SBOX}" "update_all" '
    type update_all_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "update_all_menu defined" "${out}" "menu=ok"
section "OFFICIAL_REPOSITORY_URL is a hardcoded constant"
out="$(run_core "${SBOX}" '
    printf "url=%s\n" "${DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL}"
')"
assert_contains "trust anchor is github.com/buildwithdhanush" "${out}" "github.com/buildwithdhanush/Devils-Mini-OS-Launcher"
section "§17.6/§29 network timeout and retry policy is consumed centrally"
FAKE_CURL_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-curl-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_CURL_BIN}")
cat > "${FAKE_CURL_BIN}/curl" <<'FAKECURL'
#!/usr/bin/env bash
count_file="${DMOS_CURL_COUNT_FILE}"
count=0
[[ -f "${count_file}" ]] && count="$(cat "${count_file}")"
count=$((count + 1))
printf '%s' "${count}" > "${count_file}"
if [[ ${count} -lt 3 ]]; then exit 22; fi
out=''
while [[ $# -gt 0 ]]; do
    if [[ "$1" == '-o' ]]; then out="$2"; shift 2; continue; fi
    shift
done
printf 'ok' > "${out}"
exit 0
FAKECURL
chmod 755 "${FAKE_CURL_BIN}/curl"
SBOX_RETRY="$(new_sandbox)"
RETRY_FILE="${SBOX_RETRY}/curl-count"
out="$(run_core "${SBOX_RETRY}" '
    DEVILS_MINIOS_CONFIG[network_timeout]=1
    DEVILS_MINIOS_CONFIG[network_retries]=3
    export DMOS_CURL_COUNT_FILE="${HOME}/curl-count"
    export PATH="'"${FAKE_CURL_BIN}"':${PATH}"
    tmp="${HOME}/download.bin"
    execute_structured curl "-fsSL" "-o" "${tmp}" "https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher/releases/download/v1.0.0/test"
    printf "curl_rc=%s attempts=%s content=%s\n" "$?" "$(cat "${DMOS_CURL_COUNT_FILE}")" "$(cat "${tmp}")"
')"
assert_contains "network_retries retries a failed GitHub download and eventually succeeds" "${out}" "curl_rc=0 attempts=3 content=ok"
section "startup update notice uses the centralized structured executor"
assert_eq "startup update notice does not directly execute git ls-remote" "0" "$(grep -n 'git ls-remote' "${DMOS_PROJECT_ROOT}/devils-minios.sh" | wc -l | tr -d ' ')"
assert_contains "startup update notice dispatches git ls-remote through execute_structured" "$(grep -n 'execute_structured git "ls-remote"' "${DMOS_PROJECT_ROOT}/devils-minios.sh")" "execute_structured git"
section "no config key can override the repository URL"
# Static: config schema must not contain a repository URL key
if grep -qE 'repository_url|repo_url|update_url|OFFICIAL_REPOSITORY' "${DMOS_PROJECT_ROOT}/data/defaults.conf" 2>/dev/null; then
    fail "defaults.conf must not expose a repository URL config key"
else
    pass "no repository URL config key in defaults.conf"
fi
section "SHA256SUMS exists for integrity verification"
if [[ -f "${DMOS_PROJECT_ROOT}/SHA256SUMS" ]]; then
    pass "SHA256SUMS present in project root"
else
    fail "SHA256SUMS missing"
fi
section "E701 (INSTALL-HASH): release checksum failure -> no partial activation, retryable exit 2"
# _self_update() is not a feature module (not sourced by run_module); source
# it the same way devils-minios.sh does, immediately after modules/core.sh.
# A fake `git` ahead of PATH stands in for the network: `ls-remote --tags`
# reports one newer stable tag, and `clone` materializes it by copying the
# sandbox's own already-valid installation, then deliberately replacing
# SHA256SUMS with a mismatching manifest so the real `sha256sum -c` (the
# sole sanctioned verifier, invoked only via execute_structured()) fails.
SBOX_UPD="$(new_sandbox)"
FAKE_GIT_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-git-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_GIT_BIN}")
cat > "${FAKE_GIT_BIN}/git" <<'FAKEGIT'
#!/usr/bin/env bash
case "$1" in
    ls-remote)
        printf 'abc123def456\trefs/tags/v9.9.9\n'
        ;;
    clone)
        # git clone --depth 1 --branch <tag> <url> <dest>
        dest="${*: -1}"
        mkdir -p "${dest}"
        cp -r "${DMOS_FAKE_RELEASE_SRC}/." "${dest}/"
        printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  devils-minios.sh\n' > "${dest}/SHA256SUMS"
        ;;
esac
exit 0
FAKEGIT
chmod 755 "${FAKE_GIT_BIN}/git"
out="$(run_core "${SBOX_UPD}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    export DMOS_FAKE_RELEASE_SRC="${DEVILS_MINIOS_INSTALL_DIR}"
    export PATH="'"${FAKE_GIT_BIN}"':${PATH}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    before_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    ( _self_update )
    printf "self_update_rc=%s\n" "$?"
    after_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    [[ "${before_sum}" == "${after_sum}" ]] && printf "install_unchanged=yes\n" || printf "install_unchanged=no\n"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "release checksum failure logs E701" "${out}" "E701"
assert_contains "E701 exits with retryable status 2 (INSTALL-HASH)" "${out}" "self_update_rc=2"
assert_contains "no partial activation: active installation is byte-identical after E701" "${out}" "install_unchanged=yes"
assert_contains "E701 aborts back to IDLE (no lingering UPDATING state)" "${out}" "state=IDLE"
assert_not_contains "E701 does not trigger the E702 rollback-succeeded path" "${out}" "E702"
assert_not_contains "E701 does not trigger the E703 rollback-failed / Safe Mode path" "${out}" "E703"
section "E701 (§30.6 step 4): fetched release missing required files -> registered code, exit 2, install untouched"
# Same fake-git technique as above, but the materialized release ships no
# SHA256SUMS (integrity check skipped) and lacks one required module, so
# only the required-files half of step 4 can reject it.
SBOX_MRF="$(new_sandbox)"
FAKE_GIT_MRF="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-git-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_GIT_MRF}")
cat > "${FAKE_GIT_MRF}/git" <<'FAKEGIT'
#!/usr/bin/env bash
case "$1" in
    ls-remote)
        printf 'abc123def456\trefs/tags/v9.9.9\n'
        ;;
    clone)
        dest="${*: -1}"
        mkdir -p "${dest}"
        cp -r "${DMOS_FAKE_RELEASE_SRC}/." "${dest}/"
        rm -f "${dest}/SHA256SUMS" "${dest}/modules/health_check.sh"
        ;;
esac
exit 0
FAKEGIT
chmod 755 "${FAKE_GIT_MRF}/git"
out="$(run_core "${SBOX_MRF}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    export DMOS_FAKE_RELEASE_SRC="${DEVILS_MINIOS_INSTALL_DIR}"
    export PATH="'"${FAKE_GIT_MRF}"':${PATH}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    before_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    ( _self_update ) 2>&1
    printf "self_update_rc=%s\n" "$?"
    after_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    [[ "${before_sum}" == "${after_sum}" ]] && printf "install_unchanged=yes\n" || printf "install_unchanged=no\n"
')"
assert_contains "missing required files is reported as E701 (release verification failure)" "${out}" "E701"
assert_not_contains "missing required files is no longer reported under unregistered E100" "${out}" "E100"
assert_contains "missing required files exits with the registered status 2" "${out}" "self_update_rc=2"
assert_contains "active installation is untouched when the release lacks required files" "${out}" "install_unchanged=yes"
section "E702 (rollback succeeded): activation failure restores the previous installation, exit 1"
# Reuses the E701 test's fake-git technique (network stand-in, no
# SHA256SUMS shipped so the integrity check is skipped and the flow
# reaches staged activation). A fake `mv` ahead of PATH makes only the
# "activate staging" mv fail (matched by the `.update-staging.` path
# component _self_update() itself constructs), while the "move active
# aside" and "rollback" mv calls fall through to the real `mv`, so
# rollback succeeds.
SBOX_E702="$(new_sandbox)"
FAKE_GIT_BIN_702="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-git-XXXXXXXX")"
FAKE_MV_BIN_702="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-mv-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_GIT_BIN_702}" "${FAKE_MV_BIN_702}")
cat > "${FAKE_GIT_BIN_702}/git" <<'FAKEGIT'
#!/usr/bin/env bash
case "$1" in
    ls-remote)
        printf 'abc123def456\trefs/tags/v9.9.9\n'
        ;;
    clone)
        dest="${*: -1}"
        mkdir -p "${dest}"
        cp -r "${DMOS_FAKE_RELEASE_SRC}/." "${dest}/"
        rm -f "${dest}/SHA256SUMS"
        ;;
esac
exit 0
FAKEGIT
chmod 755 "${FAKE_GIT_BIN_702}/git"
cat > "${FAKE_MV_BIN_702}/mv" <<'FAKEMV'
#!/usr/bin/env bash
if [[ "$1" == *.update-staging.* ]]; then
    exit 1
fi
exec /bin/mv "$@"
FAKEMV
chmod 755 "${FAKE_MV_BIN_702}/mv"
out="$(run_core "${SBOX_E702}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    export DMOS_FAKE_RELEASE_SRC="${DEVILS_MINIOS_INSTALL_DIR}"
    export PATH="'"${FAKE_GIT_BIN_702}:${FAKE_MV_BIN_702}"':${PATH}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    before_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    ( _self_update )
    printf "self_update_rc=%s\n" "$?"
    after_sum="$(sha256sum "${DEVILS_MINIOS_INSTALL_DIR}/devils-minios.sh")"
    [[ "${before_sum}" == "${after_sum}" ]] && printf "install_restored=yes\n" || printf "install_restored=no\n"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "activation failure with successful rollback logs E702" "${out}" "E702"
assert_contains "E702 exits with status 1" "${out}" "self_update_rc=1"
assert_contains "E702: previous installation is restored (byte-identical)" "${out}" "install_restored=yes"
assert_contains "E702 returns to IDLE (no Safe Mode)" "${out}" "state=IDLE"
assert_not_contains "E702 does not also trigger the E703 failed-rollback path" "${out}" "E703"
section "E703 (rollback also failed): Safe Mode routing, exit 1"
# Same fake-git setup, but the fake `mv` also fails the rollback mv
# (matched by the `.previous.` path component), so the launcher is left
# with no active installation on disk and must route to Safe Mode.
SBOX_E703="$(new_sandbox)"
FAKE_GIT_BIN_703="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-git-XXXXXXXX")"
FAKE_MV_BIN_703="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-mv-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_GIT_BIN_703}" "${FAKE_MV_BIN_703}")
cat > "${FAKE_GIT_BIN_703}/git" <<'FAKEGIT'
#!/usr/bin/env bash
case "$1" in
    ls-remote)
        printf 'abc123def456\trefs/tags/v9.9.9\n'
        ;;
    clone)
        dest="${*: -1}"
        mkdir -p "${dest}"
        cp -r "${DMOS_FAKE_RELEASE_SRC}/." "${dest}/"
        rm -f "${dest}/SHA256SUMS"
        ;;
esac
exit 0
FAKEGIT
chmod 755 "${FAKE_GIT_BIN_703}/git"
cat > "${FAKE_MV_BIN_703}/mv" <<'FAKEMV'
#!/usr/bin/env bash
if [[ "$1" == *.update-staging.* || "$1" == *.previous.* ]]; then
    exit 1
fi
exec /bin/mv "$@"
FAKEMV
chmod 755 "${FAKE_MV_BIN_703}/mv"
out="$(run_core "${SBOX_E703}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    export DMOS_FAKE_RELEASE_SRC="${DEVILS_MINIOS_INSTALL_DIR}"
    export PATH="'"${FAKE_GIT_BIN_703}:${FAKE_MV_BIN_703}"':${PATH}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    ( printf "2\ny\n" | _self_update )
    printf "self_update_rc=%s\n" "$?"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "activation failure with failed rollback logs E703" "${out}" "E703"
assert_contains "E703 exits with status 1" "${out}" "self_update_rc=1"
assert_contains "E703 routes to Safe Mode" "${out}" "SAFE MODE"
assert_contains "E703 Safe Mode's repair-config option (2) returns control, leaving state IDLE" "${out}" "state=IDLE"
section "PRD §22.1 step 7: self-update deletion paths revalidate before rm -rf"
# _self_update_path_shape_ok() is the immediate-pre-mutation guard in front of
# every self-update rm -rf (_self_update_abort, _self_update_rollback, and the
# staging/previous-dir cleanups inside _self_update itself). It must accept
# only the launcher-constructed staging/previous/checkout shapes and reject
# anything else a corrupted or reassigned variable could produce, including
# the install dir itself and "/".
out="$(run_core "${SBOX}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    _self_update_path_shape_ok "${DEVILS_MINIOS_INSTALL_DIR}.update-staging.1234" && printf "staging=accepted\n" || printf "staging=rejected\n"
    _self_update_path_shape_ok "${DEVILS_MINIOS_INSTALL_DIR}.previous.1234" && printf "previous=accepted\n" || printf "previous=rejected\n"
    _self_update_path_shape_ok "/tmp/devils-minios-update-abc123" && printf "checkout=accepted\n" || printf "checkout=rejected\n"
    _self_update_path_shape_ok "/" && printf "root=accepted\n" || printf "root=rejected\n"
    _self_update_path_shape_ok "" && printf "empty=accepted\n" || printf "empty=rejected\n"
    _self_update_path_shape_ok "${DEVILS_MINIOS_INSTALL_DIR}" && printf "installdir=accepted\n" || printf "installdir=rejected\n"
    _self_update_path_shape_ok "/etc" && printf "etc=accepted\n" || printf "etc=rejected\n"
')"
assert_contains "valid staging-dir shape accepted" "${out}" "staging=accepted"
assert_contains "valid previous-dir shape accepted" "${out}" "previous=accepted"
assert_contains "valid checkout-dir shape accepted" "${out}" "checkout=accepted"
assert_contains "bare / is rejected (never a valid deletion target)" "${out}" "root=rejected"
assert_contains "empty path is rejected" "${out}" "empty=rejected"
assert_contains "the active install dir itself is rejected (not a staging/previous shape)" "${out}" "installdir=rejected"
assert_contains "an unrelated attacker-controlled path (/etc) is rejected" "${out}" "etc=rejected"
section "PRD §32.1: backup manifest contract (create)"
SBOX_BK="$(new_sandbox)"
out="$(run_core "${SBOX_BK}" '
    load_config >/dev/null 2>&1; load_state >/dev/null 2>&1
    mkdir -p "${HOME}/devils-minios/workspaces/w1" "${DEVILS_MINIOS_CACHE_DIR}" "${DEVILS_MINIOS_TMP_DIR}" "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/debian"
    printf x > "${HOME}/devils-minios/workspaces/w1/user.txt"; printf x > "${DEVILS_MINIOS_CACHE_DIR}/cachefile"
    printf x > "${DEVILS_MINIOS_TMP_DIR}/tmpfile"; printf x > "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/debian/rootfile"
    backup_create; printf "create_rc=%s\n" "$?"
    bk="${DEVILS_MINIOS_BACKUP_PATH}"; printf "path=%s\n" "${bk}"
    cat "${bk}/manifest"
')"
BK_PATH="$(printf '%s\n' "${out}" | sed -n 's/^path=//p')"
assert_contains "backup_create succeeds" "${out}" "create_rc=0"
assert_contains "manifest has backup_version" "${out}" "backup_version=1"
assert_contains "manifest has created_at (UTC ISO-8601)" "${out}" "created_at=20"
assert_contains "manifest has launcher_version" "${out}" "launcher_version=1.0.0"
assert_contains "manifest has config_version" "${out}" "config_version=1"
assert_contains "manifest has state_version" "${out}" "state_version=1"
assert_contains "manifest has hash_algorithm=SHA-256" "${out}" "hash_algorithm=SHA-256"
assert_contains "manifest lists launcher files (entry: relative path + SHA-256)" "${out}" " launcher/devils-minios.sh"
assert_contains "manifest lists launcher modules and core files" "${out}" " launcher/core/core_backup.sh"
assert_contains "manifest lists user configuration" "${out}" " config/config"
assert_contains "manifest lists persistent launcher state" "${out}" " config/state"
assert_contains "manifest lists launcher version metadata" "${out}" " meta/launcher_version"
assert_contains "manifest lists migration metadata" "${out}" " meta/migration"
if printf '%s\n' "${out}" | grep -E '^entry=' | grep -qvE '^entry=[0-9a-f]{64} [A-Za-z0-9._/-]+$'; then
    fail "every entry is exactly '<64-hex sha256> <relative path>'"
else
    pass "every entry is exactly '<64-hex sha256> <relative path>'"
fi
assert_not_contains "workspaces are not duplicated" "${out}" "workspaces"
assert_not_contains "user files are not duplicated" "${out}" "user.txt"
assert_not_contains "normal caches are not duplicated" "${out}" "cachefile"
assert_not_contains "temporary files are not duplicated" "${out}" "tmpfile"
assert_not_contains "Proot user data is not duplicated" "${out}" "rootfile"
section "PRD §32.1: verify rejects tampered / malformed backups"
out="$(run_core "${SBOX_BK}" '
    bk="'"${BK_PATH}"'"
    backup_verify "${bk}" >/dev/null 2>&1; printf "verify_ok_rc=%s\n" "$?"
    cp -a "${bk}" "${bk}.t1"; printf x >> "${bk}.t1/payload/config/config"
    backup_verify "${bk}.t1" >/dev/null 2>&1; printf "tampered_rc=%s\n" "$?"
    cp -a "${bk}" "${bk}.t2"; sed -i "s/^hash_algorithm=.*/hash_algorithm=MD5/" "${bk}.t2/manifest"
    backup_verify "${bk}.t2" >/dev/null 2>&1; printf "algo_rc=%s\n" "$?"
    cp -a "${bk}" "${bk}.t3"; sed -i "0,/^entry=\([0-9a-f]\{64\}\) .*/s//entry=\1 ..\/..\/etc\/passwd/" "${bk}.t3/manifest"
    backup_verify "${bk}.t3" >/dev/null 2>&1; printf "traversal_rc=%s\n" "$?"
    cp -a "${bk}" "${bk}.t4"; sed -i "/^state_version=/d" "${bk}.t4/manifest"
    backup_verify "${bk}.t4" >/dev/null 2>&1; printf "missingfield_rc=%s\n" "$?"
    cp -a "${bk}" "${bk}.t5"; printf x > "${bk}.t5/payload/config/extra"
    backup_verify "${bk}.t5" >/dev/null 2>&1; printf "extrafile_rc=%s\n" "$?"
    backup_verify "${bk}.nonexistent" >/dev/null 2>&1; printf "nomanifest_rc=%s\n" "$?"
')"
assert_contains "pristine backup verifies" "${out}" "verify_ok_rc=0"
assert_contains "a modified payload file fails hash verification" "${out}" "tampered_rc=1"
assert_contains "hash_algorithm other than SHA-256 is rejected" "${out}" "algo_rc=1"
assert_contains "a manifest path containing .. is rejected" "${out}" "traversal_rc=1"
assert_contains "a manifest missing a required field is rejected" "${out}" "missingfield_rc=1"
assert_contains "a payload file not listed in the manifest is rejected" "${out}" "extrafile_rc=1"
assert_contains "a missing manifest is rejected" "${out}" "nomanifest_rc=1"
section "PRD §32.1: staged, validated, atomic restore"
out="$(run_core "${SBOX_BK}" '
    bk="'"${BK_PATH}"'"
    orig_theme="$(sed -n "s/^theme=//p" "${DEVILS_MINIOS_CONFIG_FILE}")"
    sed -i "s/^theme=.*/theme=nord/" "${DEVILS_MINIOS_CONFIG_FILE}"
    printf "\n# local edit\n" >> "${DEVILS_MINIOS_INSTALL_DIR}/core/core_ui.sh"
    cp "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_CONFIG_FILE}.live"
    backup_restore "${bk}.t1" >/dev/null 2>&1; printf "tampered_restore_rc=%s\n" "$?"
    cmp -s "${DEVILS_MINIOS_CONFIG_FILE}" "${DEVILS_MINIOS_CONFIG_FILE}.live" && printf "live_untouched_after_reject=yes\n"
    backup_restore "${bk}" >/dev/null 2>&1; printf "restore_rc=%s\n" "$?"
    printf "theme_after=%s orig=%s\n" "$(sed -n "s/^theme=//p" "${DEVILS_MINIOS_CONFIG_FILE}")" "${orig_theme}"
    grep -q "# local edit" "${DEVILS_MINIOS_INSTALL_DIR}/core/core_ui.sh" && printf "launcher_edit_present=yes\n" || printf "launcher_edit_present=no\n"
    ls -A "${DEVILS_MINIOS_CONFIG_DIR}" "$(dirname "${DEVILS_MINIOS_INSTALL_DIR}")" | grep -c "restore-staging\|restore-prev" | sed "s/^/staging_leftovers=/"
    validate_config >/dev/null 2>&1; printf "config_valid_rc=%s\n" "$?"
    validate_state >/dev/null 2>&1; printf "state_valid_rc=%s\n" "$?"
')"
assert_contains "restore of a tampered backup is rejected" "${out}" "tampered_restore_rc=1"
assert_contains "a rejected restore leaves live configuration untouched" "${out}" "live_untouched_after_reject=yes"
assert_contains "restore of a valid backup succeeds" "${out}" "restore_rc=0"
assert_contains "restore reactivates the backed-up configuration" "${out}" "theme_after=dracula orig=dracula"
assert_contains "restore reactivates the backed-up launcher files" "${out}" "launcher_edit_present=no"
assert_contains "no staging directories remain after restore" "${out}" "staging_leftovers=0"
assert_contains "restored configuration validates" "${out}" "config_valid_rc=0"
assert_contains "restored state validates" "${out}" "state_valid_rc=0"
section "PRD §32.1: restore refuses a backup whose restored config fails validation (nothing activated)"
SBOX_BK2="$(new_sandbox)"
out="$(run_core "${SBOX_BK2}" '
    load_config >/dev/null 2>&1; load_state >/dev/null 2>&1
    sed -i "s/^theme=.*/theme=bogus-theme/" "${DEVILS_MINIOS_CONFIG_FILE}"
    backup_create >/dev/null 2>&1; bk="${DEVILS_MINIOS_BACKUP_PATH}"
    backup_verify "${bk}" >/dev/null 2>&1; printf "verify_rc=%s\n" "$?"
    printf "\n# local edit\n" >> "${DEVILS_MINIOS_INSTALL_DIR}/core/core_ui.sh"
    backup_restore "${bk}" >/dev/null 2>&1; printf "restore_rc=%s\n" "$?"
    grep -q "# local edit" "${DEVILS_MINIOS_INSTALL_DIR}/core/core_ui.sh" && printf "installation_untouched=yes\n"
    ls -A "$(dirname "${DEVILS_MINIOS_INSTALL_DIR}")" | grep -c "restore-" | sed "s/^/leftovers=/"
')"
assert_contains "a hash-valid backup is still verified structurally" "${out}" "verify_rc=0"
assert_contains "restore fails when the staged configuration does not validate" "${out}" "restore_rc=1"
assert_contains "the active installation is untouched after failed staged validation" "${out}" "installation_untouched=yes"
assert_contains "failed restore cleans up its staging directories" "${out}" "leftovers=0"
section "PRD §32.1: self-update uses the manifest backup"
if grep -q 'backup_create' "${DMOS_PROJECT_ROOT}/core/devils_self_update.sh" \
    && ! grep -q 'pre-update-\$(date' "${DMOS_PROJECT_ROOT}/core/devils_self_update.sh"; then
    pass "_self_update() creates its pre-update backup via backup_create (no bare tar archive)"
else
    fail "_self_update() should create its pre-update backup via backup_create"
fi
assert_true "core_backup.sh is listed in install.sh REQUIRED_CORE_FILES" "$(grep -q '"core_backup"' "${DMOS_PROJECT_ROOT}/install.sh"; printf %s $?)"
section "Self-update success path stages core/ (installation stays startable)"
SBOX_OK="$(new_sandbox)"
FAKE_GIT_OK="$(mktemp -d "${TMPDIR:-/tmp}/dmos-fake-git-XXXXXXXX")"
DMOS_SANDBOXES+=("${FAKE_GIT_OK}")
cat > "${FAKE_GIT_OK}/git" <<'FAKEGIT'
#!/usr/bin/env bash
case "$1" in
    ls-remote) printf 'abc123def456\trefs/tags/v9.9.9\n' ;;
    clone) dest="${*: -1}"; mkdir -p "${dest}"; cp -r "${DMOS_FAKE_RELEASE_SRC}/." "${dest}/"; rm -f "${dest}/SHA256SUMS" ;;
esac
exit 0
FAKEGIT
chmod 755 "${FAKE_GIT_OK}/git"
out="$(run_core "${SBOX_OK}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    export DMOS_FAKE_RELEASE_SRC="${DEVILS_MINIOS_INSTALL_DIR}"
    export PATH="'"${FAKE_GIT_OK}"':${PATH}"
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    ( _self_update ) >/dev/null 2>&1; printf "self_update_rc=%s\n" "$?"
    for f in core_state core_backup core_executor devils_self_update; do
        [[ -f "${DEVILS_MINIOS_INSTALL_DIR}/core/${f}.sh" ]] && printf "core_%s=present\n" "${f}" || printf "core_%s=MISSING\n" "${f}"
    done
    [[ -x "${DEVILS_MINIOS_INSTALL_DIR}/core/core_state.sh" ]] && printf "core_exec_bit=yes\n"
    ls "${DEVILS_MINIOS_BACKUP_DIR:-${DEVILS_MINIOS_CONFIG_DIR}/backups}" 2>/dev/null | grep -c "^pre-update-" | sed "s/^/backups=/"
')"
assert_contains "successful self-update exits 0" "${out}" "self_update_rc=0"
assert_contains "updated installation contains core/core_state.sh" "${out}" "core_core_state=present"
assert_contains "updated installation contains core/core_backup.sh" "${out}" "core_core_backup=present"
assert_contains "updated installation contains core/devils_self_update.sh" "${out}" "core_devils_self_update=present"
assert_contains "staged core files are executable" "${out}" "core_exec_bit=yes"
assert_contains "the update wrote a manifest-format pre-update backup directory" "${out}" "backups=1"
section "PRD-13.13-001: dry-run mode toggle"
SBOXUA="$(new_sandbox)"
out="$(run_module "${SBOXUA}" "update_all" '
    printf "before=%s\n" "${DEVILS_MINIOS_UPDATE_DRY_RUN}"
    _update_all_toggle_dry_run >/dev/null
    printf "after_first_toggle=%s\n" "${DEVILS_MINIOS_UPDATE_DRY_RUN}"
    _update_all_toggle_dry_run >/dev/null
    printf "after_second_toggle=%s\n" "${DEVILS_MINIOS_UPDATE_DRY_RUN}"
')"
assert_contains "dry-run defaults to false" "${out}" "before=false"
assert_contains "toggling dry-run once enables it" "${out}" "after_first_toggle=true"
assert_contains "toggling dry-run twice returns to disabled" "${out}" "after_second_toggle=false"
section "PRD-13.13-001: per-package-manager update argv is ordered and structured (no string-built commands)"
out="$(run_module "${SBOXUA}" "update_all" '
    _update_all_argv_for apt refresh; printf "apt_refresh=%s\n" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
    _update_all_argv_for apt apply; printf "apt_apply=%s\n" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
    _update_all_argv_for pacman apply; printf "pacman_apply=%s\n" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
    _update_all_argv_for apk refresh; printf "apk_refresh=%s\n" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
    _update_all_argv_for xbps apply; printf "xbps_apply=%s\n" "${DEVILS_MINIOS_UPDATE_ARGV[*]}"
    _update_all_argv_for not-a-real-manager apply >/dev/null 2>&1; printf "unknown_manager_rc=%s\n" "$?"
')"
assert_contains "apt refresh argv is (update)" "${out}" "apt_refresh=update"
assert_contains "apt apply argv is (upgrade -y)" "${out}" "apt_apply=upgrade -y"
assert_contains "pacman apply argv is (-Syu --noconfirm)" "${out}" "pacman_apply=-Syu --noconfirm"
assert_contains "apk refresh argv is (update)" "${out}" "apk_refresh=update"
assert_contains "xbps apply argv is (-Suy)" "${out}" "xbps_apply=-Suy"
assert_contains "unrecognized package manager is rejected (status 1), not defaulted" "${out}" "unknown_manager_rc=1"
section "PRD-13.13-001: dry run only previews Termux updates, applies no changes and needs no confirmation"
FAKE_BIN_DRYRUN="$(mktemp -d)"
cat > "${FAKE_BIN_DRYRUN}/pkg" <<'EOS'
#!/usr/bin/env bash
printf 'pkg %s\n' "$*" >> "${DMOS_PKG_CALLS}"
exit 0
EOS
chmod +x "${FAKE_BIN_DRYRUN}/pkg"
CALL_LOG="$(mktemp)"
out="$(run_module "${SBOXUA}" "update_all" '
    export PATH="'"${FAKE_BIN_DRYRUN}"':${PATH}"
    export DMOS_PKG_CALLS="'"${CALL_LOG}"'"
    DEVILS_MINIOS_UPDATE_DRY_RUN=true
    _update_all_termux >/dev/null 2>&1
    printf "termux_dry_run_rc=%s\n" "$?"
')"
assert_contains "dry-run Termux update exits 0 without prompting" "${out}" "termux_dry_run_rc=0"
assert_contains "dry-run Termux update calls list-upgradable (preview only)" "$(cat "${CALL_LOG}")" "list-upgradable"
assert_ne "dry-run Termux update never calls the real upgrade action" "$(grep -c '^pkg upgrade' "${CALL_LOG}" 2>/dev/null || echo 0)" "1"
rm -rf "${FAKE_BIN_DRYRUN}" "${CALL_LOG}"
section "PRD-13.13-001: ordered update of every installed proot distro, one failure does not stop the rest"
SBOXORD="$(new_sandbox)"
mkdir -p "${SBOXORD}/home/.local/share/proot-distro/installed/ubuntu" "${SBOXORD}/home/.local/share/proot-distro/installed/debian"
FAKE_BIN_ORD="$(mktemp -d)"
cat > "${FAKE_BIN_ORD}/proot-distro" <<'EOS'
#!/usr/bin/env bash
# args: login <distro> -- <pkg_mgr> <argv...>
distro="$2"
if [[ "${distro}" == "debian" ]]; then
    exit 1
fi
exit 0
EOS
chmod +x "${FAKE_BIN_ORD}/proot-distro"
out="$(run_module "${SBOXORD}" "update_all" '
    export PATH="'"${FAKE_BIN_ORD}"':${PATH}"
    load_default_config; load_state 2>/dev/null || default_state
    _update_all_installed_proot
' 2>&1)"
assert_contains "ordered update reports ubuntu OK" "${out}" "ubuntu: OK"
assert_contains "ordered update reports debian FAILED without aborting the run" "${out}" "debian: FAILED"
assert_contains "ordered update prints a summary header" "${out}" "Update summary"
rm -rf "${FAKE_BIN_ORD}"
print_summary "test_update_all.sh"
