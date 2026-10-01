#!/usr/bin/env bash
# test_integration.sh - PRD §43.1: End-to-end sandbox integration checks.
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
section "fresh sandbox: core init + config + state"
out="$(run_core "${SBOX}" '
    load_default_config
    save_config
    default_state
    save_state
    validate_config && printf "config=ok\n" || printf "config=fail\n"
    validate_state && printf "state=ok\n" || printf "state=fail\n"
')"
assert_contains "config validates after defaults" "${out}" "config=ok"
assert_contains "state validates after defaults" "${out}" "state=ok"
section "PRD §14 startup order: persistent state/config precede runtime context"
out="$(run_core "${SBOX}" '
    order=()
    detect_platform() { order+=(platform); }
    detect_termux_source() { order+=(source); }
    load_state() { order+=(state); default_state; save_state >/dev/null; }
    load_config() { order+=(config); load_default_config; save_config >/dev/null; return 0; }
    build_runtime_context() { order+=(runtime); DEVILS_MINIOS_TERMINAL_WIDTH=80; DEVILS_MINIOS_UI_MODE=full; }
    recover_runtime_temp_corrupt() { return 1; }
    rotate_and_purge_logs() { order+=(logs); }
    _load_modules() { order+=(modules); }
    write_log_file() { :; }
    core_init
    printf "order=%s\\n" "${order[*]}"
')"
assert_contains "startup order detects platform/source first" "${out}" "order=platform source state config runtime logs modules"
out="$(run_core "${SBOX}" '
    load_default_config; save_config
    build_runtime_context
    printf "runtime_width=%s\\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}"
    grep -q '^terminal_width=' "${DEVILS_MINIOS_CONFIG_FILE}" && printf "persisted=yes\\n" || printf "persisted=no\\n"
')"
assert_contains "runtime context is available in memory" "${out}" "runtime_width="
assert_contains "terminal_width is not persisted" "${out}" "persisted=no"
out="$(run_core "${SBOX}" '
    printf "state_version=1\\nprimary_distro=\\nlast_successful_workflow=\\nonboarding_completion=false\\ncrash_loop_state=\\n" > "${DEVILS_MINIOS_STATE_FILE}"
    printf "corrupt\\n" > "${DEVILS_MINIOS_STATE_BACKUP}"
    load_state
    printf "state=%s onboarding=%s\\n" "${DEVILS_MINIOS_CURRENT_STATE:-unset}" "${DEVILS_MINIOS_STATE[onboarding_completion]}"
')"
assert_contains "unrecoverable state reinitializes onboarding state" "${out}" "onboarding=false"
section "all 14 modules are present and loadable"
modules=(core linux_env file_mgr termux_apps proot_apps android_tools workspace health_check log_viewer customize system_tools system_info update_all settings)
missing=0
for m in "${modules[@]}"; do
    if [[ ! -f "${DMOS_PROJECT_ROOT}/modules/${m}.sh" ]]; then
        fail "module ${m}.sh missing"
        missing=1
    fi
done
[[ ${missing} -eq 0 ]] && pass "all 14 modules present"
section "future_plans.sh must not exist"
if [[ -f "${DMOS_PROJECT_ROOT}/modules/future_plans.sh" ]]; then
    fail "future_plans.sh must not exist"
else
    pass "future_plans.sh absent"
