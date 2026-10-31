#!/usr/bin/env bash
# PRD-6.2 master test runner for Devil's Mini OS Launcher.
# Read-only with respect to the active/installed launcher. It extracts the
# supplied source ZIP to a new, private test workspace and tests that copy.
# The active/installed launcher is never modified. If ShellCheck is absent,
# package installation occurs only after explicit interactive user approval.
set -uo pipefail
umask 077

readonly ZIP_NAME='devils-mini-os-launcher-PRD62-shellcheck-patch-2026-10-25.zip'
readonly EXPECTED_ZIP_SHA256='3684d00b9d6d791bb7ee9bddc583c8e60784cfaacf94a1b07b3fa459470ef930'
readonly EXPECTED_ROOT='devils-mini-os-launcher-Testing'
readonly DEFAULT_TIMEOUT_SECONDS=1800
readonly DOWNLOAD_DIR="${HOME}/storage/downloads"
readonly ZIP_PATH="${DMOS_TEST_ZIP:-${DOWNLOAD_DIR}/${ZIP_NAME}}"
readonly RUN_BASE="${DMOS_TEST_BASE:-${HOME}/devils-minios-test-runs}"
readonly TEST_TIMEOUT_SECONDS="${DMOS_TEST_TIMEOUT:-${DEFAULT_TIMEOUT_SECONDS}}"

CHECK_LABELS=()
CHECK_STATES=()
CHECK_CODES=()
CHECK_LOGS=()
ROOT=''
WORK=''
LOG_DIR=''
MASTER_LOG=''
REPORT=''
SHELLCHECK_INSTALL_APPROVED='NO'
SHELLCHECK_INSTALL_RESULT='not required'

say() { printf '%s\n' "$*"; }

usage_error() {
    say "ERROR: $*"
    say 'No launcher installation was changed.'
    exit 2
}

for required in bash unzip sha256sum timeout find awk grep sed sort wc tail tee date tr; do
    command -v "$required" >/dev/null 2>&1 || usage_error "required command missing: $required"
done

(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )) \
    || usage_error "Bash 4.3+ required; found ${BASH_VERSION}"

