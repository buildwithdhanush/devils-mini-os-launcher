#!/usr/bin/env bash
# Devil's Mini OS Launcher - Test Harness (helper library, §43.1 - not counted
# in the mandatory 19 test files; provides sandboxing + assertions only).
#
# Sourced (not executed) by every test_*.sh file. Deliberately does NOT set
# -e: individual assertions must be able to fail without aborting the whole
# suite, so run_all.sh can report a complete pass/fail matrix.

# Resolve the project root (parent of test/) once.
if [[ -z "${DMOS_PROJECT_ROOT:-}" ]]; then
    DMOS_TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DMOS_PROJECT_ROOT="$(cd "${DMOS_TEST_LIB_DIR}/../.." && pwd)"
fi
export DMOS_PROJECT_ROOT

# ---------------------------------------------------------------------------
# Counters (per test-file; run_all.sh aggregates across files via exit codes
# and the per-file summary line each file prints on completion).
# ---------------------------------------------------------------------------
DMOS_TESTS_RUN=0
DMOS_TESTS_PASSED=0
DMOS_TESTS_FAILED=0
DMOS_FAILED_NAMES=()

pass() {
    DMOS_TESTS_RUN=$((DMOS_TESTS_RUN + 1))
    DMOS_TESTS_PASSED=$((DMOS_TESTS_PASSED + 1))
    printf '  [PASS] %s\n' "$1"
}

fail() {
    DMOS_TESTS_RUN=$((DMOS_TESTS_RUN + 1))
    DMOS_TESTS_FAILED=$((DMOS_TESTS_FAILED + 1))
    DMOS_FAILED_NAMES+=("$1")
    printf '  [FAIL] %s\n' "$1"
    [[ -n "${2:-}" ]] && printf '         %s\n' "$2"
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        pass "${desc}"
    else
        fail "${desc}" "expected [${expected}] got [${actual}]"
    fi
}

assert_ne() {
    local desc="$1" not_expected="$2" actual="$3"
    if [[ "${not_expected}" != "${actual}" ]]; then
        pass "${desc}"
    else
        fail "${desc}" "did not expect [${actual}]"
    fi
}

assert_true() {
    local desc="$1" status="$2"
    if [[ "${status}" -eq 0 ]]; then
        pass "${desc}"
    else
        fail "${desc}" "exit status was ${status}, expected 0"
    fi
}

assert_false() {
    local desc="$1" status="$2"
    if [[ "${status}" -ne 0 ]]; then
        pass "${desc}"
    else
        fail "${desc}" "exit status was 0, expected non-zero"
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" -eq "${actual}" ]]; then
        pass "${desc}"
    else
        fail "${desc}" "expected exit ${expected} got ${actual}"
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        pass "${desc}"
    else
        fail "${desc}" "expected to find [${needle}]"
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "${haystack}" != *"${needle}"* ]]; then
        pass "${desc}"
    else
        fail "${desc}" "did not expect to find [${needle}]"
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -e "${path}" ]]; then
        pass "${desc}"
    else
        fail "${desc}" "missing: ${path}"
    fi
}

assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -e "${path}" ]]; then
        pass "${desc}"
    else
        fail "${desc}" "should not exist: ${path}"
    fi
}

# ---------------------------------------------------------------------------
# Sandbox management. Every test gets its own throwaway HOME + install dir so
# tests are isolated, deterministic, and never touch the real user profile.
# ---------------------------------------------------------------------------
DMOS_SANDBOXES=()

new_sandbox() {
    local sbox
    sbox="$(mktemp -d "${TMPDIR:-/tmp}/dmos-test-XXXXXXXX")"
    mkdir -p "${sbox}/home" "${sbox}/usr/opt/devils-minios" "${sbox}/usr/bin"
    cp -r "${DMOS_PROJECT_ROOT}/modules" "${sbox}/usr/opt/devils-minios/"
    cp -r "${DMOS_PROJECT_ROOT}/core" "${sbox}/usr/opt/devils-minios/"
    cp -r "${DMOS_PROJECT_ROOT}/data" "${sbox}/usr/opt/devils-minios/"
    cp "${DMOS_PROJECT_ROOT}/devils-minios.sh" "${sbox}/usr/opt/devils-minios/"
    chmod 755 "${sbox}/usr/opt/devils-minios/devils-minios.sh"
    find "${sbox}/usr/opt/devils-minios/modules" -name '*.sh' -exec chmod 755 {} \;
    find "${sbox}/usr/opt/devils-minios/core" -name '*.sh' -exec chmod 755 {} \;
    DMOS_SANDBOXES+=("${sbox}")
    printf '%s' "${sbox}"
}

cleanup_sandboxes() {
    local s
    for s in "${DMOS_SANDBOXES[@]:-}"; do
        [[ -n "${s}" && -d "${s}" ]] && rm -rf "${s}"
    done
    DMOS_SANDBOXES=()
}
trap cleanup_sandboxes EXIT