fi
section "desktops.db has exactly 8 Tier-1 entries"
count="$(grep -cE '^[a-z]' "${DMOS_PROJECT_ROOT}/data/desktops.db" 2>/dev/null || echo 0)"
assert_eq "exactly 8 desktops" "8" "${count}"
section "PRD §18 catalog schemas and cardinality"
proot_count="$(awk -F'\\|' '!/^#/ && NF {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/proot_apps.db")"
termux_count="$(awk -F'\\|' '!/^#/ && NF {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/termux_apps.db")"
distro_count="$(awk -F'\\|' '!/^#/ && NF {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/proot_distros.db")"
assert_eq "proot apps exact cardinality" "40" "${proot_count}"
assert_eq "termux apps cardinality in required range" "1" "$([[ ${termux_count} -ge 30 && ${termux_count} -le 40 ]] && echo 1 || echo 0)"
assert_eq "proot distros have six records" "6" "${distro_count}"
proot_bad_fields="$(awk -F'\\|' '!/^#/ && NF != 7 {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/proot_apps.db")"
termux_bad_fields="$(awk -F'\\|' '!/^#/ && NF != 11 {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/termux_apps.db")"
distro_bad_fields="$(awk -F'\\|' '!/^#/ && NF != 7 {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/proot_distros.db")"
desktop_bad_fields="$(awk -F'\\|' '!/^#/ && NF != 7 {n++} END{print n+0}' "${DMOS_PROJECT_ROOT}/data/desktops.db")"
assert_eq "proot apps all records have seven fields" "0" "${proot_bad_fields}"
assert_eq "termux apps all records have eleven fields" "0" "${termux_bad_fields}"
assert_eq "proot distros all records have seven fields" "0" "${distro_bad_fields}"
assert_eq "desktops all records have seven fields" "0" "${desktop_bad_fields}"
for db in proot_apps.db termux_apps.db proot_distros.db; do
    dup="$(awk -F'\\|' '!/^#/ && NF {print $1}' "${DMOS_PROJECT_ROOT}/data/${db}" | sort | uniq -d | wc -l | tr -d ' ')"
    assert_eq "${db} has no duplicate IDs" "0" "${dup}"
done
section "proot_apps.db has entries with 7 fields"
out="$(run_core "${SBOX}" '
    load_database "$(data_file_path proot_apps.db)" 7 _validate_proot_app_record true 2>/dev/null || true
    printf "count=%d\n" "${#DEVILS_MINIOS_CATALOG[@]}"
')"
assert_contains "proot apps catalog non-empty" "${out}" "count="
assert_not_contains "proot apps not zero" "${out}" "count=0"
section "xstartup generation contract exists"
out="$(run_module "${SBOX}" "linux_env" '
    type generate_xstartup >/dev/null 2>&1 && printf "gen=ok\n" || printf "gen=missing\n"
')"
assert_contains "generate_xstartup defined" "${out}" "gen=ok"
section "UI modes: Full / Compact / Minimal"
out="$(run_core "${SBOX}" '
    type show_main_menu_full >/dev/null 2>&1 && printf "full=ok\n" || printf "full=missing\n"
    type show_main_menu_compact >/dev/null 2>&1 && printf "compact=ok\n" || printf "compact=missing\n"
    type show_main_menu_minimal >/dev/null 2>&1 && printf "minimal=ok\n" || printf "minimal=missing\n"
')"
assert_contains "Full menu function exists" "${out}" "full=ok"
assert_contains "Compact menu function exists" "${out}" "compact=ok"
assert_contains "Minimal menu function exists" "${out}" "minimal=ok"
section "PRD §15 CLI precedence: exit codes and immediate termination"
_cli() {
    # Runs the real entry point in the sandbox with HOME confined to it.
    HOME="${SBOX}/home" bash "${SBOX}/usr/opt/devils-minios/devils-minios.sh" "$@" 2>&1
}
out="$(_cli -v)"; rc=$?
assert_status "-v exits 0 immediately (PRD-15-001)" 0 "${rc}"
assert_contains "-v prints SemVer product version" "${out}" "v1.0.0"
_cli --help >/dev/null; rc=$?
assert_status "--help exits 0 immediately" 0 "${rc}"
_cli -h -v >/dev/null; rc=$?
assert_status "-h -v: first of -h/-v wins, exit 0 (not a conflict)" 0 "${rc}"
_cli --safe-mode -v >/dev/null; rc=$?
assert_status "-v terminates before --safe-mode dispatch, exit 0" 0 "${rc}"
out="$(_cli --bogus)"; rc=$?
assert_status "unknown option exits 2 (PRD-15-006)" 2 "${rc}"
assert_contains "unknown option reports E400" "${out}" "E400"
_cli --update --uninstall >/dev/null; rc=$?
assert_status "conflicting lifecycle flags exit 2 with E400" 2 "${rc}"
_cli --run-module future >/dev/null; rc=$?
assert_status "removed alias 'future' rejected, exit 2" 2 "${rc}"
_cli --run-module roadmap >/dev/null; rc=$?
assert_status "removed alias 'roadmap' rejected, exit 2" 2 "${rc}"
_cli --run-module >/dev/null; rc=$?
assert_status "--run-module without a name exits 2" 2 "${rc}"
out="$(DMOS_TEST_ROOT="${SBOX}/usr/opt/devils-minios" bash -s 2>&1 <<'SCRIPT'
set +e
source "${DMOS_TEST_ROOT}/devils-minios.sh"
set +e
for pair in "linux_env linux_env" "files file_mgr" "file_mgr file_mgr" "desktop_env linux_env" "desktops linux_env" "android android_tools" "android_tools android_tools" "doctor health_check" "health_check health_check" "logs logs" "theme customize" "customize customize" "tools system_tools" "system_tools system_tools" "info system_info" "system_info system_info" "update update" "termux_apps termux_apps" "proot_apps proot_apps" "workspace workspace" "settings settings"; do
    set -- $pair
    resolved="$(_resolve_run_module_alias "$1")"
    printf '%s=%s\n' "$1" "$resolved"
