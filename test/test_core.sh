#!/usr/bin/env bash
# SC2016 disabled file-wide: snippets are single-quoted on purpose; run_core/run_module
# (test/lib/harness.sh) embed them verbatim in an inner `bash -s`, not this shell.
# shellcheck disable=SC2016
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/harness.sh
source "${SCRIPT_DIR}/lib/harness.sh"
section "Path accessors"
SBOX="$(new_sandbox)"
out="$(run_core "${SBOX}" '
    printf "cfg=%s\n" "$(get_config_dir)"
    printf "cache=%s\n" "$(get_cache_dir)"
    printf "bin=%s\n" "$(get_bin_dir)"
    printf "tmp=%s\n" "$(get_tmp_dir)"
    printf "etc=%s\n" "$(get_etc_dir)"
    printf "log=%s\n" "$(get_log_file)"
')"
assert_contains "get_config_dir returns HOME/.config/devils-minios" "${out}" "cfg=${SBOX}/home/.config/devils-minios"
assert_contains "get_cache_dir returns HOME/.cache/devils-minios" "${out}" "cache=${SBOX}/home/.cache/devils-minios"
assert_contains "get_bin_dir returns INSTALL_DIR/bin" "${out}" "bin=${SBOX}/usr/opt/devils-minios/bin"
assert_contains "get_tmp_dir returns config-dir tmp" "${out}" "tmp=${SBOX}/home/.config/devils-minios/tmp"
assert_contains "get_etc_dir returns INSTALL_DIR/data" "${out}" "etc=${SBOX}/usr/opt/devils-minios/data"
assert_contains "get_log_file returns log dir + launcher.log" "${out}" "log=${SBOX}/home/.config/devils-minios/logs/launcher.log"
section "Logging: level filtering and file creation"
out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    DEVILS_MINIOS_LOG_LEVEL=WARN
    write_log_file "DEBUG" "should-not-appear"
    write_log_file "INFO" "should-not-appear-either"
    write_log_file "WARN" "should-appear-warn"
    write_log_file "ERROR" "should-appear-error"
    cat "$(get_log_file)"
')"
assert_not_contains "DEBUG suppressed when log_level=WARN" "${out}" "should-not-appear"
assert_contains "WARN entry written at log_level=WARN" "${out}" "should-appear-warn"
assert_contains "ERROR entry written at log_level=WARN" "${out}" "should-appear-error"
out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    DEVILS_MINIOS_LOG_LEVEL=DEBUG
    write_log_file "DEBUG" "debug-now-appears"
    cat "$(get_log_file)"
')"
assert_contains "DEBUG entry written at log_level=DEBUG" "${out}" "debug-now-appears"
assert_contains "log entries are timestamped" "${out}" "[DEBUG] debug-now-appears"
section "Log rotation and purge"
SBOX2="$(new_sandbox)"
out="$(run_core "${SBOX2}" '
    mkdir -p "$(get_config_dir)/logs"
    log_file="$(get_log_file)"
    # Build an oversized log file (> DEVILS_MINIOS_LOG_MAX_BYTES) directly.
    head -c $((DEVILS_MINIOS_LOG_MAX_BYTES + 1000)) /dev/zero | tr "\0" "a" > "${log_file}"
    rotate_and_purge_logs
    [[ -f "${log_file}.1" ]] && printf "rotated=yes\n" || printf "rotated=no\n"
    printf "newsize=%s\n" "$(wc -c < "${log_file}")"
')"
assert_contains "oversized log is rotated into .1" "${out}" "rotated=yes"
assert_contains "active log truncated to empty after rotation" "${out}" "newsize=0"
out="$(run_core "${SBOX2}" '
    mkdir -p "$(get_config_dir)/logs"
    log_file="$(get_log_file)"
    old_ts="$(date -u -d "40 days ago" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
    recent_ts="$(date -u "+%Y-%m-%d %H:%M:%S")"
    printf "[%s] [INFO] old-entry-should-be-purged\n" "${old_ts}" > "${log_file}"
    printf "[%s] [INFO] recent-entry-should-survive\n" "${recent_ts}" >> "${log_file}"
    rotate_and_purge_logs
    cat "${log_file}"
