#!/usr/bin/env bash
# test/run_all.sh - PRD §43.2 harness (not counted in the 19 mandatory files).
# Discovers and executes all 19 mandatory test files; reports aggregate result.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export DMOS_PROJECT_ROOT="${PROJECT_ROOT}"

MANDATORY=(
    test_core.sh
    test_utils.sh
    test_security.sh
    test_linux_env.sh
    test_file_mgr.sh
    test_termux_apps.sh
    test_proot_apps.sh
    test_android_tools.sh
    test_workspace.sh
    test_health_check.sh
    test_log_viewer.sh
    test_customize.sh
    test_system_tools.sh
    test_system_info.sh
    test_update_all.sh
    test_settings.sh
    test_integration.sh
    test_install.sh
    test_report_generator.sh
)

TOTAL_FILES=${#MANDATORY[@]}
PASSED_FILES=0
FAILED_FILES=0
TOTAL_RUN=0
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_LIST=()

printf '========================================\n'
printf ' Devil'\''s Mini OS Launcher — Test Suite\n'
printf ' %d mandatory test files\n' "${TOTAL_FILES}"
printf '========================================\n\n'

for f in "${MANDATORY[@]}"; do
    path="${SCRIPT_DIR}/${f}"
    if [[ ! -f "${path}" ]]; then
        printf '[MISSING] %s\n' "${f}"
        FAILED_FILES=$((FAILED_FILES + 1))
        FAILED_LIST+=("${f} (missing)")
        continue
    fi
    printf '>>> Running %s\n' "${f}"
    # Preserve the test process exit status. A passing-looking summary must
    # never override a non-zero process exit (e.g. a crash after assertions).
    output="$(bash "${path}" 2>&1)"
    test_status=$?
    printf '%s\n' "${output}"

    # Parse summary line: "name: N run, M passed, K failed"
    summary_line="$(printf '%s\n' "${output}" | grep -E '^[a-z_]+\.sh: [0-9]+ run,' | tail -1 || true)"
    if [[ -n "${summary_line}" ]]; then
        run_n="$(printf '%s' "${summary_line}" | sed -E 's/.*: ([0-9]+) run,.*/\1/')"
        pass_n="$(printf '%s' "${summary_line}" | sed -E 's/.*, ([0-9]+) passed,.*/\1/')"
        fail_n="$(printf '%s' "${summary_line}" | sed -E 's/.*, ([0-9]+) failed.*/\1/')"
        TOTAL_RUN=$((TOTAL_RUN + run_n))
        TOTAL_PASS=$((TOTAL_PASS + pass_n))
        TOTAL_FAIL=$((TOTAL_FAIL + fail_n))
        if [[ "${test_status}" -eq 0 && "${fail_n}" -eq 0 ]]; then
            PASSED_FILES=$((PASSED_FILES + 1))
            printf '[PASS] %s (%s assertions)\n\n' "${f}" "${pass_n}"
        else
            FAILED_FILES=$((FAILED_FILES + 1))
            if [[ "${test_status}" -ne 0 ]]; then
                FAILED_LIST+=("${f} (exit ${test_status})")
                printf '[FAIL] %s (%s failed; process exit %s)\n\n' "${f}" "${fail_n}" "${test_status}"
            else
                FAILED_LIST+=("${f}")
                printf '[FAIL] %s (%s failed)\n\n' "${f}" "${fail_n}"
            fi
        fi
    else
        # A summary fallback is valid only when the process itself exited 0.
        if [[ "${test_status}" -eq 0 ]] && printf '%s\n' "${output}" | grep -q '0 failed'; then
            PASSED_FILES=$((PASSED_FILES + 1))
            printf '[PASS] %s (summary parse fallback)\n\n' "${f}"
        else
            FAILED_FILES=$((FAILED_FILES + 1))
            FAILED_LIST+=("${f} (exit ${test_status}; no valid summary / failures)")
            printf '[FAIL] %s (exit %s; no valid summary / failures)\n\n' "${f}" "${test_status}"
        fi
    fi
done

printf '========================================\n'
printf ' SUMMARY\n'
printf '========================================\n'
printf 'Files:  %d / %d passed\n' "${PASSED_FILES}" "${TOTAL_FILES}"
printf 'Assertions: %d run, %d passed, %d failed\n' "${TOTAL_RUN}" "${TOTAL_PASS}" "${TOTAL_FAIL}"
if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
    printf 'Failed files:\n'
    printf '  - %s\n' "${FAILED_LIST[@]}"
fi
printf '========================================\n'

# Ensure report exists (report generator writes it)
if [[ ! -f "${PROJECT_ROOT}/data/reports/report.md" ]]; then
    bash "${SCRIPT_DIR}/test_report_generator.sh" >/dev/null 2>&1 || true
fi

if [[ ${FAILED_FILES} -eq 0 && ${TOTAL_FAIL} -eq 0 ]]; then
    printf 'ALL TESTS PASSED\n'
    exit 0
else
    printf 'SOME TESTS FAILED\n'
    exit 1
fi