done
_resolve_run_module_alias "" >/dev/null 2>&1 && printf 'empty=resolved\n' || printf 'empty=rejected\n'
_resolve_run_module_alias "file_mgrs" >/dev/null 2>&1 && printf 'nearmiss=resolved\n' || printf 'nearmiss=rejected\n'
SCRIPT
)"
assert_contains "canonical module alias mappings resolve" "${out}" "files=file_mgr"
assert_contains "desktop aliases resolve to merged linux_env" "${out}" "desktops=linux_env"
assert_contains "android alias resolves" "${out}" "android=android_tools"
assert_contains "diagnostic alias resolves" "${out}" "doctor=health_check"
assert_contains "every remaining canonical module name resolves to itself" "${out}" "termux_apps=termux_apps"
assert_contains "workspace canonical name resolves to itself" "${out}" "workspace=workspace"
assert_contains "settings canonical name resolves to itself" "${out}" "settings=settings"
assert_contains "empty --run-module target is rejected by the resolver" "${out}" "empty=rejected"
assert_contains "a near-miss target (file_mgrs) is rejected, not fuzzy-matched" "${out}" "nearmiss=rejected"
_cli --update --uninstall-auto-start >/dev/null; rc=$?
assert_status "update + uninstall-auto-start conflict exits 2 with E400" 2 "${rc}"
_cli --uninstall --uninstall-auto-start >/dev/null; rc=$?
assert_status "uninstall + uninstall-auto-start conflict exits 2 with E400" 2 "${rc}"
out="$(printf '0\n' | _cli --safe-mode --update 2>&1)"; rc=$?
assert_status "--safe-mode takes precedence over --update" 0 "${rc}"
assert_contains "--safe-mode dispatches before lifecycle update" "${out}" "SAFE MODE"
out="$(DMOS_TEST_ROOT="${SBOX}/usr/opt/devils-minios" HOME="${SBOX}/home" PREFIX="${SBOX}/usr" XDG_CACHE_HOME="${SBOX}/home/.cache" bash -s 2>&1 <<'SCRIPT'
set +e
source "${DMOS_TEST_ROOT}/devils-minios.sh"
set +e
DEVILS_MINIOS_CURRENT_STATE=MODULE_RUNNING
FLAG_UNINSTALL=true
FLAG_UPDATE=false
FLAG_UNINSTALL_AUTO_START=false
FLAG_RUN_MODULE=""
FLAG_ANY_PRESENT=true
DEVILS_MINIOS_NO_CHECKS=true
_run_startup_diagnostics() { :; }
_dispatch_cli
SCRIPT
)"; rc=$?
assert_status "--uninstall outside IDLE exits 2" 2 "${rc}"
assert_contains "--uninstall outside IDLE reports E401" "${out}" "E401"
section "§43.3 / §15.1 --offline: network-dependent operations rejected, no network attempted"
mkdir -p "${SBOX}/fakebin"
cat > "${SBOX}/fakebin/git" <<'FAKEGIT'
#!/usr/bin/env bash
printf 'git-called\n' >> "${GIT_CALL_LOG}"
exit 1
FAKEGIT
chmod 755 "${SBOX}/fakebin/git"
export GIT_CALL_LOG="${SBOX}/git-calls.log"; : > "${GIT_CALL_LOG}"
out="$(PATH="${SBOX}/fakebin:${PATH}" run_core "${SBOX}" '
    source "${DEVILS_MINIOS_INSTALL_DIR}/core/devils_self_update.sh"
    DEVILS_MINIOS_CURRENT_STATE=IDLE; DEVILS_MINIOS_OFFLINE_MODE=true
    ( _self_update ); printf "update_rc=%s\n" "$?"