')"
assert_not_contains "entries older than retention window are purged" "${out}" "old-entry-should-be-purged"
assert_contains "recent entries survive purge" "${out}" "recent-entry-should-survive"
section "Persistent state: save/load atomic write"
SBOX3="$(new_sandbox)"
out="$(run_core "${SBOX3}" '
    default_state
    DEVILS_MINIOS_STATE[primary_distro]="ubuntu"
    save_state
    [[ -f "${DEVILS_MINIOS_STATE_FILE}" ]] && printf "state_exists=yes\n"
    unset DEVILS_MINIOS_STATE
    declare -gA DEVILS_MINIOS_STATE=()
    load_state
    printf "primary_distro=%s\n" "${DEVILS_MINIOS_STATE[primary_distro]}"
')"
assert_contains "save_state writes the state file" "${out}" "state_exists=yes"
assert_contains "load_state round-trips a saved value" "${out}" "primary_distro=ubuntu"
section "State corruption -> state.bak restore"
out="$(run_core "${SBOX3}" '
    default_state
    DEVILS_MINIOS_STATE[primary_distro]="debian"
    save_state
    save_state
    printf "garbage not kv" > "${DEVILS_MINIOS_STATE_FILE}"
    unset DEVILS_MINIOS_STATE
    declare -gA DEVILS_MINIOS_STATE=()
    load_state
    printf "primary_distro=%s\n" "${DEVILS_MINIOS_STATE[primary_distro]:-}"
')"
assert_contains "corrupted state restores primary_distro from state.bak" "${out}" "primary_distro=debian"
assert_contains "§48.2 E406: state.bak restoration logs the registered code" "${out}" "E406"
section "Both state and state.bak invalid -> default reinitialization"
SBOX4="$(new_sandbox)"
out="$(run_core "${SBOX4}" '
    mkdir -p "$(get_config_dir)"
    printf "garbage\n" > "${DEVILS_MINIOS_STATE_FILE}"
    printf "also garbage\n" > "${DEVILS_MINIOS_STATE_BACKUP}"
    load_state
    printf "state_version=%s\n" "${DEVILS_MINIOS_STATE[state_version]}"
    printf "onboarding=%s\n" "${DEVILS_MINIOS_STATE[onboarding_completion]}"
