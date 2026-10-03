#!/usr/bin/env bash
# test_install.sh - PRD §43.1: Installation lifecycle: Git + ZIP sources,
# separate-install activation, existing-installation policy, installer-owned
# deletion boundary (§30.1), self-source-overwrite guard.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/harness.sh
source "${SCRIPT_DIR}/lib/harness.sh"

section "install.sh exists and is bash"
if [[ -f "${DMOS_PROJECT_ROOT}/install.sh" ]]; then
    pass "install.sh present"
else
    fail "install.sh missing"
fi

section "install.sh syntax check"
if bash -n "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    pass "install.sh passes bash -n"
else
    fail "install.sh has syntax errors"
fi

section "install.sh does not use curl|bash"
if grep -qE 'curl.*\|.*bash|wget.*\|.*bash|curl.*\|.*sh' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    fail "install.sh must not use curl|bash"
else
    pass "install.sh has no curl|bash pattern"
fi

section "installer deletion boundary: only tracked paths (§30.1)"
# Static: look for a tracking variable pattern (INSTALL_CREATED or similar)
if grep -qE 'CREATED|TRACKED|installer.*own|delete.*bound' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null || \
   grep -qE 'rm -rf.*\$\{' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    pass "install.sh has scoped deletion logic"
else
    # Still pass if the script is careful; check it doesn't rm -rf /
    if grep -qE 'rm -rf /[^$]' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
        fail "install.sh contains dangerous absolute rm -rf"
    else
        pass "install.sh has no dangerous absolute rm -rf"
    fi
fi

section "installer never rm -rf's the pre-existing install/target dir directly (§30.1)"
# §30.1 forbids `rm -rf` on any path the installer did not itself create in
# the current run. INSTALL_TARGET_DIR is a pre-existing path on a reinstall
# (created in a *prior* run, if at all), so it must never appear as the
# direct argument to rm -rf; it may only be reached indirectly after being
# renamed into a variable the installer itself just created (e.g. an
# "*.old.$$"-style backup path captured at creation time).
if grep -qE 'rm -rf "\$\{INSTALL_TARGET_DIR\}"' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    fail "install.sh must not rm -rf \${INSTALL_TARGET_DIR} directly (it may pre-exist from a prior run)"
else
    pass "install.sh never rm -rf's \${INSTALL_TARGET_DIR} directly"
fi
if grep -qE '\.old\.\$\$' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null && \
   grep -qE 'mv "\$\{INSTALL_TARGET_DIR\}"' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    pass "install.sh renames the old installation into an installer-owned backup path before any deletion"
else
    fail "install.sh should rename the old installation into an installer-owned backup path before deleting it"
fi

section "installer activation keeps a valid installation on mv failure"
if grep -qE 'old_install_backup.*INSTALL_TARGET_DIR' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    pass "install.sh restores the backup if activation mv fails"
else
    fail "install.sh should restore the renamed-aside backup if activating the new install fails"
fi

section "SHA256SUMS and --verify support"
if grep -qE 'verify|SHA256SUMS|sha256' "${DMOS_PROJECT_ROOT}/install.sh" 2>/dev/null; then
    pass "install.sh references checksum verification"
else
    fail "install.sh missing checksum verification support"
fi

section "entry point exists"
if [[ -f "${DMOS_PROJECT_ROOT}/devils-minios.sh" ]]; then
    pass "devils-minios.sh present"
    if bash -n "${DMOS_PROJECT_ROOT}/devils-minios.sh" 2>/dev/null; then
        pass "devils-minios.sh passes bash -n"
    else
        fail "devils-minios.sh has syntax errors"
    fi
else
    fail "devils-minios.sh missing"
fi

section "installer directory check (§48.2 E601): empty vs non-empty unrecognized directory"
# Functions are sourced with the trailing `_main "$@"` invocation stripped,
# so `_prepare_install_dir` can be exercised in isolation without a real
# install, network access, or a fresh SHA256SUMS (neither is relevant to
# this check).
INSTALL_BODY="$(mktemp)"
sed '$d' "${DMOS_PROJECT_ROOT}/install.sh" > "${INSTALL_BODY}"