')"
assert_contains "--offline update exits 1 (operation-specific failure, not a crash)" "${out}" "update_rc=1"
assert_contains "--offline update explains that network access is required" "${out}" "requires network access"
assert_eq "--offline update never invokes git (no silent network attempt)" "0" "$(wc -l < "${GIT_CALL_LOG}" | tr -d ' ')"
section "§43.3 / §15.2 --no-checks: bypasses only non-critical diagnostics"
_cli --no-checks -v >/dev/null; rc=$?
assert_status "--no-checks is accepted and does not disturb -v (exit 0)" 0 "${rc}"
_cli --no-checks --update --uninstall >/dev/null; rc=$?
assert_status "--no-checks does not bypass CLI conflict validation (exit 2)" 2 "${rc}"
_cli --no-checks --bogus-flag >/dev/null; rc=$?
assert_status "--no-checks does not bypass unknown-option rejection (exit 2)" 2 "${rc}"
out="$(run_core "${SBOX}" '
    DEVILS_MINIOS_NO_CHECKS=true
    printf "not a valid config line\n" > "${DEVILS_MINIOS_CONFIG_FILE}"
    validate_config && printf "cfg=valid\n" || printf "cfg=invalid\n"
')"
assert_contains "--no-checks state does not bypass configuration validation" "${out}" "cfg=invalid"
out="$(run_core "${SBOX}" '
    DEVILS_MINIOS_NO_CHECKS=true
    validate_path "${HOME}/allowed/../escape" "${HOME}/allowed" && printf "path=allowed\\n" || printf "path=blocked\\n"
    execute_structured true "ok;blocked" >/dev/null 2>&1 && printf "exec=allowed\\n" || printf "exec=blocked\\n"
')"
assert_contains "--no-checks does not bypass path validation" "${out}" "path=blocked"
assert_contains "--no-checks does not bypass structured-executor safety" "${out}" "exec=blocked"
# The manifest/checksum boundary belongs to install/update verification, not
# startup diagnostics; --no-checks must not make a bad installed manifest valid.
out="$(run_core "${SBOX}" '
    DEVILS_MINIOS_NO_CHECKS=true
    printf "bad  ${DEVILS_MINIOS_INSTALL_DIR}/missing-file\\n" > "${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS"
    _installed_manifest_tampered && printf "manifest=tampered\\n" || printf "manifest=valid\\n"
')"
assert_contains "--no-checks does not bypass manifest integrity validation" "${out}" "manifest=tampered"
out="$(run_core "${SBOX}" '
    DEVILS_MINIOS_NO_CHECKS=true
    calls=0
    _get_battery_percent() { calls=$((calls + 1)); printf 10; }
    check_storage_threshold() { calls=$((calls + 1)); return 0; }
    _check_for_update_notice() { calls=$((calls + 1)); }
    _run_startup_diagnostics
    printf "optional_checks=%s\\n" "$calls"
')"
assert_contains "--no-checks skips all optional startup diagnostics" "${out}" "optional_checks=0"
section "PRD §15.1 complete offline matrix: network operations reject; local operations remain usable"
out="$(run_core "${SBOX}" '
    calls=0
    execute_structured() { calls=$((calls + 1)); printf "EXEC:%s:%s\\n" "$1" "$2"; return 0; }
    DEVILS_MINIOS_OFFLINE_MODE=true
    rc=0; install_proot_package "debian" "curl" || rc=$?
    printf "proot_install_rc=%s calls=%s\\n" "$rc" "$calls"
    rc=0; install_github_artifact "owner/repo" "v1.0.0" "x.tar.gz" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" || rc=$?
    printf "github_install_rc=%s calls=%s\\n" "$rc" "$calls"