')"
assert_contains "both state files invalid reinitializes state_version=1" "${out}" "state_version=1"
assert_contains "both state files invalid reinitializes onboarding_completion=false" "${out}" "onboarding=false"
section "E411 (CFG-BAD-VALUE): invalid config -> restore from defaults.conf, no config.bak recovery"
SBOX5="$(new_sandbox)"
out="$(run_core "${SBOX5}" '
    load_default_config
    DEVILS_MINIOS_CONFIG[theme]="nord"
    save_config
    save_config
    printf "garbage config\n" > "${DEVILS_MINIOS_CONFIG_FILE}"
    unset DEVILS_MINIOS_CONFIG
    declare -gA DEVILS_MINIOS_CONFIG=()
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "invalid config logs E411" "${out}" "E411"
assert_contains "invalid config self-heals with exit 0" "${out}" "rc=0"
assert_contains "invalid config restores the defaults.conf theme" "${out}" "theme=dracula"
assert_not_contains "invalid config recovery does not consult config.bak's last-known-good theme" "${out}" "theme=nord"
out="$(run_core "${SBOX5}" '
    printf "garbage\n" > "${DEVILS_MINIOS_CONFIG_FILE}"
    printf "garbage2\n" > "${DEVILS_MINIOS_CONFIG_BACKUP}"
    unset DEVILS_MINIOS_CONFIG
    declare -gA DEVILS_MINIOS_CONFIG=()
    load_config
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "config and backup both invalid falls back to default theme" "${out}" "theme=dracula"
section "E410 (CFG-MISSING): absent config -> regenerate from defaults.conf, self-healed"
SBOX9="$(new_sandbox)"
out="$(run_core "${SBOX9}" '
    [[ -f "${DEVILS_MINIOS_CONFIG_FILE}" ]] && printf "pre_exists=yes\n" || printf "pre_exists=no\n"
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    validate_config && printf "post_valid=yes\n" || printf "post_valid=no\n"
')"
assert_contains "no config file exists before load_config" "${out}" "pre_exists=no"
assert_contains "missing config logs E410" "${out}" "E410"
assert_contains "missing config self-heals with exit 0" "${out}" "rc=0"
assert_contains "regenerated config matches defaults.conf theme" "${out}" "theme=dracula"
assert_contains "regenerated config passes validate_config" "${out}" "post_valid=yes"
section "E411 (CFG-BAD-VALUE / CFG-UNKNOWN-KEY / forbidden runtime_context key)"
SBOX10="$(new_sandbox)"
out="$(run_core "${SBOX10}" '
    load_default_config
    save_config
    sed -i "s/^theme=.*/theme=not-a-real-theme/" "${DEVILS_MINIOS_CONFIG_FILE}"
    unset DEVILS_MINIOS_CONFIG
    declare -gA DEVILS_MINIOS_CONFIG=()
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "invalid known value (bad theme) logs E411" "${out}" "E411"
assert_contains "invalid known value recovers with exit 0" "${out}" "rc=0"
assert_contains "invalid known value restores default theme" "${out}" "theme=dracula"
out="$(run_core "${SBOX10}" '
    load_default_config
    save_config
    printf "unknown_key=1\n" >> "${DEVILS_MINIOS_CONFIG_FILE}"
    unset DEVILS_MINIOS_CONFIG
    declare -gA DEVILS_MINIOS_CONFIG=()
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "unknown key logs E411" "${out}" "E411"
assert_contains "unknown key recovers with exit 0" "${out}" "rc=0"
assert_contains "unknown key restores default theme" "${out}" "theme=dracula"
out="$(run_core "${SBOX10}" '
    load_default_config
    save_config
    printf "terminal_width=999\n" >> "${DEVILS_MINIOS_CONFIG_FILE}"
    unset DEVILS_MINIOS_CONFIG
    declare -gA DEVILS_MINIOS_CONFIG=()
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "runtime_context key present in persisted config logs E411" "${out}" "E411"
assert_contains "runtime_context key present recovers with exit 0" "${out}" "rc=0"
assert_contains "runtime_context key present restores default theme" "${out}" "theme=dracula"
section "E412 (CFG-TAMPER): installed manifest integrity failure -> no auto-recovery, Safe Mode routing"
SBOX11="$(new_sandbox)"
out="$(run_core "${SBOX11}" '
    load_default_config
    DEVILS_MINIOS_CONFIG[theme]="gruvbox"
    save_config
    printf "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  modules/core.sh\n" > "${DEVILS_MINIOS_INSTALL_DIR}/SHA256SUMS"
    load_config
    printf "rc=%s\n" "$?"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "installed manifest tamper logs E412 at ERROR level" "${out}" "ERROR [E412]"
assert_not_contains "E412 does not fall through to E411 self-heal" "${out}" "E411"
assert_not_contains "E412 does not fall through to E410 self-heal" "${out}" "E410"
assert_contains "installed manifest tamper: load_config returns non-zero (routes to Safe Mode / exit 1)" "${out}" "rc=1"
assert_contains "installed manifest tamper leaves in-memory config untouched (no auto-recover)" "${out}" "theme=gruvbox"
section "Crash-loop window (3 crashes in 10 minutes)"
SBOX6="$(new_sandbox)"
out="$(run_core "${SBOX6}" '
    default_state
    save_state
    now=$(date +%s)
    DEVILS_MINIOS_STATE[crash_loop_state]="$((now-500)),$((now-300))"
    save_state
    count="$(_record_serious_crash "test-crash")"
    printf "count=%s\n" "${count}"