[[ -f "$ZIP_PATH" ]] || usage_error "source ZIP not found: $ZIP_PATH (put ${ZIP_NAME} in Termux Downloads or set DMOS_TEST_ZIP)"
[[ "$TEST_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] && (( TEST_TIMEOUT_SECONDS >= 60 )) \
    || usage_error 'DMOS_TEST_TIMEOUT must be an integer >= 60 seconds'

STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
WORK="${RUN_BASE}/run-${STAMP}-$$"
[[ ! -e "$WORK" ]] || usage_error "refusing to overwrite existing test workspace: $WORK"
mkdir -p "$RUN_BASE" || usage_error "cannot create test base directory: $RUN_BASE"
mkdir -m 700 "$WORK" "$WORK/source" "$WORK/logs" || usage_error "cannot create fresh test workspace: $WORK"
LOG_DIR="$WORK/logs"
MASTER_LOG="$WORK/master-console.log"
REPORT="$WORK/master-test-report.md"
exec > >(tee -a "$MASTER_LOG") 2>&1

say '============================================================'
say " Devil's Mini OS Launcher — PRD-6.2 automated master test"
say " Started (UTC): ${STAMP}"
say " ZIP: ${ZIP_PATH}"
say " Workspace: ${WORK}"
say ' Active launcher: NOT TOUCHED'
say ' Package/network changes: only after explicit opt-in to install missing ShellCheck'
say '============================================================'

run_check() {
    local label="$1"
    shift
    local number=$(( ${#CHECK_LABELS[@]} + 1 ))
    local logfile
    local rc=0
    logfile="${LOG_DIR}/$(printf '%02d' "$number").log"
    CHECK_LABELS+=("$label")
    CHECK_LOGS+=("$logfile")
    say ""
    say "[RUN $number] $label"
    if "$@" >"$logfile" 2>&1; then
        CHECK_STATES+=(PASS)
        CHECK_CODES+=(0)
        say "[PASS] $label"
        tail -n 8 "$logfile" 2>/dev/null || true
    else
        rc=$?
        CHECK_CODES+=("$rc")
        if (( rc == 124 || rc == 137 )); then
            CHECK_STATES+=(TIMEOUT)
            say "[TIMEOUT] $label (exit ${rc})"
        elif (( rc == 127 )); then
            CHECK_STATES+=(BLOCKED)
            say "[BLOCKED] $label (required tool/command unavailable; exit ${rc})"
        else
            CHECK_STATES+=(FAIL)
            say "[FAIL] $label (exit ${rc})"
        fi
        tail -n 35 "$logfile" 2>/dev/null || true
        say "Full log: $logfile"
    fi
}

last_check_passed() {
    local last=$(( ${#CHECK_STATES[@]} - 1 ))
    [[ "$last" -ge 0 && "${CHECK_STATES[$last]}" == PASS ]]
}

check_zip_hash() {
    local actual
    actual="$(sha256sum "$ZIP_PATH" | awk '{print $1}')" || return 1
    say "Expected SHA-256: ${EXPECTED_ZIP_SHA256}"
    say "Actual SHA-256:   ${actual}"
    [[ "$actual" == "$EXPECTED_ZIP_SHA256" ]]
}

check_zip_integrity() {
    unzip -tq "$ZIP_PATH"
}

check_archive_paths() {
    local paths roots
    paths="$(unzip -Z1 "$ZIP_PATH")" || return 1
    printf '%s\n' "$paths" | awk '
        /^\// || /(^|\/)\.\.(\/|$)/ || /\\/ || /^[A-Za-z]:/ {
            print "Unsafe archive path: " $0
            bad=1
        }
        END { if (bad) exit 1 }
    ' || return 1
    roots="$(printf '%s\n' "$paths" | awk -F/ 'NF {print $1}' | sort -u)" || return 1
    say "Archive top-level path: ${roots}"
    [[ "$roots" == "$EXPECTED_ROOT" ]]
}

check_extract_source() {
    unzip -q "$ZIP_PATH" -d "${WORK}/source" || return 1
    ROOT="${WORK}/source/${EXPECTED_ROOT}"
    [[ -d "$ROOT" && -f "$ROOT/SHA256SUMS" && -f "$ROOT/test/run_all.sh" && -f "$ROOT/devils-minios.sh" ]]
}

check_manifest() {
    local expected actual
    cd "$ROOT" || return 1
    sha256sum -c SHA256SUMS || return 1
    expected="$(awk '{sub(/^[^ ]+  /, ""); sub(/^\.\//, ""); print}' SHA256SUMS | sort)" || return 1
    actual="$(find . -type f ! -name SHA256SUMS -print | sed 's#^\./##' | sort)" || return 1
    if [[ "$expected" != "$actual" ]]; then
        say 'Manifest completeness mismatch: file list differs from SHA256SUMS.'
        return 1
    fi
    say "Manifest integrity and completeness verified ($(printf '%s\n' "$expected" | wc -l | tr -d ' ') entries)."
}

check_platform() {
    local machine api release prefix
    machine="$(uname -m 2>/dev/null || true)"
    api="$(getprop ro.build.version.sdk 2>/dev/null || true)"
    release="$(getprop ro.build.version.release 2>/dev/null || true)"
    prefix="${PREFIX:-unset}"
    say "uname -m: ${machine:-unknown}"
    say "Android API: ${api:-unavailable}"
    say "Android release: ${release:-unavailable}"
    say "PREFIX: ${prefix}"
    [[ "$machine" == aarch64 || "$machine" == x86_64 ]] || {
        say 'Unsupported or unconfirmed architecture; expected aarch64 or x86_64.'
        return 1
    }
    [[ "$api" =~ ^[0-9]+$ ]] && (( api >= 29 )) || {
        say 'Could not verify Android API >=29 (Android 10+).'
        return 1
    }
    [[ "$prefix" == *com.termux* ]] || {
        say 'Could not verify a Termux PREFIX; run this script from Termux.'
        return 1
    }
}

check_bash_syntax() {
    local file failed=0 count=0
    cd "$ROOT" || return 1
    while IFS= read -r -d '' file; do
        count=$((count + 1))
        if ! bash -n "$file" 2>&1; then
            say "Syntax failure: ${file#./}"
            failed=1
        fi
    done < <(find . -type f -name '*.sh' -print0)
    say "Syntax-checked ${count} shell files."
    (( failed == 0 ))
}

check_shellcheck() {
    local file reply='' install_rc=0
    local -a files=()
    cd "$ROOT" || return 1
    if ! command -v shellcheck >/dev/null 2>&1; then
        if ! command -v pkg >/dev/null 2>&1; then
            SHELLCHECK_INSTALL_RESULT='blocked: ShellCheck and Termux pkg unavailable'
            say 'ShellCheck is missing and the Termux pkg command is unavailable.'
            return 127
        fi
        if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
            SHELLCHECK_INSTALL_RESULT='blocked: no interactive terminal for explicit consent'
            say 'ShellCheck is missing; no interactive terminal is available to request installation consent.'
            say 'Install manually with: pkg install shellcheck'
            return 127
        fi
        printf 'ShellCheck is missing. Install it now with `pkg install shellcheck`? This may use the network and modify Termux packages. [y/N]: ' >/dev/tty
        IFS= read -r reply </dev/tty || reply=''
        case "$reply" in
            y|Y|yes|YES|Yes)
                SHELLCHECK_INSTALL_APPROVED='YES'
                SHELLCHECK_INSTALL_RESULT='approved; install attempted'
                say 'User explicitly approved Termux package installation for ShellCheck.'
                if pkg install -y shellcheck >"${LOG_DIR}/shellcheck-install.log" 2>&1; then
                    SHELLCHECK_INSTALL_RESULT='approved; pkg install exited 0'
                else
                    install_rc=$?
                    SHELLCHECK_INSTALL_RESULT="approved; pkg install failed with exit ${install_rc}"
                    say "ShellCheck package installation failed (exit ${install_rc}); see ${LOG_DIR}/shellcheck-install.log."
                    return "$install_rc"
                fi
                if ! command -v shellcheck >/dev/null 2>&1; then
                    SHELLCHECK_INSTALL_RESULT='approved; package command returned success but ShellCheck remains unavailable'
                    say 'pkg install returned success but shellcheck is not on PATH.'
                    return 127
                fi
                ;;
            *)
                SHELLCHECK_INSTALL_RESULT='declined by user'
                say 'ShellCheck installation declined; the ShellCheck gate is BLOCKED, not passed.'
                return 127
                ;;
        esac
    fi
    while IFS= read -r -d '' file; do files+=("$file"); done < <(find . -type f -name '*.sh' -print0)
    (( ${#files[@]} > 0 )) || { say 'No .sh files found.'; return 1; }
    say "ShellCheck version: $(shellcheck --version | sed -n '2p')"
    say "Checking all ${#files[@]} .sh files, including tests and the traceability validator."
    shellcheck "${files[@]}"
}

check_traceability() {
    cd "$ROOT" || return 1
    [[ -f test/validate_traceability.sh ]] || { say 'Missing test/validate_traceability.sh'; return 1; }
    bash test/validate_traceability.sh
}

check_structure() {
    local f lines count
    local -a actual_modules=() expected_modules=(
        android_tools.sh core.sh customize.sh file_mgr.sh health_check.sh
        linux_env.sh log_viewer.sh proot_apps.sh settings.sh system_info.sh
        system_tools.sh termux_apps.sh update_all.sh workspace.sh
    )
    local -a tests=(
        test_core.sh test_utils.sh test_security.sh test_linux_env.sh
        test_file_mgr.sh test_termux_apps.sh test_proot_apps.sh
        test_android_tools.sh test_workspace.sh test_health_check.sh
        test_log_viewer.sh test_customize.sh test_system_tools.sh
        test_system_info.sh test_update_all.sh test_settings.sh
        test_integration.sh test_install.sh test_report_generator.sh
    )
    cd "$ROOT" || return 1
    for f in modules/*.sh; do [[ -f "$f" ]] && actual_modules+=("${f##*/}"); done
    [[ "$(printf '%s\n' "${actual_modules[@]}")" == "$(printf '%s\n' "${expected_modules[@]}")" ]] || {
        say "Expected exactly these 14 modules: ${expected_modules[*]}"
        say "Found modules: ${actual_modules[*]}"
        return 1
    }
    say 'Exactly the 14 required active modules are present.'

    count=0
    for f in test/test_*.sh; do [[ -f "$f" ]] && count=$((count + 1)); done
    [[ "$count" -eq 19 ]] || { say "Expected 19 mandatory test files; found ${count}."; return 1; }
    for f in "${tests[@]}"; do [[ -f "test/$f" ]] || { say "Missing mandatory test file: test/$f"; return 1; }; done
    [[ -f test/run_all.sh ]] || { say 'Missing test/run_all.sh'; return 1; }
    say 'Exactly 19 mandatory test files and the run_all.sh harness are present.'

    local future_files
    future_files="$(find . -iname '*future_plans*' -print 2>/dev/null)" || return 1
    [[ -z "$future_files" ]] || { say "Forbidden future_plans path(s): $future_files"; return 1; }
    say 'No future_plans-named path exists in the source tree.'

    local -a required_docs=(
        README.md docs/CHANGELOG.md docs/COMPATIBILITY.md docs/DATA.md
        docs/INSTALL.md docs/MODULES.md docs/SECURITY.md
        docs/TRACEABILITY.md docs/TROUBLESHOOTING.md
    )
    for f in "${required_docs[@]}"; do [[ -f "$f" ]] || { say "Missing required documentation: $f"; return 1; }; done
    say 'Required documentation files are present.'

    while IFS= read -r -d '' f; do
        lines="$(wc -l < "$f")" || return 1
        if (( lines >= 500 )); then say "Line-limit violation: $f has ${lines} lines (must be <500)."; return 1; fi
    done < <(find . -type f -name '*.sh' -print0)
    say 'Every .sh file in the repository is below 500 lines.'
}

count_catalog_records() {
    awk 'BEGIN { n=0 } { sub(/\r$/, ""); if ($0 !~ /^[[:space:]]*#/ && $0 ~ /[^[:space:]]/) n++ } END { print n+0 }' "$1"
}

check_catalog_cardinality() {
    local desktops proot_apps termux_apps
    cd "$ROOT" || return 1
    for f in data/desktops.db data/proot_apps.db data/termux_apps.db data/proot_distros.db; do
        [[ -f "$f" ]] || { say "Missing catalog: $f"; return 1; }
    done
    desktops="$(count_catalog_records data/desktops.db)"
    proot_apps="$(count_catalog_records data/proot_apps.db)"
    termux_apps="$(count_catalog_records data/termux_apps.db)"
    say "Tier-1 desktop entries: ${desktops} (required 8)"
    say "Proot application entries: ${proot_apps} (required 40)"
    say "Termux application entries: ${termux_apps} (required 30-40)"
    [[ "$desktops" -eq 8 && "$proot_apps" -eq 40 && "$termux_apps" -ge 30 && "$termux_apps" -le 40 ]]
}

check_forbidden_constructs() {
    local f hit failed=0
    local -a source_files=(install.sh devils-minios.sh modules/*.sh core/*.sh)
    cd "$ROOT" || return 1
    for f in "${source_files[@]}"; do
        [[ -f "$f" ]] || continue
        hit="$(grep -nE '(^|[;&|[:space:]])eval([[:space:]]|$)|(^|[;&|[:space:]])(sh|bash)[[:space:]]+-c([[:space:]]|$)' "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
        if [[ -n "$hit" ]]; then
            say "Forbidden dynamic-shell construct in ${f}:"
            say "$hit"
            failed=1
        fi
        hit="$(grep -nE '(curl|wget)[^#]*\|[^#]*bash' "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
        if [[ -n "$hit" ]]; then
            say "Forbidden curl/wget-to-bash pipeline in ${f}:"
            say "$hit"
            failed=1
        fi
    done
    (( failed == 0 )) || return 1
    say 'No forbidden eval/sh -c/bash -c or curl|bash/wget|bash construct found in launcher/installer source paths.'
}

check_cli_smoke() {
    local version help
    cd "$ROOT" || return 1
    version="$(bash devils-minios.sh --version 2>&1)" || { say "--version failed: $version"; return 1; }
    [[ "$version" == *'1.0.0'* ]] || { say "Unexpected version output: $version"; return 1; }
    help="$(bash devils-minios.sh --help 2>&1)" || { say "--help failed: $help"; return 1; }
    [[ "$help" == *'Usage:'* ]] || { say "Unexpected --help output: $help"; return 1; }
    say '--version reports 1.0.0 and --help prints usage; neither installs or updates anything.'
}

run_mandatory_suite() {
    cd "$ROOT" || return 1
    timeout "$TEST_TIMEOUT_SECONDS" bash test/run_all.sh
}

check_post_test_manifest() {
    cd "$ROOT" || return 1
    sha256sum -c SHA256SUMS
}

write_report() {
    local i overall=PASS failed=0 state
    for state in "${CHECK_STATES[@]}"; do [[ "$state" == PASS ]] || failed=1; done
    (( failed == 0 )) || overall=FAIL
    {
        printf '# Devil\x27s Mini OS Launcher — PRD-6.2 Master Test Report\n\n'
        printf -- '- Started (UTC): `%s`\n' "$STAMP"
        printf -- '- Source ZIP: `%s`\n' "$ZIP_PATH"
        printf -- '- Expected ZIP SHA-256: `%s`\n' "$EXPECTED_ZIP_SHA256"
        printf -- '- Extracted source: `%s`\n' "${ROOT:-not extracted}"
        printf -- '- Device architecture: `%s`\n' "$(uname -m 2>/dev/null || echo unavailable)"
        printf -- '- ShellCheck install explicitly approved: `%s`\n' "$SHELLCHECK_INSTALL_APPROVED"
        printf -- '- ShellCheck install status: `%s`\n' "$SHELLCHECK_INSTALL_RESULT"
        printf -- '- Overall automated result: **%s**\n\n' "$overall"
        printf '| # | Check | Status | Exit code | Log |\n|---:|---|---|---:|---|\n'
        for i in "${!CHECK_LABELS[@]}"; do
            printf '| %s | %s | **%s** | %s | `%s` |\n' \
                "$((i + 1))" "${CHECK_LABELS[$i]}" "${CHECK_STATES[$i]}" \
                "${CHECK_CODES[$i]}" "${CHECK_LOGS[$i]}"
        done
        printf '\n## Release-gate limits of this run\n\n'
        printf '%s\n' '- This run tests only the architecture of the current device; the PRD requires both `aarch64` and `x86_64` evidence before release.'
        printf '%s\n' '- PRD-required manual Android acceptance and review of requirement-level traceability are not replaced by this automated run.'
        printf '%s\n' '- A passing automated result is not a v1.0.0 FINAL/release approval.'
        printf '\n## Evidence files\n\n'
        printf -- '- Console log: `%s`\n' "$MASTER_LOG"
        printf -- '- Individual check logs: `%s`\n' "$LOG_DIR"
        printf -- '- Extracted test copy: `%s`\n' "${ROOT:-not extracted}"
    } > "$REPORT"
    say ''
    say '============================================================'
    say "AUTOMATED RESULT: ${overall}"
    say "Report: ${REPORT}"
    say "Console log: ${MASTER_LOG}"
    say "Check logs: ${LOG_DIR}"
    say 'Installed launcher: not touched.'
    say 'Release status: NOT VERIFIED by this one-device run (second architecture and manual acceptance remain separate gates).'
    say '============================================================'
    (( failed == 0 ))
}

abort_if_last_check_failed() {
    if ! last_check_passed; then
        write_report || true
        exit 1
    fi
}

run_check 'Target device / Termux / Android API preflight' check_platform
abort_if_last_check_failed
run_check 'Archive SHA-256 matches the verified ZIP' check_zip_hash
abort_if_last_check_failed
run_check 'ZIP internal structure integrity' check_zip_integrity
abort_if_last_check_failed
run_check 'Archive paths are safe and have the expected single root' check_archive_paths
abort_if_last_check_failed
run_check 'Extract source to a new private workspace' check_extract_source
abort_if_last_check_failed
run_check 'SHA256SUMS integrity and manifest completeness' check_manifest
abort_if_last_check_failed

run_check 'Bash syntax: every .sh file in the source tree' check_bash_syntax
run_check 'ShellCheck: every .sh file in the source tree' check_shellcheck
run_check 'PRD structure: 14 modules, 19 tests, docs, no future_plans, line limits' check_structure
run_check 'PRD §43.5 traceability schema, IDs, fields, owners, statuses and totals' check_traceability
run_check 'Catalog cardinality: desktops/proot apps/Termux apps' check_catalog_cardinality
run_check 'Security scan: forbidden dynamic shell/pipeline constructs' check_forbidden_constructs
run_check 'CLI smoke: --version and --help' check_cli_smoke
run_check 'PRD §43.2: full mandatory test suite (19 files; bounded runtime)' run_mandatory_suite
run_check 'Post-suite SHA256SUMS integrity' check_post_test_manifest

write_report