')"
assert_contains "offline proot package install is rejected before execution" "${out}" "proot_install_rc=1 calls=0"
assert_contains "offline GitHub artifact install is rejected before execution" "${out}" "github_install_rc=1 calls=0"
out="$(run_module "${SBOX}" "termux_apps" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    _prompt_default() { printf "git"; }
    _has_command() { return 0; }
    check_storage_threshold() { return 0; }
    execute_structured() { printf "EXECUTED\\n"; return 0; }
    _termux_apps_install
')"
assert_contains "offline pkg application install is rejected" "${out}" "requires network access"
assert_not_contains "offline pkg application install does not execute pkg" "${out}" "EXECUTED"
out="$(run_module "${SBOX}" "linux_env" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    _has_command() { return 0; }
    _prompt_default() { printf "debian"; }
    _confirm() { return 0; }
    check_storage_threshold() { return 0; }
    execute_structured() { printf "EXECUTED\\n"; return 0; }
    _linux_env_install_distro
')"
assert_contains "offline proot distro installation is rejected" "${out}" "requires network access"
assert_not_contains "offline proot distro installation does not execute proot-distro" "${out}" "EXECUTED"
out="$(run_module "${SBOX}" "linux_env" '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/debian"
    DEVILS_MINIOS_OFFLINE_MODE=true
    _has_command() { return 0; }
    _prompt_default() { printf "debian"; }
    execute_structured() { printf "EXEC:%s:%s\\n" "$1" "$2"; return 0; }
    _linux_env_launch_distro
')"
assert_contains "offline installed distro launch remains allowed" "${out}" "EXEC:proot-distro:login"
out="$(run_module "${SBOX}" "system_tools" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    _prompt_default() { printf "%s/backup.tar.gz" "${HOME}"; }
    validate_path() { return 0; }
    execute_structured() { printf "EXEC:%s:%s\\n" "$1" "$2"; return 0; }
    _system_tools_backup
')"
assert_contains "offline backup remains allowed" "${out}" "EXEC:tar:-czf"
out="$(run_module "${SBOX}" "system_tools" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    backup="${HOME}/restore.tar.gz"
    : > "${backup}"
    _prompt_default() { printf "%s" "${backup}"; }
    validate_path() { return 0; }
    _confirm() { return 0; }
    execute_structured() { printf "EXEC:%s:%s\\n" "$1" "$2"; return 0; }
    load_config() { :; }
    load_state() { :; }
    _system_tools_restore
')"
assert_contains "offline restore remains allowed" "${out}" "EXEC:tar:-xzf"
out="$(run_module "${SBOX}" "android_tools" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    _has_command() { return 0; }
    execute_structured() { printf "EXEC:%s:%s\\n" "$1" "$2"; return 0; }
    _android_tools_adb
')"
assert_contains "offline adb operation remains allowed" "${out}" "EXEC:adb:devices"
out="$(run_core "${SBOX}" '
    DEVILS_MINIOS_OFFLINE_MODE=true
    DEVILS_MINIOS_CONFIG[check_updates]=true
    calls=0
    execute_structured() { calls=$((calls + 1)); return 1; }
    _has_command() { return 0; }
    _check_for_update_notice
    printf "update_check_calls=%s\\n" "$calls"
