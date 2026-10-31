#!/usr/bin/env bash
set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec > >(tee -a "$EVIDENCE_DIR/master-console.log") 2>&1

echo "========================================"
echo " Devil's Mini OS Launcher"
echo " Android Manual Test Evidence Runner"
echo "========================================"
echo "timestamp=$(date -Is)"
echo "project_root=$PROJECT_ROOT"
echo "evidence_dir=$EVIDENCE_DIR"
echo

echo "===== 00 BASELINE ====="

{
    echo "timestamp=$(date -Is)"
    echo "android_release=$(getprop ro.build.version.release 2>/dev/null || true)"
    echo "android_api=$(getprop ro.build.version.sdk 2>/dev/null || true)"
    echo "android_codename=$(getprop ro.build.version.codename 2>/dev/null || true)"
    echo "device_model=$(getprop ro.product.model 2>/dev/null || true)"
    echo "manufacturer=$(getprop ro.product.manufacturer 2>/dev/null || true)"
    echo "cpu_abi=$(getprop ro.product.cpu.abi 2>/dev/null || true)"
    echo "cpu_abi2=$(getprop ro.product.cpu.abilist 2>/dev/null || true)"
    echo "uname=$(uname -a 2>/dev/null || true)"
    echo "machine=$(uname -m 2>/dev/null || true)"
    echo "bash_version=$BASH_VERSION"
    echo "prefix=${PREFIX:-unset}"
    echo "home=$HOME"
    echo "term=${TERM:-unset}"
    echo
    echo "termux_info:"
    if command -v termux-info >/dev/null 2>&1; then
        termux-info 2>&1 || true
    else
        echo "termux-info=not-installed"
    fi
    echo
    echo "capabilities:"
    for cmd in bash git curl sha256sum pkg proot-distro adb fastboot termux-api termux-battery-status termux-wifi-connectioninfo tput; do
        printf '%-32s' "$cmd"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "FOUND: $(command -v "$cmd")"
        else
            echo "NOT_FOUND"
        fi
    done
} > "$EVIDENCE_DIR/00-baseline/device-environment.txt"

{
    echo "===== STORAGE ====="
    df -h "$HOME" "$PREFIX" 2>/dev/null || true
    echo
    echo "===== PROJECT SIZE ====="
    du -sh "$PROJECT_ROOT" 2>/dev/null || true
    echo
    echo "===== PREFIX SIZE ====="
    du -sh "$PREFIX" 2>/dev/null || true
} > "$EVIDENCE_DIR/00-baseline/storage.txt"

if command -v getprop >/dev/null 2>&1; then
    getprop > "$EVIDENCE_DIR/00-baseline/android-getprop.txt" 2>&1 || true
fi

echo "===== 01 READINESS ====="

{
    echo "===== ACTIVE MODULES ====="
    find "$PROJECT_ROOT/modules" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' 2>/dev/null | sort
    echo
    echo "module_count=$(find "$PROJECT_ROOT/modules" -maxdepth 1 -type f -name '*.sh' | wc -l)"
} > "$EVIDENCE_DIR/01-readiness/modules.txt"

{
    echo "===== FUTURE PLANS CHECK ====="
    find "$PROJECT_ROOT" -iname '*future_plans*' -print 2>/dev/null || true
    echo
    echo "future_plans_matches=$(find "$PROJECT_ROOT" -iname '*future_plans*' | wc -l)"
} > "$EVIDENCE_DIR/01-readiness/future-plans.txt"

{
    echo "===== BASH SYNTAX CHECK ====="
    failed=0
    while IFS= read -r -d '' file; do
        if bash -n "$file" 2>&1; then
            echo "PASS: $file"
        else
            echo "FAIL: $file"
            failed=$((failed + 1))
        fi
    done < <(find "$PROJECT_ROOT" -type f -name '*.sh' -print0)
    echo
    echo "syntax_failures=$failed"
} > "$EVIDENCE_DIR/01-readiness/syntax.txt"

{
    echo "===== SHELL LINE LIMIT ====="
    failed=0
    while IFS= read -r -d '' file; do
        lines=$(wc -l < "$file")
        if [ "$lines" -ge 500 ]; then
            echo "FAIL: $file -> $lines lines"
            failed=$((failed + 1))
        else
            echo "PASS: $file -> $lines lines"
        fi
    done < <(find "$PROJECT_ROOT" -type f -name '*.sh' -print0)
    echo
    echo "files_at_or_above_500=$failed"
} > "$EVIDENCE_DIR/01-readiness/line-limit.txt"

echo "===== 02 NETWORK BASELINE ====="

net_snapshot() {
    awk '
        /\/statistics\/rx_bytes$/ {rx += $1}
        /\/statistics\/tx_bytes$/ {tx += $1}
        END {
            printf "rx_bytes=%d\n", rx+0
            printf "tx_bytes=%d\n", tx+0
        }
    ' /sys/class/net/*/statistics/rx_bytes \
      /sys/class/net/*/statistics/tx_bytes 2>/dev/null
}

net_snapshot > "$EVIDENCE_DIR/05-network-metering/before.txt"

echo "===== 03 AUTOMATED SUITE ====="

suite_start=$(date +%s)

(
    cd "$PROJECT_ROOT" || exit 1
    bash test/run_all.sh
) > "$EVIDENCE_DIR/02-automated-suite/run_all.txt" 2>&1

suite_rc=$?

suite_end=$(date +%s)