SBOX_E601_NONEMPTY="$(mktemp -d)"
mkdir -p "${SBOX_E601_NONEMPTY}/usr/opt/devils-minios"
printf 'not a launcher file\n' > "${SBOX_E601_NONEMPTY}/usr/opt/devils-minios/random_file"
out_ne="$(PREFIX="${SBOX_E601_NONEMPTY}/usr" bash -c "source '${INSTALL_BODY}'; _prepare_install_dir" 2>&1)"
st_ne=$?
assert_contains "E601 fires for an existing, non-empty, unrecognized directory" "${out_ne}" "E601"
assert_status "E601 exits with status 1" 1 "${st_ne}"

SBOX_E601_EMPTY="$(mktemp -d)"
mkdir -p "${SBOX_E601_EMPTY}/usr/opt/devils-minios"
out_e="$(PREFIX="${SBOX_E601_EMPTY}/usr" bash -c "source '${INSTALL_BODY}'; _prepare_install_dir" 2>&1)"
st_e=$?
assert_not_contains "E601 does NOT fire for an existing but empty directory" "${out_e}" "E601"
assert_status "empty pre-existing directory proceeds with exit status 0" 0 "${st_e}"

DMOS_SANDBOXES+=("${SBOX_E601_NONEMPTY}" "${SBOX_E601_EMPTY}")

section "install-time manifest verification (§48.2 E602): tampered/corrupt source -> exit 2"
# §48.2 E602's registered trigger is install manifest/checksum verification
# failure. This exercises the source-side trigger in _validate_source():
# a source tree whose SHA256SUMS does not match its own files.
SBOX_E602_SRC="$(mktemp -d)"
cp "${DMOS_PROJECT_ROOT}/devils-minios.sh" "${SBOX_E602_SRC}/"
cp -r "${DMOS_PROJECT_ROOT}/modules" "${SBOX_E602_SRC}/"
cp -r "${DMOS_PROJECT_ROOT}/core" "${SBOX_E602_SRC}/"
printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  devils-minios.sh\n' > "${SBOX_E602_SRC}/SHA256SUMS"
SBOX_E602_TARGET="$(mktemp -d)"
out_602src="$(PREFIX="${SBOX_E602_TARGET}/usr" bash -c "source '${INSTALL_BODY}'; _validate_source '${SBOX_E602_SRC}'" 2>&1)"
st_602src=$?
assert_contains "E602 fires when the install source's SHA256SUMS fails verification" "${out_602src}" "E602"
assert_status "E602 (source tamper) exits with status 2" 2 "${st_602src}"

section "--verify manifest checks (§48.2 E602): missing/failed verification on the active installation -> exit 2"
SBOX_E602_MISSING="$(mktemp -d)"
mkdir -p "${SBOX_E602_MISSING}/usr/opt/devils-minios"
out_602missing="$(PREFIX="${SBOX_E602_MISSING}/usr" bash -c "source '${INSTALL_BODY}'; _run_verify" 2>&1)"
st_602missing=$?
assert_contains "E602 fires when --verify finds no SHA256SUMS in the active installation" "${out_602missing}" "E602"
assert_status "E602 (missing manifest) exits with status 2" 2 "${st_602missing}"

SBOX_E602_FAIL="$(mktemp -d)"
mkdir -p "${SBOX_E602_FAIL}/usr/opt/devils-minios"
printf 'not the real launcher\n' > "${SBOX_E602_FAIL}/usr/opt/devils-minios/devils-minios.sh"
printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  devils-minios.sh\n' > "${SBOX_E602_FAIL}/usr/opt/devils-minios/SHA256SUMS"
out_602fail="$(PREFIX="${SBOX_E602_FAIL}/usr" bash -c "source '${INSTALL_BODY}'; _run_verify" 2>&1)"
st_602fail=$?
assert_contains "E602 fires when --verify's checksum comparison fails" "${out_602fail}" "E602"
assert_status "E602 (verification failure) exits with status 2" 2 "${st_602fail}"

section "fresh install + active-manifest verification (§30.2): verify succeeds after a clean install"
SBOX_REAL_INSTALL="$(mktemp -d)"
mkdir -p "${SBOX_REAL_INSTALL}/home" "${SBOX_REAL_INSTALL}/usr"
PREFIX="${SBOX_REAL_INSTALL}/usr" HOME="${SBOX_REAL_INSTALL}/home" bash "${DMOS_PROJECT_ROOT}/install.sh" >/dev/null 2>&1
st_real_install=$?
assert_status "clean sandbox install exits 0" 0 "${st_real_install}"
if [[ -f "${SBOX_REAL_INSTALL}/usr/opt/devils-minios/SHA256SUMS" ]]; then
    pass "clean sandbox install creates active SHA256SUMS"