')"
assert_contains "offline startup update-check is skipped without network execution" "${out}" "update_check_calls=0"
section "PRD §15.2 no-checks matrix: security/integrity boundaries remain active"
SBOX_NC="$(new_sandbox)"
mkdir -p "${SBOX_NC}/home/.config/devils-minios"
printf 'bad_key=true\n' > "${SBOX_NC}/home/.config/devils-minios/config"
out="$(printf '0\\n' | HOME="${SBOX_NC}/home" PREFIX="${SBOX_NC}/usr" timeout 8 bash "${SBOX_NC}/usr/opt/devils-minios/devils-minios.sh" --no-checks 2>&1)" || true
assert_contains "--no-checks does not bypass configuration validation (unknown key -> E411, §48.2 CFG-UNKNOWN-KEY)" "${out}" "E411"
assert_not_contains "config validation failure is not reported under the E400 state/CLI code" "${out}" "[E400]"
section "PRD §15.2 --debug is session-only and active before module dispatch"
SBOX_DBG="$(new_sandbox)"
printf '0\\n' | HOME="${SBOX_DBG}/home" PREFIX="${SBOX_DBG}/usr" timeout 8 bash "${SBOX_DBG}/usr/opt/devils-minios/devils-minios.sh" --debug --run-module health_check >"${SBOX_DBG}/debug.out" 2>&1 || true
assert_file_exists "debug invocation creates launcher log" "${SBOX_DBG}/home/.config/devils-minios/logs/launcher.log"
debug_log="$(cat "${SBOX_DBG}/home/.config/devils-minios/logs/launcher.log" 2>/dev/null || true)"
assert_contains "--debug produces a DEBUG session log entry" "${debug_log}" "[DEBUG]"
cfg_after="$(cat "${SBOX_DBG}/home/.config/devils-minios/config" 2>/dev/null || true)"
assert_contains "--debug does not persist DEBUG log level" "${cfg_after}" $'log_level=INFO'
section "PRD §26.1 Safe Mode entry via core_init()'s own routing (not just load_config()'s return code in isolation)"
SBOX_INIT="$(new_sandbox)"
out="$(run_core "${SBOX_INIT}" '
    trigger_safe_mode() { printf "SAFE:%s\n" "$1"; DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"; }
    load_default_config >/dev/null; save_config >/dev/null
    printf "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  modules/core.sh\n" > "${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS"
    core_init 2>/dev/null
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "core_init() itself (not just load_config()) routes a tampered manifest into Safe Mode" "${out}" "SAFE:configuration/installation tamper detected (E412)"
assert_contains "state reaches SAFE_MODE via core_init()'s own routing" "${out}" "state=SAFE_MODE"
SBOX_RTC="$(new_sandbox)"
out="$(run_core "${SBOX_RTC}" '
    trigger_safe_mode() { printf "SAFE:%s\n" "$1"; DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"; }
    load_default_config >/dev/null; save_config >/dev/null
    default_state >/dev/null; save_state >/dev/null
    build_runtime_context() { DEVILS_MINIOS_TERMINAL_WIDTH="not-a-number"; DEVILS_MINIOS_UI_MODE="full"; }
    recover_runtime_temp_corrupt() { return 1; }
    core_init 2>/dev/null
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "core_init() routes a failed RUNTIME-TEMP-CORRUPT rebuild into Safe Mode (previously only unit-tested)" "${out}" "SAFE:RUNTIME-TEMP-CORRUPT: runtime context rebuild failed"
assert_contains "state reaches SAFE_MODE via the runtime-context recovery path" "${out}" "state=SAFE_MODE"
section "PRD §33.2 / §22.1 nuclear-reset revalidates its target path before mutating it"
SBOX_RESET2="$(new_sandbox)"
out="$(run_core "${SBOX_RESET2}" '
    rm -rf "${DEVILS_MINIOS_CONFIG_DIR}"
    real_target="$(dirname "${DEVILS_MINIOS_CONFIG_DIR}")/real-config-target"
    mkdir -p "${real_target}"
    ln -s "${real_target}" "${DEVILS_MINIOS_CONFIG_DIR}"
    DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"
    nuclear_reset >/dev/null 2>&1
    printf "reset_rc=%s\n" "$?"
    printf "target_survives=%s\n" "$([[ -d "${real_target}" ]] && echo yes || echo no)"
')"
assert_contains "nuclear reset refuses a symlinked config dir instead of mutating through it (E703)" "${out}" "reset_rc=2"
assert_contains "the symlink target is left untouched when nuclear reset refuses" "${out}" "target_survives=yes"
section "PRD §26 crash-window and crash-flag are independent (regression)"
out="$(run_core "${SBOX}" '
    now=$(date +%s)
    DEVILS_MINIOS_STATE[crash_loop_state]="$((now-500)),$((now-300))"
    _record_serious_crash "crash-a" >/dev/null 2>/dev/null
    IFS="," read -r -a window1 <<< "${DEVILS_MINIOS_STATE[crash_loop_state]}"
    _clear_crash_flag
    printf "flag_after_clear=%s\n" "$([[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && echo present || echo cleared)"
    IFS="," read -r -a window_after_clear <<< "${DEVILS_MINIOS_STATE[crash_loop_state]}"
    printf "window_len_before_clear=%s window_len_after_clear=%s\n" "${#window1[@]}" "${#window_after_clear[@]}"
    _record_serious_crash "crash-b" >/dev/null 2>/dev/null
    IFS="," read -r -a window2 <<< "${DEVILS_MINIOS_STATE[crash_loop_state]}"
    printf "window_len_after_second_crash=%s\n" "${#window2[@]}"
')"
assert_contains "clearing the crash flag removes only the flag file, not the crash-loop window" "${out}" "flag_after_clear=cleared"
assert_contains "crash-loop window is unaffected by the flag clearing (3 before, 3 after)" "${out}" "window_len_before_clear=3 window_len_after_clear=3"
assert_contains "a crash recorded after flag-clear continues the window (4th), not reset to 1" "${out}" "window_len_after_second_crash=4"
section "PRD §26 crash-loop routing and crash-flag Safe Mode entry"
out="$(HOME="${SBOX}/home" PREFIX="${SBOX}/usr" DEVILS_MINIOS_INSTALL_DIR="${SBOX}/usr/opt/devils-minios" XDG_CACHE_HOME="${SBOX}/home/.cache" bash -s 2>&1 <<SCRIPT
set +e
source "${SBOX}/usr/opt/devils-minios/devils-minios.sh"
set +e
trigger_safe_mode() { printf 'SAFE:%s\n' "\$1"; }
_record_serious_crash() { printf '3'; return 0; }
FLAG_SAFE_MODE=true
FLAG_OFFLINE=true
FLAG_NO_CHECKS=true
FLAG_DEBUG=true
false
_crash_trap 123
SCRIPT
)"
assert_contains "third crash routes unconditionally to Safe Mode" "${out}" "SAFE:crash-loop threshold reached (3 crashes in 10 minutes)"
SBOX_CRASH="$(new_sandbox)"
mkdir -p "${SBOX_CRASH}/home/.config/devils-minios"
printf 'created_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "${SBOX_CRASH}/home/.config/devils-minios/.crash-flag"
out="$(printf '0\\n' | HOME="${SBOX_CRASH}/home" PREFIX="${SBOX_CRASH}/usr" timeout 8 bash "${SBOX_CRASH}/usr/opt/devils-minios/devils-minios.sh" --no-checks 2>&1)" || true
assert_contains "non-stale crash flag enters Safe Mode" "${out}" "SAFE MODE"
section "§48.2 E603: startup low-storage diagnostic uses the registered insufficient-storage code"
out="$(DMOS_TEST_ROOT="${SBOX}/usr/opt/devils-minios" bash -s 2>&1 <<'SCRIPT'
set +e
source "${DMOS_TEST_ROOT}/devils-minios.sh"
set +e
DEVILS_MINIOS_NO_CHECKS=false
DEVILS_MINIOS_SAFE_MODE=false
check_storage_threshold() { return 3; }
_check_for_update_notice() { :; }
_run_startup_diagnostics
printf 'diag_rc=%s\n' "$?"
SCRIPT
)"
assert_contains "low storage at startup is reported with the registered E603" "${out}" "E603"
assert_not_contains "low storage at startup no longer uses unregistered E300" "${out}" "E300"
assert_contains "startup diagnostics stay non-blocking on low storage" "${out}" "diag_rc=0"
section "PRD-27.5-001: auto_launch=true with zero CLI arguments runs last_successful_workflow"
SBOX_AL="$(new_sandbox)"
mkdir -p "${SBOX_AL}/home/.config/devils-minios"
cat > "${SBOX_AL}/home/.config/devils-minios/config" <<'CFG'
config_version=1
theme=dracula
banner=devil
banner_animation=false
auto_launch=true
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
cat > "${SBOX_AL}/home/.config/devils-minios/state" <<'STATE'
state_version=1
primary_distro=
last_successful_workflow=system_info|view|system
onboarding_completion=true
crash_loop_state=
STATE
out="$(printf '0\n0\n' | HOME="${SBOX_AL}/home" PREFIX="${SBOX_AL}/usr" timeout 8 bash "${SBOX_AL}/usr/opt/devils-minios/devils-minios.sh" 2>&1)" || true
assert_contains "zero-argument launch with auto_launch=true dispatches the last successful workflow's module" "${out}" "System Info"
assert_not_contains "auto-launched bare invocation does not fall through to the interactive main menu" "${out}" "Main Menu"
section "PRD-27.5-001: auto_launch is ignored when any CLI flag is present"
SBOX_AL2="$(new_sandbox)"
mkdir -p "${SBOX_AL2}/home/.config/devils-minios"
cp "${SBOX_AL}/home/.config/devils-minios/config" "${SBOX_AL2}/home/.config/devils-minios/config"
cp "${SBOX_AL}/home/.config/devils-minios/state" "${SBOX_AL2}/home/.config/devils-minios/state"
out="$(printf '0\n' | HOME="${SBOX_AL2}/home" PREFIX="${SBOX_AL2}/usr" timeout 8 bash "${SBOX_AL2}/usr/opt/devils-minios/devils-minios.sh" --no-checks 2>&1)" || true
assert_not_contains "any CLI flag present (--no-checks) suppresses auto_launch dispatch, per §27.5" "${out}" "== System Info =="
section "PRD-27.5-001: with zero CLI arguments but no recorded last_successful_workflow, the main menu runs directly"
SBOX_AL3="$(new_sandbox)"
mkdir -p "${SBOX_AL3}/home/.config/devils-minios"
cp "${SBOX_AL}/home/.config/devils-minios/config" "${SBOX_AL3}/home/.config/devils-minios/config"
cat > "${SBOX_AL3}/home/.config/devils-minios/state" <<'STATE'
state_version=1
primary_distro=
last_successful_workflow=
onboarding_completion=true
crash_loop_state=
STATE
out="$(printf '0\n' | HOME="${SBOX_AL3}/home" PREFIX="${SBOX_AL3}/usr" timeout 8 bash "${SBOX_AL3}/usr/opt/devils-minios/devils-minios.sh" 2>&1)" || true
assert_not_contains "no recorded workflow means nothing is auto-dispatched" "${out}" "== System Info =="
section "PRD §26.3: persistent state rejects unknown keys and shell-shaped workflow values"
SBOX_STATE="$(new_sandbox)"
out="$(run_core "${SBOX_STATE}" '
    default_state; save_state >/dev/null 2>&1
    printf "state_version=1\nprimary_distro=\nlast_successful_workflow=system_info|view|system\nonboarding_completion=false\ncrash_loop_state=\nunknown_key=x\n" > "${DEVILS_MINIOS_STATE_FILE}"
    validate_state >/dev/null 2>&1; printf "unknown_rc=%s\n" "$?"
    printf "state_version=1\nprimary_distro=\nlast_successful_workflow=system_info;rm|view|system\nonboarding_completion=false\ncrash_loop_state=\n" > "${DEVILS_MINIOS_STATE_FILE}"
    validate_state >/dev/null 2>&1; printf "shell_rc=%s\n" "$?"