# run_core <sandbox> <bash-snippet>
# Sources core.sh (only) inside the sandbox's isolated HOME/PREFIX and
# evaluates the snippet. Echoes combined stdout+stderr; caller reads $? via
# the wrapper variables below (bash -s exits with the snippet's own status).
run_core() {
    local sbox="$1" script="$2"
    HOME="${sbox}/home" PREFIX="${sbox}/usr" \
    DEVILS_MINIOS_INSTALL_DIR="${sbox}/usr/opt/devils-minios" \
    XDG_CACHE_HOME="${sbox}/home/.cache" \
        bash -s 2>&1 <<SCRIPT
set -uo pipefail
source "\${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"
set +e
${script}
SCRIPT
}

# run_core_status <sandbox> <bash-snippet>
# Same as run_core but only echoes the final exit status (as text) - useful
# when the snippet's own output does not matter.
run_core_status() {
    local sbox="$1" script="$2"
    HOME="${sbox}/home" PREFIX="${sbox}/usr" \
    DEVILS_MINIOS_INSTALL_DIR="${sbox}/usr/opt/devils-minios" \
    XDG_CACHE_HOME="${sbox}/home/.cache" \
        bash -s >/dev/null 2>&1 <<SCRIPT
set -uo pipefail
source "\${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"
set +e
${script}
SCRIPT
    printf '%s' "$?"
}

# run_module <sandbox> <module-name> <bash-snippet>
# Sources core.sh then the named feature module, then evaluates the snippet.
run_module() {
    local sbox="$1" module="$2" script="$3"
    HOME="${sbox}/home" PREFIX="${sbox}/usr" \
    DEVILS_MINIOS_INSTALL_DIR="${sbox}/usr/opt/devils-minios" \
    XDG_CACHE_HOME="${sbox}/home/.cache" \
        bash -s 2>&1 <<SCRIPT
set -uo pipefail
source "\${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"
source "\${DEVILS_MINIOS_INSTALL_DIR}/modules/${module}.sh"
set +e
${script}
SCRIPT
}

# section <title> - visual separator only, not a test.
section() {
    printf '\n-- %s --\n' "$1"
}

# print_summary <test-file-name> - prints the aggregate and returns the
# appropriate exit code (0 all passed, 1 otherwise). run_all.sh greps this.