')"
assert_contains "third crash within 10 minutes reports count=3" "${out}" "count=3"
assert_contains "§48.2 E900: _record_serious_crash logs the generic/unclassified crash code" "${out}" "E900"
out="$(run_core "${SBOX6}" '
    default_state
    save_state
    now=$(date +%s)
    DEVILS_MINIOS_STATE[crash_loop_state]="$((now-2000)),$((now-1900))"
    save_state
    count="$(_record_serious_crash "test-crash-outside-window")"
    printf "count=%s\n" "${count}"
')"
assert_contains "crashes older than 10 minutes fall out of the window" "${out}" "count=1"
section "Crash flag lifecycle (§26.5)"
SBOX7="$(new_sandbox)"
out="$(run_core "${SBOX7}" '
    printf "flag=%s\n" "$(_check_crash_flag)"
')"
assert_contains "absent crash flag reports absent" "${out}" "flag=absent"
out="$(run_core "${SBOX7}" '
    default_state; save_state
    _record_serious_crash "fresh-crash" >/dev/null
    printf "flag=%s\n" "$(_check_crash_flag)"
')"
assert_contains "freshly written crash flag reports active" "${out}" "flag=active"
out="$(run_core "${SBOX7}" '
    mkdir -p "$(get_config_dir)"
    old_ts="$(date -u -d "48 hours ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)"
    printf "created_at=%s\n" "${old_ts}" > "${DEVILS_MINIOS_CRASH_FLAG}"
    result="$(_check_crash_flag)"
    printf "flag=%s\n" "${result}"
    [[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && printf "flag_file=present\n" || printf "flag_file=cleared\n"
')"
assert_contains "stale (>24h) crash flag reports stale" "${out}" "flag=stale"
assert_contains "stale crash flag is cleared from disk" "${out}" "flag_file=cleared"
out="$(run_core "${SBOX7}" '
    mkdir -p "$(get_config_dir)"
    printf "not-a-valid-flag-body\n" > "${DEVILS_MINIOS_CRASH_FLAG}"
    printf "flag=%s\n" "$(_check_crash_flag)"
')"
assert_contains "unparseable crash flag fails closed as active" "${out}" "flag=active"
section "PRD §26.5 steps 5–6: IDLE entry clears only an old-session crash flag"
out="$(run_core "${SBOX7}" '
    printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${DEVILS_MINIOS_CRASH_FLAG}"
    DEVILS_MINIOS_SESSION_CRASH_RECORDED=false
    DEVILS_MINIOS_CURRENT_STATE="FIRST_BOOT"
    _enter_idle_state
    printf "stage5_flag=%s state=%s\n" "$([[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && echo present || echo cleared)" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "first successful IDLE entry clears a prior-session crash flag" "${out}" "stage5_flag=cleared"
assert_contains "first successful IDLE entry reaches IDLE" "${out}" "state=IDLE"
out="$(run_core "${SBOX7}" '
    printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${DEVILS_MINIOS_CRASH_FLAG}"
    DEVILS_MINIOS_SESSION_CRASH_RECORDED=true
    DEVILS_MINIOS_CURRENT_STATE="MODULE_RUNNING"
    _enter_idle_state
    printf "new_crash_flag=%s\n" "$([[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && echo present || echo cleared)"
')"
assert_contains "a new crash in the same session prevents IDLE clearing" "${out}" "new_crash_flag=present"
out="$(run_core "${SBOX7}" '
    printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${DEVILS_MINIOS_CRASH_FLAG}"
    DEVILS_MINIOS_SESSION_CRASH_RECORDED=false
    DEVILS_MINIOS_CURRENT_STATE="RECOVERY"
    record_state_transition "IDLE" >/dev/null 2>&1
    printf "stage6_flag=%s state=%s\n" "$([[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && echo present || echo cleared)" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "RECOVERY to IDLE clears the crash flag" "${out}" "stage6_flag=cleared"
assert_contains "RECOVERY to IDLE reaches IDLE" "${out}" "state=IDLE"
section "SIGINT handling"
out="$(run_core "${SBOX7}" '
    mkdir -p "$(get_config_dir)/logs"
    printf "n\n" | { handle_sigint; printf "returned=%s\n" "$?"; }
')"
assert_contains "declining SIGINT confirmation returns without exiting" "${out}" "returned=0"
status="$(HOME="${SBOX7}/home" PREFIX="${SBOX7}/usr" DEVILS_MINIOS_INSTALL_DIR="${SBOX7}/usr/opt/devils-minios" \
    bash -c 'set -uo pipefail; source "${DEVILS_MINIOS_INSTALL_DIR}/modules/core.sh"; mkdir -p "$(get_config_dir)/logs"; printf "y\n" | handle_sigint' >/dev/null 2>&1; printf '%s' "$?")"
assert_status "confirming SIGINT exits with status 130" 130 "${status}"
section "PRD §33.2 nuclear reset: quarantine, clean regeneration, asset restoration, RECOVERY→FIRST_BOOT"
SBOX_RESET="$(new_sandbox)"
out="$(run_core "${SBOX_RESET}" '
    mkdir -p "${DEVILS_MINIOS_CONFIG_DIR}/banners" "${DEVILS_MINIOS_CONFIG_DIR}/templates"
    printf "keep-banner\n" > "${DEVILS_MINIOS_CONFIG_DIR}/banners/custom.txt"
    printf "keep-template\n" > "${DEVILS_MINIOS_CONFIG_DIR}/templates/custom.txt"
    printf "old-config\n" > "${DEVILS_MINIOS_CONFIG_FILE}"
    printf "onboarding\n" > "${DEVILS_MINIOS_ONBOARDING_MARKER}"
    DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"
    nuclear_reset >/dev/null 2>&1
    rc=$?
    quarantine="$(find "$(dirname "${DEVILS_MINIOS_CONFIG_DIR}")" -maxdepth 1 -type d -name "devils-minios-corrupted-*" | head -1)"
    printf "reset_rc=%s state=%s quarantine=%s\n" "${rc}" "${DEVILS_MINIOS_CURRENT_STATE}" "${quarantine}"
    printf "banner=%s\n" "$(cat "${DEVILS_MINIOS_CONFIG_DIR}/banners/custom.txt" 2>/dev/null || true)"
    printf "template=%s\n" "$(cat "${DEVILS_MINIOS_CONFIG_DIR}/templates/custom.txt" 2>/dev/null || true)"
    printf "marker=%s\n" "$([[ -e "${DEVILS_MINIOS_ONBOARDING_MARKER}" ]] && echo present || echo absent)"
    printf "fresh_config=%s\n" "$(grep -c '^config_version=' "${DEVILS_MINIOS_CONFIG_FILE}" 2>/dev/null || true)"
')"
assert_contains "nuclear reset succeeds" "${out}" "reset_rc=0"
assert_contains "nuclear reset ends in FIRST_BOOT via RECOVERY" "${out}" "state=FIRST_BOOT"
assert_contains "nuclear reset creates a quarantined config sibling" "${out}" "quarantine="
assert_contains "nuclear reset restores validated banners" "${out}" "banner=keep-banner"
assert_contains "nuclear reset restores validated templates" "${out}" "template=keep-template"
assert_contains "nuclear reset removes onboarding marker" "${out}" "marker=absent"
assert_contains "nuclear reset regenerates clean default configuration" "${out}" "fresh_config=1"
section "State machine transition validation"
out="$(run_core "${SBOX7}" '
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    record_state_transition "MODULE_RUNNING"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "valid transition IDLE->MODULE_RUNNING succeeds" "${out}" "state=MODULE_RUNNING"
out="$(run_core "${SBOX7}" '
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    record_state_transition "UNINSTALLED" 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "invalid transition IDLE->UNINSTALLED must succeed per §39 table" "${out}" "rc=0"
out="$(run_core "${SBOX7}" '
    DEVILS_MINIOS_CURRENT_STATE="SAFE_MODE"
    record_state_transition "UNINSTALLED" 2>&1
    printf "rc=%s\n" "$?"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "invalid transition SAFE_MODE->UNINSTALLED is refused" "${out}" "rc=2"
assert_contains "state unchanged after refused transition" "${out}" "state=SAFE_MODE"
section "PRD-39 S6 P1-1 amendment: FIRST_BOOT->RECOVERY / FIRST_BOOT->SAFE_MODE (regression)"
out="$(run_core "${SBOX7}" '
    DEVILS_MINIOS_CURRENT_STATE="FIRST_BOOT"
    record_state_transition "RECOVERY" 2>&1
    printf "recovery_rc=%s\n" "$?"
    printf "recovery_state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
    DEVILS_MINIOS_CURRENT_STATE="FIRST_BOOT"
    record_state_transition "SAFE_MODE" 2>&1
    printf "safemode_rc=%s\n" "$?"
    printf "safemode_state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "FIRST_BOOT->RECOVERY is a legal transition (was missing, fixed)" "${out}" "recovery_rc=0"
assert_contains "FIRST_BOOT->RECOVERY actually transitions" "${out}" "recovery_state=RECOVERY"
assert_contains "FIRST_BOOT->SAFE_MODE is a legal transition (was missing, fixed)" "${out}" "safemode_rc=0"
assert_contains "FIRST_BOOT->SAFE_MODE actually transitions" "${out}" "safemode_state=SAFE_MODE"
section "core_init deterministic bootstrap"
SBOX8="$(new_sandbox)"
out="$(run_core "${SBOX8}" '
    core_init
    printf "config_dir_exists=%s\n" "$([[ -d $(get_config_dir) ]] && echo yes || echo no)"
    printf "log_file_has_entry=%s\n" "$(grep -c "Core runtime initialized" "$(get_log_file)" 2>/dev/null || echo 0)"
')"
assert_contains "core_init creates the config directory" "${out}" "config_dir_exists=yes"
assert_contains "core_init logs an initialization entry" "${out}" "log_file_has_entry=1"
section "_fsync_path is pure Bash (no Python runtime)"
if grep -qE 'python|python3' "${DMOS_PROJECT_ROOT}/modules/core.sh" 2>/dev/null; then
    fail "core.sh must not reference python/python3 anywhere"
else
    pass "core.sh has no python/python3 reference"
fi
out="$(run_core "${SBOX8}" '
    f="$(get_config_dir)/fsync-test.txt"
    printf "hello" > "${f}"
    _fsync_path "${f}"
    printf "rc=%s\n" "$?"
')"
assert_contains "_fsync_path succeeds without python3" "${out}" "rc=0"
section "sanitize_log_for_upload redacts paths, usernames, and IPs (§13.1/§49)"
out="$(run_core "${SBOX8}" '
    mkdir -p "$(get_config_dir)/logs"
    log="$(get_log_file)"
    printf "[INFO] connected to 192.168.1.42 as user in %s/workspaces/demo\n" "${HOME}" > "${log}"
    sanitize_log_for_upload "${log}"
')"
assert_not_contains "sanitized output no longer contains the raw HOME path" "${out}" "${SBOX8}/home/workspaces/demo"
assert_not_contains "sanitized output no longer contains the IP address" "${out}" "192.168.1.42"
assert_contains "sanitized output marks the redacted IP" "${out}" "<IP>"
assert_contains "sanitized output marks the redacted home path" "${out}" "<HOME>"
section "sanitize_log_for_upload can write to a destination file"
out="$(run_core "${SBOX8}" '
    mkdir -p "$(get_config_dir)/logs"
    log="$(get_log_file)"
    dest="$(get_config_dir)/sanitized.txt"
    printf "[INFO] path %s/secret\n" "${HOME}" > "${log}"
    sanitize_log_for_upload "${log}" "${dest}"
    printf "rc=%s\n" "$?"
    printf "exists=%s\n" "$([[ -f ${dest} ]] && echo yes || echo no)"
    grep -q "${HOME}" "${dest}" && printf "leaked=yes\n" || printf "leaked=no\n"
')"
assert_contains "sanitize_log_for_upload with dest exits 0" "${out}" "rc=0"
assert_contains "sanitize_log_for_upload writes the destination file" "${out}" "exists=yes"
assert_contains "destination file does not leak the raw HOME path" "${out}" "leaked=no"
section "PRD §26 crash record: atomic write + required fields + recent log context"
SBOXCR="$(new_sandbox)"
out="$(run_core "${SBOXCR}" '
    default_state
    save_state
    mkdir -p "${DEVILS_MINIOS_LOG_DIR}"
    write_log_file "INFO" "marker-line-for-crash-context"
    _record_serious_crash "unit-test-crash" >/dev/null 2>&1
    f="$(ls "${DEVILS_MINIOS_CRASH_DIR}"/crash-*.log 2>/dev/null | head -1)"
    printf "files=%s\n" "$(ls "${DEVILS_MINIOS_CRASH_DIR}" | wc -l)"
    printf "tmp_left=%s\n" "$(ls "${DEVILS_MINIOS_CRASH_DIR}" | grep -c "\.tmp\.")"
    for k in timestamp= context=unit-test-crash state= platform= recent_log_begin marker-line-for-crash-context recent_log_end; do
        grep -q -- "${k}" "${f}" && printf "has_%s=yes\n" "${k%%=*}" || printf "has_%s=no\n" "${k%%=*}"
    done
')"
assert_contains "crash record file exists" "${out}" "files=1"
assert_contains "no temp file left behind (atomic rename)" "${out}" "tmp_left=0"
assert_contains "record has timestamp" "${out}" "has_timestamp=yes"
assert_contains "record has error/context" "${out}" "has_context=yes"
assert_contains "record has current state" "${out}" "has_state=yes"
assert_contains "record has platform" "${out}" "has_platform=yes"
assert_contains "record embeds recent log context" "${out}" "has_marker-line-for-crash-context=yes"
section "PRD §26.5 step 7: Safe Mode config repair that validates clears the crash flag"
out="$(run_core "${SBOXCR}" '
    default_state; save_state
    printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${DEVILS_MINIOS_CRASH_FLAG}"
    _confirm() { return 0; }; _prompt_default() { printf "2"; }
    trigger_safe_mode "test" >/dev/null 2>&1
    [[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && printf "flag=present\n" || printf "flag=cleared\n"
    printf "state=%s\n" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "crash flag cleared after successful validated config repair" "${out}" "flag=cleared"
assert_contains "SAFE_MODE -> IDLE after config reset (§39)" "${out}" "state=IDLE"
section "PRD §40-002: Safe Mode config/state repairs require confirmation"
out="$(run_core "${SBOXCR}" '
    confirm_calls=0; _confirm() { confirm_calls=$((confirm_calls + 1)); return 0; }; _prompt_default() { printf "2"; }
    trigger_safe_mode "test" >/dev/null 2>&1; printf "config_confirm_calls=%s\n" "${confirm_calls}"
')"
assert_contains "Safe Mode config repair invokes confirmation before reset" "${out}" "config_confirm_calls=1"
out="$(run_core "${SBOXCR}" '
    confirm_calls=0; _confirm() { confirm_calls=$((confirm_calls + 1)); return 0; }; _prompt_default() { printf "3"; }
    trigger_safe_mode "test" >/dev/null 2>&1
    printf "state_confirm_calls=%s state=%s\n" "${confirm_calls}" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "Safe Mode state repair invokes confirmation before reset" "${out}" "state_confirm_calls=1"
assert_contains "SAFE_MODE -> IDLE after state reset (PRD-33.1-001, §39)" "${out}" "state=IDLE"
section "PRD §40.1-001: Safe Mode Proot relaunch requires a valid primary rootfs"
SBOXSM="$(new_sandbox)"
out="$(run_core "${SBOXSM}" '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}"
    default_state; DEVILS_MINIOS_STATE[primary_distro]=ubuntu; save_state
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    printf "rootfs_valid="; _safe_mode_primary_distro_valid_p && printf "yes\n" || printf "no\n"
    rm -rf "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"; ln -s "${HOME}" "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    printf "symlink_valid="; _safe_mode_primary_distro_valid_p && printf "yes\n" || printf "no\n"
')"
assert_contains "Safe Mode accepts a real contained primary rootfs" "${out}" "rootfs_valid=yes"
assert_contains "Safe Mode rejects a symlinked primary rootfs" "${out}" "symlink_valid=no"
section "PRD §40.1-001: Safe Mode Proot relaunch requires a valid primary rootfs"
SBOXSM="$(new_sandbox)"
out="$(run_core "${SBOXSM}" '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}"
    default_state; DEVILS_MINIOS_STATE[primary_distro]=ubuntu
    save_state
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    printf "rootfs_valid="; _safe_mode_primary_distro_valid_p && printf "yes\n" || printf "no\n"
    rm -rf "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    ln -s "${HOME}" "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    printf "symlink_valid="; _safe_mode_primary_distro_valid_p && printf "yes\n" || printf "no\n"
')"
assert_contains "Safe Mode accepts a real contained primary rootfs" "${out}" "rootfs_valid=yes"
assert_contains "Safe Mode rejects a symlinked primary rootfs" "${out}" "symlink_valid=no"
section "PRD §26.1 MOD-INIT-FAIL: failing module disabled for the session, others keep loading"
SBOXMI="$(new_sandbox)"
printf 'return 1\n' > "${SBOXMI}/usr/opt/devils-minios/modules/system_info.sh"
rm -f "${SBOXMI}/usr/opt/devils-minios/modules/workspace.sh"
out="$(run_core "${SBOXMI}" '
    mkdir -p "${DEVILS_MINIOS_LOG_DIR}"
    set -e
    _load_modules
    set +e
    printf "loader_completed=yes\n"
    printf "disabled=%s\n" "${DEVILS_MINIOS_DISABLED_MODULES[*]}"
    type settings_menu >/dev/null 2>&1 && printf "settings_loaded=yes\n" || printf "settings_loaded=no\n"
    dispatch_module info >/dev/null 2>&1; printf "info_rc=%s\n" "$?"
    dispatch_module workspace >/dev/null 2>&1; printf "workspace_rc=%s\n" "$?"
')"
assert_contains "loader completes under set -e despite a failing module" "${out}" "loader_completed=yes"
assert_contains "load-failing and missing modules are both disabled" "${out}" "disabled=workspace system_info"
assert_contains "unrelated modules still load" "${out}" "settings_loaded=yes"
assert_contains "dispatching a disabled module returns 1 (Unavailable), not a crash" "${out}" "info_rc=1"
assert_contains "dispatching a disabled (missing) module returns 1" "${out}" "workspace_rc=1"
run_platform_and_core_boundary_tests
print_summary "test_core.sh"
exit $?