')"
assert_contains "unknown state key is rejected" "${out}" "unknown_rc=1"
assert_contains "shell-shaped workflow value is rejected on validation" "${out}" "shell_rc=1"
section "PRD §26.1: unrecoverable state is explicitly marked for FIRST_BOOT routing"
SBOX_STATE2="$(new_sandbox)"
out="$(run_core "${SBOX_STATE2}" '
    printf "state_version=999\nprimary_distro=\nlast_successful_workflow=\nonboarding_completion=false\ncrash_loop_state=\n" > "${DEVILS_MINIOS_STATE_FILE}"
    rm -f "${DEVILS_MINIOS_STATE_BACKUP}"
    DEVILS_MINIOS_STATE_RECOVERY_REINITIALIZED=false
    load_state; printf "rc=%s reinit=%s state_version=%s\n" "$?" "${DEVILS_MINIOS_STATE_RECOVERY_REINITIALIZED}" "${DEVILS_MINIOS_STATE[state_version]}"
')"
assert_contains "unrecoverable state is reinitialized and marked for FIRST_BOOT" "${out}" "rc=0 reinit=true state_version=1"
self_update_guard="$(grep -nE 'validate_path .*DEVILS_MINIOS_(UPDATE|INSTALL|BACKUP)|validate_path .*stage|validate_path .*previous|validate_path .*cache' core/devils_self_update.sh core/core_state.sh modules/system_tools.sh | wc -l | tr -d ' ')"
if (( self_update_guard >= 3 )); then pass "recursive deletion code has explicit validation guards"; else fail "recursive deletion code has explicit validation guards"; fi
print_summary "test_integration.sh"