# Cross-file integration group kept here so test_core.sh remains below the PRD file-size limit.
run_platform_and_core_boundary_tests() {
    section "PRD §9/§10: detect_platform architecture, API-floor and non-Termux diagnostics-only gating"
    SBOXPLAT="$(new_sandbox)"
    out="$(run_core "${SBOXPLAT}" '
        mkdir -p "$(get_config_dir)/logs"
        uname() { if [[ "$1" == "-m" ]]; then printf "riscv64\n"; else printf "Linux\n"; fi; }
        ( detect_platform ) >/tmp/dmos_arch_out.$$ 2>&1; rc=$?
        printf "unsupported_arch_rc=%s\n" "${rc}"
        grep -q "E900" /tmp/dmos_arch_out.$$ && printf "unsupported_arch_e900=yes\n" || printf "unsupported_arch_e900=no\n"
        rm -f /tmp/dmos_arch_out.$$
        unset -f uname
    ')"
    assert_contains "PRD-9-003: unsupported architecture aborts with exit status 5" "${out}" "unsupported_arch_rc=5"
    assert_contains "PRD-9-003: unsupported architecture is reported as registered code E900" "${out}" "unsupported_arch_e900=yes"

    SBOXAPI="$(new_sandbox)"
    out="$(run_core "${SBOXAPI}" '
        mkdir -p "$(get_config_dir)/logs"
        uname() { if [[ "$1" == "-m" ]]; then printf "aarch64\n"; else printf "Linux\n"; fi; }
        getprop() { case "$1" in ro.build.version.sdk) printf "24\n" ;; ro.build.version.release) printf "7.0\n" ;; esac; }
        ( detect_platform ) >/tmp/dmos_api_out.$$ 2>&1; rc=$?
        printf "below_floor_rc=%s\n" "${rc}"
        grep -q "E900" /tmp/dmos_api_out.$$ && printf "below_floor_e900=yes\n" || printf "below_floor_e900=no\n"
        rm -f /tmp/dmos_api_out.$$
        getprop() { case "$1" in ro.build.version.sdk) printf "29\n" ;; ro.build.version.release) printf "10\n" ;; esac; }
        ( detect_platform ) >/tmp/dmos_api_ok.$$ 2>&1; printf "at_floor_rc=%s\n" "$?"
        rm -f /tmp/dmos_api_ok.$$
        unset -f uname getprop
    ')"
    assert_contains "PRD-9-001: Android API below 29 aborts with exit status 5" "${out}" "below_floor_rc=5"
    assert_contains "PRD-9-001: below-floor API abort is reported as registered code E900" "${out}" "below_floor_e900=yes"
    assert_contains "PRD-9-001: Android API 29 (the supported floor) is accepted" "${out}" "at_floor_rc=0"

    SBOXNONTMX="$(new_sandbox)"
    out="$(run_core "${SBOXNONTMX}" '
        mkdir -p "$(get_config_dir)/logs"
        uname() { if [[ "$1" == "-m" ]]; then printf "x86_64\n"; else printf "Linux\n"; fi; }
        unset PREFIX
        detect_platform >/tmp/dmos_nontmx_out.$$ 2>&1
        printf "platform=%s\n" "${DEVILS_MINIOS_PLATFORM}"
        printf "safe_mode=%s\n" "${DEVILS_MINIOS_SAFE_MODE}"
        grep -q "E900" /tmp/dmos_nontmx_out.$$ && printf "nontermux_e900=yes\n" || printf "nontermux_e900=no\n"
        rm -f /tmp/dmos_nontmx_out.$$
        unset -f uname
    ')"
    assert_contains "PRD-10-002: non-Termux host is detected (not termux)" "${out}" "platform=linux"
    assert_contains "PRD-10-002: unsupported host combination degrades to Safe/diagnostics-only mode rather than a hard crash" "${out}" "safe_mode=true"
    assert_contains "PRD-10-002: unsupported host combination is reported as registered code E900" "${out}" "nontermux_e900=yes"

    section "PRD-11-002: core.sh owns platform/config/logging/security/recovery/UI; features stay modular"
    out="$(run_core "${SBOXPLAT}" '
        for fn in write_log_file detect_platform validate_path execute_structured \
                  save_config load_state nuclear_reset backup_create install_proot_package apply_theme; do
            type "${fn}" >/dev/null 2>&1 && printf "%s=ok\n" "${fn}" || printf "%s=missing\n" "${fn}"
        done
        # Feature modules (§12/§14) are a distinct, non-overlapping set from the
        # internal core_*.sh split files core.sh owns.
        overlap=no
        for mod in "${DEVILS_MINIOS_FEATURE_MODULES[@]}"; do
            for part in "${_DEVILS_MINIOS_CORE_SPLIT_FILES[@]}"; do
                [[ "${mod}" == "${part}" ]] && overlap=yes
            done
        done
        printf "feature_module_count=%s\n" "${#DEVILS_MINIOS_FEATURE_MODULES[@]}"
        printf "modules_dir_file_count=%s\n" "$(find "${DEVILS_MINIOS_INSTALL_DIR}/modules" -maxdepth 1 -name "*.sh" | wc -l)"
        printf "core_split_overlaps_feature_modules=%s\n" "${overlap}"
    ')"
    assert_contains "core.sh owns logging (write_log_file)" "${out}" "write_log_file=ok"
    assert_contains "core.sh owns platform detection (detect_platform)" "${out}" "detect_platform=ok"
    assert_contains "core.sh owns security (validate_path)" "${out}" "validate_path=ok"
    assert_contains "core.sh owns the structured executor (execute_structured)" "${out}" "execute_structured=ok"
    assert_contains "core.sh owns configuration (save_config)" "${out}" "save_config=ok"
    assert_contains "core.sh owns persistent state (load_state)" "${out}" "load_state=ok"
    assert_contains "core.sh owns recovery (nuclear_reset)" "${out}" "nuclear_reset=ok"
    assert_contains "core.sh owns backup (backup_create)" "${out}" "backup_create=ok"
    assert_contains "core.sh owns the data catalog (install_proot_package)" "${out}" "install_proot_package=ok"
    assert_contains "core.sh owns UI (apply_theme)" "${out}" "apply_theme=ok"
    assert_contains "13 dispatchable feature modules are registered (the 14th module file is core.sh, the loader itself)" "${out}" "feature_module_count=13"
    assert_contains "modules/ contains exactly 14 module files total (§12, D1)" "${out}" "modules_dir_file_count=14"
    assert_contains "core split files and feature modules are disjoint sets (features stay modular)" "${out}" "core_split_overlaps_feature_modules=no"

    section "PRD-11-002: a missing required core component aborts startup instead of running with a hole in core ownership"
    SBOXMISSCORE="$(new_sandbox)"
    rm -f "${SBOXMISSCORE}/usr/opt/devils-minios/core/core_security.sh"
    out="$(HOME="${SBOXMISSCORE}/home" PREFIX="${SBOXMISSCORE}/usr" \
        DEVILS_MINIOS_INSTALL_DIR="${SBOXMISSCORE}/usr/opt/devils-minios" \
        XDG_CACHE_HOME="${SBOXMISSCORE}/home/.cache" \
        bash -c 'source "${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"' 2>&1; printf 'rc=%s' "$?")"
    assert_contains "missing core_security.sh is reported by name" "${out}" "Required core component missing: core_security.sh"
    assert_contains "missing core component aborts (does not continue half-initialized)" "${out}" "rc=1"
}

print_summary() {
    local name="$1"
    printf '\n%s: %d run, %d passed, %d failed\n' "${name}" "${DMOS_TESTS_RUN}" "${DMOS_TESTS_PASSED}" "${DMOS_TESTS_FAILED}"
    if [[ ${DMOS_TESTS_FAILED} -gt 0 ]]; then
        printf 'Failed assertions in %s:\n' "${name}"
        printf '  - %s\n' "${DMOS_FAILED_NAMES[@]}"
        return 1
    fi
    return 0
}