echo "suite_exit=$suite_rc" > "$EVIDENCE_DIR/02-automated-suite/exit-status.txt"
echo "suite_duration_seconds=$((suite_end - suite_start))" \
    > "$EVIDENCE_DIR/02-automated-suite/duration.txt"

echo "===== 04 CLI SMOKE ====="

{
    echo "===== VERSION ====="
    (
        cd "$PROJECT_ROOT" || exit 1
        bash devils-minios.sh --version
    ) 2>&1 || true

    echo
    echo "===== HELP ====="
    (
        cd "$PROJECT_ROOT" || exit 1
        bash devils-minios.sh --help
    ) 2>&1 || true
} > "$EVIDENCE_DIR/03-cli-smoke/version-help.txt"

echo "===== 05 INTEGRITY ====="

{
    cd "$PROJECT_ROOT" || exit 1

    echo "===== SHA256SUMS ====="
    sha256sum -c SHA256SUMS 2>&1 || true

    echo
    echo "===== GIT STATUS ====="
    if [ -d .git ]; then
        git status --short 2>&1 || true
        echo
        git rev-parse HEAD 2>&1 || true
        echo
        git branch --show-current 2>&1 || true
    else
        echo "No .git directory"
    fi

    echo
    echo "===== SOURCE FILE LIST ====="
    find . -type f -print | sort
} > "$EVIDENCE_DIR/04-integrity/integrity.txt"

echo "===== 06 NETWORK AFTER ====="

net_snapshot > "$EVIDENCE_DIR/05-network-metering/after.txt"

awk -F= '
    NR == FNR { before[$1] = $2; next }
    {
        delta = $2 - before[$1]
        printf "%s=%d bytes\n", $1, delta
    }
' \
"$EVIDENCE_DIR/05-network-metering/before.txt" \
"$EVIDENCE_DIR/05-network-metering/after.txt" \
> "$EVIDENCE_DIR/05-network-metering/delta.txt"

echo "===== 07 GENERATE MANUAL CHECKLIST ====="

cat > "$EVIDENCE_DIR/MANUAL-CHECKLIST.md" <<'CHECKLIST'
# Devil's Mini OS Launcher v1.0.0
# Real Android / Termux Manual Acceptance Evidence

Complete these manual acceptance groups on the same device.

## MA-01
Installation variants, ZIP/Git checkout, onboarding, auto-start opt-in.

Record:
- installation command/output
- version output
- onboarding screenshots or terminal transcript
- auto-start opt-in result
- reinstall/idempotency result

## MA-02
Supported Android/Termux source and unsupported-platform behavior.

Record:
- Android API level
- architecture
- Termux source
- Play Store warning behavior when applicable
- unsupported-platform behavior when applicable

## MA-03
Proot distro, desktop, systemd acknowledgement, xstartup/startup.

Record:
- selected distro
- installation result
- desktop startup result
- systemd acknowledgement
- xstartup/startup result

## MA-04
Application installation and security.

Record:
- Termux app installation result
- Proot app installation result
- GitHub artifact path when applicable
- architecture mismatch confirmation behavior
- security rejection behavior

## MA-05
Android tools and Termux:API degradation.

Record:
- ADB detection
- fastboot detection
- Termux:API available/unavailable behavior
- graceful degradation when optional capability is missing

## MA-06
Terminal widths and Ctrl+C.

Test:
- Full mode
- Compact mode
- Minimal mode
- Ctrl+C confirmation

Record terminal width and observed behavior.

## MA-07
Log viewer.

Record:
- log listing
- log viewing
- read-only behavior
- malformed/missing log handling where applicable

## MA-08
Configuration, state and crash recovery.

Record:
- configuration reset
- state reset
- valid crash recovery
- stale crash flag
- malformed crash flag
- recovery evidence

## MA-09
Safe Mode.

Record:
- explicit Safe Mode
- Safe Mode caused by recovery conditions
- menu availability restrictions
- exit/recovery path

## MA-10
Reset, update/rollback and uninstall.

Record separately:
- configuration reset
- state reset
- nuclear reset
- update
- rollback/failure behavior
- uninstall

Do not run destructive operations until all required user data is backed up.

## MA-11
Real-device full suite and performance.

Record:
- real aarch64/x86_64 architecture
- full 19-test suite result
- launcher cold-start timing
- memory observation
- final device/environment evidence

## Evidence rule

Do not mark a manual item as PASS only from source inspection or automated tests.

Store the actual terminal output, screenshots, timing results, and relevant command results under its MA-* directory.
CHECKLIST

echo "===== 08 FINAL SUMMARY ====="

{
    echo "timestamp=$(date -Is)"
    echo "project_root=$PROJECT_ROOT"
    echo "evidence_dir=$EVIDENCE_DIR"
    echo
    echo "module_count=$(find "$PROJECT_ROOT/modules" -maxdepth 1 -type f -name '*.sh' | wc -l)"
    echo "future_plans_matches=$(find "$PROJECT_ROOT" -iname '*future_plans*' | wc -l)"
    echo
    echo "suite_exit=$suite_rc"
    echo "suite_duration_seconds=$((suite_end - suite_start))"
    echo
    echo "Evidence generated:"
    find "$EVIDENCE_DIR" -maxdepth 2 -type f -printf '%P\n' | sort
} > "$EVIDENCE_DIR/FINAL-SUMMARY.txt"

echo
echo "========================================"
echo " TEST RUN FINISHED"
echo "========================================"
echo "Evidence: $EVIDENCE_DIR"
echo "Suite exit: $suite_rc"
echo "Manual checklist: $EVIDENCE_DIR/MANUAL-CHECKLIST.md"
echo

exit "$suite_rc"