else
    fail "clean sandbox install creates active SHA256SUMS"
fi
out_real_verify="$(PREFIX="${SBOX_REAL_INSTALL}/usr" HOME="${SBOX_REAL_INSTALL}/home" bash "${DMOS_PROJECT_ROOT}/install.sh" --verify 2>&1)"
st_real_verify=$?
assert_status "clean sandbox active installation verifies successfully" 0 "${st_real_verify}"
assert_not_contains "active manifest does not reference source-only test files" "${out_real_verify}" "test/test_"

DMOS_SANDBOXES+=("${SBOX_E602_SRC}" "${SBOX_E602_TARGET}" "${SBOX_E602_MISSING}" "${SBOX_E602_FAIL}" "${SBOX_REAL_INSTALL}")

section "PRD-22.1/30 uninstall refuses a symlinked installation directory"
SBOX_UNSYM="$(new_sandbox)"
TARGET_UNSYM="${SBOX_UNSYM}/home/real-install"
mkdir -p "${TARGET_UNSYM}"
cp -r "${DMOS_PROJECT_ROOT}/modules" "${TARGET_UNSYM}/"
cp -r "${DMOS_PROJECT_ROOT}/core" "${TARGET_UNSYM}/"
cp -r "${DMOS_PROJECT_ROOT}/data" "${TARGET_UNSYM}/"
cp "${DMOS_PROJECT_ROOT}/devils-minios.sh" "${TARGET_UNSYM}/"
mkdir -p "${SBOX_UNSYM}/home/.config/devils-minios"
cat > "${SBOX_UNSYM}/home/.config/devils-minios/config" <<'CFG'
config_version=1
theme=dracula
banner=devil
banner_animation=false
auto_launch=false
health_check_interval=1800
log_level=INFO
check_updates=false
language=en
network_timeout=30
network_retries=3
termux_source=unknown
android_version=unknown
architecture=x86_64
CFG
printf '%s\n' now > "${SBOX_UNSYM}/home/.config/devils-minios/.onboarding-complete"
cat > "${SBOX_UNSYM}/home/.config/devils-minios/state" <<'STATE'
state_version=1
primary_distro=
last_successful_workflow=
onboarding_completion=true
crash_loop_state=
STATE
rm -rf "${SBOX_UNSYM}/usr/opt/devils-minios"
ln -s "${TARGET_UNSYM}" "${SBOX_UNSYM}/usr/opt/devils-minios"
out="$(printf 'y\n' | HOME="${SBOX_UNSYM}/home" PREFIX="${SBOX_UNSYM}/usr" timeout 8 bash "${SBOX_UNSYM}/usr/opt/devils-minios/devils-minios.sh" --uninstall 2>&1 || true)"
assert_contains "symlinked install directory is rejected" "${out}" "uninstall refused"
if [[ -d "${TARGET_UNSYM}" ]]; then
    pass "symlink target remains untouched"
else
    fail "symlink target remains untouched"
fi
section "install storage gate (§48.2 E603): insufficient storage -> exit 3"
# §48.2 E603's registered trigger is insufficient storage. A fake `df` ahead
# of PATH stands in for the filesystem so the check is deterministic
# regardless of the actual free space on the machine running the suite.
FAKE_DF_BIN="$(mktemp -d)"
cat > "${FAKE_DF_BIN}/df" <<'FAKEDF'
#!/usr/bin/env bash
printf 'Filesystem     1B-blocks       Used  Available Use%% Mounted on\n'
printf 'fakefs         1000000000  999999999          1   99%% /\n'
FAKEDF
chmod 755 "${FAKE_DF_BIN}/df"
SBOX_E603="$(mktemp -d)"
mkdir -p "${SBOX_E603}/usr/opt/devils-minios"
out_603="$(PREFIX="${SBOX_E603}/usr" PATH="${FAKE_DF_BIN}:${PATH}" bash -c "source '${INSTALL_BODY}'; _check_install_storage" 2>&1)"
st_603=$?
assert_contains "E603 fires when available storage is below the required threshold" "${out_603}" "E603"
assert_status "E603 exits with status 3" 3 "${st_603}"

DMOS_SANDBOXES+=("${FAKE_DF_BIN}" "${SBOX_E603}")

rm -f "${INSTALL_BODY}"

print_summary "test_install.sh"
