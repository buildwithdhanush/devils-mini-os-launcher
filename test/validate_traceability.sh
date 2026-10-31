#!/usr/bin/env bash
# PRD-6.2 §43.5 traceability matrix structure validator.
# Development/release validation only; not loaded by the launcher runtime.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT}/docs/TRACEABILITY.md"
[[ -f "${MATRIX}" ]] || { printf 'FAIL: missing %s\n' "${MATRIX}" >&2; exit 1; }

COUNTS="$(awk -F'|' '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
BEGIN {
    expected="Requirement ID|PRD Section|Requirement|Rationale|Module|Implementation Artifact|Test Reference|Manual Acceptance|Release Gate|Evidence|Status|Accountable Owner|Verification Owner|Approval Authority"
}
/^\| Requirement ID \|/ {
    headers++
    actual=""
    for (i=2; i<NF; i++) {
        if (i>2) actual=actual "|"
        actual=actual trim($i)
    }
    if (actual != expected) {
        printf "FAIL: traceability header does not match the §43.5.2 field list\n" > "/dev/stderr"
        printf "Found: %s\n", actual > "/dev/stderr"
        bad=1
    }
}
/^\| PRD-/ {
    rows++
    if (NF != 16) {
        printf "FAIL: row %d has %d columns, expected 14: %s\n", NR, NF-2, $0 > "/dev/stderr"
        bad=1
        next
    }
    id=trim($2)
    if (id !~ /^PRD-[0-9]+(\.[0-9]+)?-[0-9][0-9][0-9]$/) {
        printf "FAIL: nonconforming requirement ID at line %d: %s\n", NR, id > "/dev/stderr"
        bad=1
    }
    if (seen[id]++) {
        printf "FAIL: duplicate requirement ID: %s\n", id > "/dev/stderr"
        bad=1
    }
    for (i=2; i<=15; i++) {
        if (trim($i)=="") {
            printf "FAIL: blank field at row %s, column %d\n", id, i-1 > "/dev/stderr"
            bad=1
        }
    }
    status=trim($12)
    if (status=="Verified") verified++
    else if (status=="Partial") partial++
    else if (status=="Not Verified") not_verified++
    else {
        printf "FAIL: invalid status for %s: %s\n", id, status > "/dev/stderr"
        bad=1
    }
}
END {
    if (headers != 1) { printf "FAIL: expected one matrix header, found %d\n", headers > "/dev/stderr"; bad=1 }
    if (rows < 1) { printf "FAIL: no requirement rows found\n" > "/dev/stderr"; bad=1 }
    printf "%d %d %d %d %d\n", rows, verified, partial, not_verified, bad
}' "${MATRIX}")" || { printf 'FAIL: matrix parser failed\n' >&2; exit 1; }
read -r ROWS VERIFIED PARTIAL NOT_VERIFIED PARSE_BAD <<<"${COUNTS}"
[[ "${PARSE_BAD}" == 0 ]] || exit 1

SUMMARY_LINE="$(grep -F '**Current totals:' "${MATRIX}" || true)"
[[ -n "${SUMMARY_LINE}" ]] || { printf 'FAIL: missing Current totals summary\n' >&2; exit 1; }
[[ "$(printf '%s\n' "${SUMMARY_LINE}" | wc -l | tr -d ' ')" == 1 ]] || {
    printf 'FAIL: expected one Current totals line\n' >&2; exit 1;
}
REPORTED_ROWS="$(printf '%s\n' "${SUMMARY_LINE}" | sed -nE 's/.*Current totals: ([0-9]+) rows.*/\1/p')"
REPORTED_VERIFIED="$(printf '%s\n' "${SUMMARY_LINE}" | sed -nE 's/.*— ([0-9]+) Verified,.*/\1/p')"
REPORTED_PARTIAL="$(printf '%s\n' "${SUMMARY_LINE}" | sed -nE 's/.* ([0-9]+) Partial,.*/\1/p')"
REPORTED_NOT_VERIFIED="$(printf '%s\n' "${SUMMARY_LINE}" | sed -nE 's/.* ([0-9]+) Not Verified\..*/\1/p')"
ACTUAL="${ROWS} ${VERIFIED} ${PARTIAL} ${NOT_VERIFIED}"
REPORTED="${REPORTED_ROWS:-missing} ${REPORTED_VERIFIED:-missing} ${REPORTED_PARTIAL:-missing} ${REPORTED_NOT_VERIFIED:-missing}"
[[ "${ACTUAL}" == "${REPORTED}" ]] || {
    printf 'FAIL: totals mismatch; table=%s summary=%s\n' "${ACTUAL}" "${REPORTED}" >&2
    exit 1
}

printf 'PASS: traceability schema valid: %s rows; %s unique IDs; %s Verified, %s Partial, %s Not Verified.\n' \
    "${ROWS}" "${ROWS}" "${VERIFIED}" "${PARTIAL}" "${NOT_VERIFIED}"
