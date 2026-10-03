#!/usr/bin/env bash
# test_utils.sh - PRD §43.1: Utility functions defined in core.sh
# (string/path helpers, sanitizers, validation primitives).
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

section "_is_valid_key"
out="$(run_core "${SBOX}" '
    _is_valid_key "b" "a" "b" "c" && printf "found=yes\n" || printf "found=no\n"
    _is_valid_key "z" "a" "b" "c" && printf "missing=yes\n" || printf "missing=no\n"
')"
assert_contains "_is_valid_key finds a matching candidate" "${out}" "found=yes"
assert_contains "_is_valid_key rejects a non-matching candidate" "${out}" "missing=no"

section "_trim"
out="$(run_core "${SBOX}" '
    printf "[%s]\n" "$(_trim "   padded value   ")"
    printf "[%s]\n" "$(_trim "no-padding")"
    printf "[%s]\n" "$(_trim "")"
')"
assert_contains "_trim strips leading/trailing whitespace" "${out}" "[padded value]"
assert_contains "_trim leaves unpadded strings alone" "${out}" "[no-padding]"
assert_contains "_trim handles empty string" "${out}" "[]"

section "_is_int / _is_bool"
out="$(run_core "${SBOX}" '
    _is_int "123" && printf "int_123=yes\n" || printf "int_123=no\n"
    _is_int "-5" && printf "int_neg=yes\n" || printf "int_neg=no\n"
    _is_int "12a" && printf "int_12a=yes\n" || printf "int_12a=no\n"
    _is_int "" && printf "int_empty=yes\n" || printf "int_empty=no\n"
    _is_bool "true" && printf "bool_true=yes\n" || printf "bool_true=no\n"
    _is_bool "false" && printf "bool_false=yes\n" || printf "bool_false=no\n"
    _is_bool "yes" && printf "bool_yes=yes\n" || printf "bool_yes=no\n"
')"
assert_contains "_is_int accepts a positive integer" "${out}" "int_123=yes"
assert_contains "_is_int rejects a negative number (unsigned-only grammar)" "${out}" "int_neg=no"
assert_contains "_is_int rejects a non-numeric string" "${out}" "int_12a=no"
assert_contains "_is_int rejects empty string" "${out}" "int_empty=no"
assert_contains "_is_bool accepts 'true'" "${out}" "bool_true=yes"
assert_contains "_is_bool accepts 'false'" "${out}" "bool_false=yes"
assert_contains "_is_bool rejects 'yes'" "${out}" "bool_yes=no"

section "_has_command"
out="$(run_core "${SBOX}" '
    _has_command bash && printf "bash=yes\n" || printf "bash=no\n"
    _has_command definitely-not-a-real-command-xyz && printf "fake=yes\n" || printf "fake=no\n"
')"
assert_contains "_has_command finds bash on PATH" "${out}" "bash=yes"
assert_contains "_has_command reports missing for a bogus command" "${out}" "fake=no"

section "sanitize_input"
out="$(run_core "${SBOX}" '
    printf "[%s]\n" "$(sanitize_input "$(printf "abc\x01\x02def")" 1024)"
    trimmed="$(sanitize_input "0123456789" 5)"
    printf "trimmed=%s\n" "${trimmed}"
')"
assert_contains "sanitize_input strips control characters" "${out}" "[abcdef]"
assert_contains "sanitize_input truncates to max_length" "${out}" "trimmed=01234"

section "_validate_no_metacharacters (denylist grammar, §23.1)"
out="$(run_core "${SBOX}" '
    _validate_no_metacharacters "safe-value_1.2" && printf "safe=ok\n" || printf "safe=rejected\n"
    for bad in "a;b" "a&b" "a|b" "a\$(b)" "a\`b\`" "a<b" "a>b" "a(b)"; do
        if _validate_no_metacharacters "${bad}"; then
            printf "bad[%s]=accepted\n" "${bad}"
        else
            printf "bad[%s]=rejected\n" "${bad}"
        fi
    done
')"
assert_contains "safe value passes metacharacter validation" "${out}" "safe=ok"
assert_not_contains "no dangerous token is ever accepted" "${out}" "=accepted"

section "validate_path (traversal + base-dir confinement)"
out="$(run_core "${SBOX}" '
    mkdir -p "${HOME}/allowed/sub"
    validate_path "relative/file" && printf "relative=ok\n" || printf "relative=rejected\n"
    validate_path "../escape" && printf "dotdot=ok\n" || printf "dotdot=rejected\n"
    validate_path "a//b" && printf "doubleslash=ok\n" || printf "doubleslash=rejected\n"
    validate_path "${HOME}/allowed/sub/file.txt" "${HOME}/allowed" && printf "confined=ok\n" || printf "confined=rejected\n"
    validate_path "${HOME}/outside/file.txt" "${HOME}/allowed" && printf "escape_base=ok\n" || printf "escape_base=rejected\n"
')"
assert_contains "validate_path accepts a plain relative path with no base dir" "${out}" "relative=ok"
assert_contains "validate_path rejects .. traversal" "${out}" "dotdot=rejected"
assert_contains "validate_path rejects double-slash paths" "${out}" "doubleslash=rejected"
assert_contains "validate_path accepts a path confined to base_dir" "${out}" "confined=ok"
assert_contains "validate_path rejects a path escaping base_dir" "${out}" "escape_base=rejected"

section "validate_path: segment-based .. rejection (§22.1 step 2) does not false-positive on literal filenames"
out="$(run_core "${SBOX}" '
    mkdir -p "${HOME}/allowed2"
    validate_path "notes..old.txt" && printf "literal_dotdot_substring=ok\n" || printf "literal_dotdot_substring=rejected\n"
    validate_path "${HOME}/allowed2/notes..old.txt" "${HOME}/allowed2" && printf "literal_dotdot_confined=ok\n" || printf "literal_dotdot_confined=rejected\n"
    validate_path "${HOME}/allowed2/../escape" "${HOME}/allowed2" && printf "real_traversal=ok\n" || printf "real_traversal=rejected\n"
')"
assert_contains "a filename merely containing the substring .. (not a .. segment) is not falsely rejected" "${out}" "literal_dotdot_substring=ok"
assert_contains "same, confined to a base_dir, is still accepted" "${out}" "literal_dotdot_confined=ok"
assert_contains "an actual .. path segment is still rejected even inside a base_dir" "${out}" "real_traversal=rejected"

section "validate_path: nonexistent-parent containment is enforced via resolution, not skipped"
out="$(run_core "${SBOX}" '
    mkdir -p "${HOME}/allowed3"
    validate_path "${HOME}/allowed3/does/not/exist/yet.txt" "${HOME}/allowed3" && printf "nonexistent_confined=ok\n" || printf "nonexistent_confined=rejected\n"
    validate_path "${HOME}/notallowed3/does/not/exist/yet.txt" "${HOME}/allowed3" && printf "nonexistent_escape=ok\n" || printf "nonexistent_escape=rejected\n"
')"
assert_contains "a nonexistent-parent path that is still lexically inside base_dir is accepted" "${out}" "nonexistent_confined=ok"
assert_contains "a nonexistent-parent path outside base_dir is rejected, not silently allowed" "${out}" "nonexistent_escape=rejected"

section "is_external_storage_path"
out="$(run_core "${SBOX}" '
    is_external_storage_path "/sdcard/DCIM/photo.jpg" && printf "sdcard=external\n" || printf "sdcard=internal\n"
    is_external_storage_path "/storage/emulated/0/Download" && printf "storage=external\n" || printf "storage=internal\n"
    is_external_storage_path "${HOME}/file.txt" && printf "home=external\n" || printf "home=internal\n"
')"
assert_contains "/sdcard paths are classified external" "${out}" "sdcard=external"
assert_contains "/storage/emulated paths are classified external" "${out}" "storage=external"
assert_contains "HOME paths are classified internal" "${out}" "home=internal"

# --- §43.5 traceability closure tests (PRD-12-01/02, §13.1 function coverage); kept here so test_core.sh stays under 500 lines ---
section "PRD-12-01/02: exactly 14 modules, no future_plans.sh"
mod_count="$(find "${DMOS_PROJECT_ROOT}/modules" -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')"
assert_eq "PRD-12-01: exactly 14 files under modules/" "14" "${mod_count}"
assert_eq "PRD-12-02: no future_plans file exists anywhere" "0" "$(find "${DMOS_PROJECT_ROOT}" -iname '*future_plans*' | wc -l | tr -d ' ')"
assert_eq "PRD-12-02: no source references future_plans" "0" "$(grep -rl 'future_plans' "${DMOS_PROJECT_ROOT}/modules" "${DMOS_PROJECT_ROOT}/core" "${DMOS_PROJECT_ROOT}/devils-minios.sh" 2>/dev/null | wc -l | tr -d ' ')"

section "§13.1 detect_terminal_width / detect_termux_source / warn_play_store / warn_proot_limits"
SBOX_PLAT="$(new_sandbox)"
out="$(run_core "${SBOX_PLAT}" '
    COLUMNS=80 detect_terminal_width; printf "w80=%s mode=%s\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}" "${DEVILS_MINIOS_UI_MODE}"
    COLUMNS=50 detect_terminal_width; printf "w50=%s mode=%s\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}" "${DEVILS_MINIOS_UI_MODE}"
    COLUMNS=30 detect_terminal_width; printf "w30=%s mode=%s\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}" "${DEVILS_MINIOS_UI_MODE}"
')"
assert_contains "detect_terminal_width: >=60 columns -> full" "${out}" "w80=80 mode=full"
assert_contains "detect_terminal_width: 40-59 columns -> compact" "${out}" "w50=50 mode=compact"
assert_contains "detect_terminal_width: <40 columns -> minimal" "${out}" "w30=30 mode=minimal"
out="$(run_core "${SBOX_PLAT}" '
    unset COLUMNS
    tput() { [[ "$1" == "cols" ]] && printf "55\n"; }
    detect_terminal_width; printf "tput=%s mode=%s\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}" "${DEVILS_MINIOS_UI_MODE}"
    unset -f tput
    COLUMNS=; detect_terminal_width; printf "fallback=%s mode=%s\n" "${DEVILS_MINIOS_TERMINAL_WIDTH}" "${DEVILS_MINIOS_UI_MODE}"
')"
assert_contains "detect_terminal_width uses tput fallback" "${out}" "tput=55 mode=compact"
assert_contains "detect_terminal_width falls back to 80" "${out}" "fallback=80 mode=full"
out="$(run_core "${SBOX_PLAT}" '
    TERMUX_APK_RELEASE=github detect_termux_source; printf "gh=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
    TERMUX_APK_RELEASE=f-droid detect_termux_source; printf "fd=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
    TERMUX_APK_RELEASE=playstore detect_termux_source; printf "ps=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
')"
assert_contains "detect_termux_source: github build" "${out}" "gh=github"
assert_contains "detect_termux_source: f-droid build" "${out}" "fd=f-droid"
assert_contains "detect_termux_source: play-store build" "${out}" "ps=play-store"

section "PRD-19.1-001: per-mode UI features (box drawing / banner / label length)"
out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    DEVILS_MINIOS_TERMINAL_WIDTH=80; DEVILS_MINIOS_UI_MODE=full; show_main_menu_full
    printf "END-FULL\n"
')"
assert_contains "Full mode draws a box (top-left corner glyph present)" "${out}" "╔"
assert_contains "Full mode shows the full module label" "${out}" "File Manager"

out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    DEVILS_MINIOS_UI_MODE=compact; show_main_menu_compact
    printf "END-COMPACT\n"
')"
assert_not_contains "Compact mode does NOT draw a box (no box-drawing glyphs)" "${out}" "╔"
assert_contains "Compact mode still shows the full module label" "${out}" "File Manager"

out="$(run_core "${SBOX}" '
    mkdir -p "$(get_config_dir)/logs"
    DEVILS_MINIOS_UI_MODE=minimal; show_main_menu_minimal
    printf "END-MINIMAL\n"
')"
assert_not_contains "Minimal mode does NOT draw a box" "${out}" "╔"
assert_not_contains "Minimal mode does NOT show the banner (ASCII art)" "${out}" "____"
assert_contains "Minimal mode uses short module keys, not the full label" "${out}" "file_mgr"
assert_not_contains "Minimal mode omits the long descriptive label" "${out}" "File Manager"

out="$(run_core "${SBOX}" '
    unset TERMUX_APK_RELEASE
    PREFIX="/data/data/com.termux/files/usr" detect_termux_source; printf "prefix_fdroid=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
    PREFIX="/data/data/com.termux.playstore/files/usr" detect_termux_source; printf "prefix_ps=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
    PREFIX="/opt/something-else" detect_termux_source; printf "prefix_unknown=%s\n" "${DEVILS_MINIOS_TERMUX_SOURCE}"
')"
assert_contains "detect_termux_source: \$PREFIX f-droid inference (PRD-35.1-001)" "${out}" "prefix_fdroid=f-droid"
assert_contains "detect_termux_source: \$PREFIX play-store inference (PRD-35.1-001)" "${out}" "prefix_ps=play-store"
assert_contains "detect_termux_source: unrecognised \$PREFIX falls back to unknown (PRD-35.1-001)" "${out}" "prefix_unknown=unknown"
out="$(run_core "${SBOX_PLAT}" '
    DEVILS_MINIOS_TERMUX_SOURCE=play-store; warn_play_store
    DEVILS_MINIOS_TERMUX_SOURCE=f-droid; printf "BEGIN-FDROID\n"; warn_play_store; printf "END-FDROID\n"
')"
assert_contains "warn_play_store: warns for a Play Store build" "${out}" "Play Store or unknown Termux source detected"
assert_not_contains "warn_play_store: silent for an F-Droid build" "$(printf '%s' "${out}" | sed -n '/BEGIN-FDROID/,/END-FDROID/p')" "WARNING"
out="$(run_core "${SBOX_PLAT}" 'warn_proot_limits')"
assert_contains "warn_proot_limits: states proot is not kernel virtualization" "${out}" "not kernel virtualization"

section "§13.1 draw_box_top / draw_box_line / draw_box_bottom"
out="$(run_core "${SBOX_PLAT}" 'draw_box_top 20; draw_box_line 20 "hi"; draw_box_bottom 20')"
assert_eq "draw_box_*: emits exactly three lines" "3" "$(printf '%s\n' "${out}" | wc -l | tr -d ' ')"
assert_contains "draw_box_line: renders its text between side glyphs" "${out}" "║ hi"
assert_contains "draw_box_top: uses the corner glyphs" "${out}" "╔"
assert_contains "draw_box_bottom: uses the corner glyphs" "${out}" "╝"

section "§13.1 apply_theme / set_banner / error_handler / check_storage_threshold"
out="$(run_core "${SBOX_PLAT}" '
    apply_theme "not-a-theme" >/dev/null 2>&1; printf "bad_theme_rc=%s\n" "$?"
    apply_theme nord >/dev/null 2>&1; printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    set_banner "not-a-banner" >/dev/null 2>&1; printf "bad_banner_rc=%s\n" "$?"
    set_banner minimal >/dev/null 2>&1; printf "banner=%s\n" "${DEVILS_MINIOS_CONFIG[banner]}"
')"
assert_contains "apply_theme: unknown theme rejected with status 2" "${out}" "bad_theme_rc=2"
assert_contains "apply_theme: valid theme is applied" "${out}" "theme=nord"
assert_contains "set_banner: unknown banner rejected with status 2" "${out}" "bad_banner_rc=2"
assert_contains "set_banner: valid banner is applied" "${out}" "banner=minimal"
out="$(run_core "${SBOX_PLAT}" 'error_handler; printf "rc=%s\n" "$?"; error_handler E406 "custom"; printf "rc=%s\n" "$?"')"
assert_contains "error_handler: defaults to E900" "${out}" "ERROR [E900]: Unknown error"
assert_contains "error_handler: honors a supplied code and message" "${out}" "ERROR [E406]: custom"
assert_contains "error_handler: returns status 1" "${out}" "rc=1"
FAKE_DF_CORE="$(mktemp -d)"
cat > "${FAKE_DF_CORE}/df" <<'FAKEDF'
#!/usr/bin/env bash
printf 'Filesystem     1B-blocks       Used  Available Use%% Mounted on\n'
printf 'fakefs         1000000000  999999999          1   99%% /\n'
FAKEDF
chmod 755 "${FAKE_DF_CORE}/df"
out="$(run_core "${SBOX_PLAT}" '
    PATH="'"${FAKE_DF_CORE}"':${PATH}" check_storage_threshold 1000; printf "rc=%s\n" "$?"
')"
assert_contains "check_storage_threshold: insufficient storage logs E603" "${out}" "E603"
assert_contains "check_storage_threshold: insufficient storage returns 3" "${out}" "rc=3"
out="$(run_core "${SBOX_PLAT}" 'check_storage_threshold 0; printf "rc=%s\n" "$?"')"
assert_contains "check_storage_threshold: returns 0 when space suffices" "${out}" "rc=0"
rm -rf "${FAKE_DF_CORE}"

section "§25.1 / §43.3 battery gate: <=9% block, 10-20% inclusive confirm, >=21% continue"
out="$(run_core "${SBOX_PLAT}" '
    _confirm() { printf "CONFIRM_ASKED\n"; return 0; }
    bat_out="${TMPDIR:-/tmp}/dmos_bat_$$.out"
    for pct in 0 9 10 20 21 100; do
        _get_battery_percent() { printf "%s" "${PCT}"; }
        PCT=${pct}; check_battery_gate "test op" >"${bat_out}" 2>&1; rc=$?
        printf "pct%s_rc=%s asked=%s\n" "${pct}" "${rc}" "$(grep -c CONFIRM_ASKED "${bat_out}")"
    done
    rm -f "${bat_out}"
    _confirm() { return 1; }
    PCT=15; check_battery_gate "test op" >/dev/null 2>&1; printf "pct15_declined_rc=%s\n" "$?"
')"
assert_contains "battery 0% is blocked (status 3), no confirmation offered" "${out}" "pct0_rc=3 asked=0"
assert_contains "battery 9% is blocked (status 3), boundary inclusive" "${out}" "pct9_rc=3 asked=0"
assert_contains "battery 10% requires confirmation (lower inclusive bound)" "${out}" "pct10_rc=0 asked=1"
assert_contains "battery 20% requires confirmation (upper inclusive bound)" "${out}" "pct20_rc=0 asked=1"
assert_contains "battery 21% continues with no confirmation" "${out}" "pct21_rc=0 asked=0"
assert_contains "battery 100% continues with no confirmation" "${out}" "pct100_rc=0 asked=0"
assert_contains "declined low-battery confirmation returns status 4 (user abort)" "${out}" "pct15_declined_rc=4"

section "§25.2 / §43.3 Termux:API absent: battery gate fails open with exactly one WARN per launch"
SBOX_BAT="$(new_sandbox)"
out="$(run_core "${SBOX_BAT}" '
    mkdir -p "${DEVILS_MINIOS_LOG_DIR}"
    _has_command() { [[ "$1" == "termux-battery-status" ]] && return 1; command -v "$1" >/dev/null 2>&1; }
    check_battery_gate "op one" >/dev/null 2>&1; printf "first_rc=%s\n" "$?"
    check_battery_gate "op two" >/dev/null 2>&1; printf "second_rc=%s\n" "$?"
    printf "warn_count=%s\n" "$(grep -c "WARN.*battery level unavailable; proceeding" "${DEVILS_MINIOS_LOG_DIR}/launcher.log" 2>/dev/null)"
    printf "malformed_code=%s\n" "$(grep -c "\[battery level unavailable" "${DEVILS_MINIOS_LOG_DIR}/launcher.log" 2>/dev/null)"
')"
assert_contains "no Termux:API: first gate call proceeds (status 0, no hard block)" "${out}" "first_rc=0"
assert_contains "no Termux:API: second gate call proceeds (status 0)" "${out}" "second_rc=0"
assert_contains "exactly one 'battery level unavailable; proceeding' WARN per launch" "${out}" "warn_count=1"
assert_contains "WARN text is the message itself, not misplaced into the code field" "${out}" "malformed_code=0"

section "§25.1 / §43.3 storage rule: allow iff available >= required + 100 MB safety margin (exact boundary)"
FAKE_DF_B="$(mktemp -d)"
cat > "${FAKE_DF_B}/df" <<'FAKEDF2'
#!/usr/bin/env bash
printf 'Filesystem 1B-blocks Used Available Use%% Mounted\nfake 999999999999 0 %s 0%% /\n' "${FAKE_AVAILABLE}"
FAKEDF2
chmod 755 "${FAKE_DF_B}/df"
out="$(run_core "${SBOX_PLAT}" '
    export PATH="'"${FAKE_DF_B}"':${PATH}"
    printf "margin=%s\n" "${DEVILS_MINIOS_SAFETY_MARGIN_BYTES}"
    FAKE_AVAILABLE=$((1000 + 104857600)) check_storage_threshold 1000 >/dev/null 2>&1; printf "exact_rc=%s\n" "$?"
    FAKE_AVAILABLE=$((1000 + 104857600 - 1)) check_storage_threshold 1000 >/dev/null 2>&1; printf "short_by_one_rc=%s\n" "$?"
    printf "defaults=%s,%s,%s\n" "${DEVILS_MINIOS_DEFAULT_DISTRO_REQUIRED_BYTES}" "${DEVILS_MINIOS_DEFAULT_DESKTOP_REQUIRED_BYTES}" "${DEVILS_MINIOS_DEFAULT_APP_REQUIRED_BYTES}"
')"
rm -rf "${FAKE_DF_B}"
assert_contains "safety_margin_bytes is the fixed 104,857,600 constant" "${out}" "margin=104857600"
assert_contains "available == required + margin is allowed (status 0)" "${out}" "exact_rc=0"
assert_contains "available one byte short of required + margin is rejected (status 3)" "${out}" "short_by_one_rc=3"
assert_contains "per-operation fixed defaults: distro 1 GiB, desktop 300 MB, app 100 MB" "${out}" "defaults=1073741824,314572800,104857600"

section "§13.1 restore_state_from_backup / trigger_safe_mode / show_banner / run_desktop_startup"
SBOX_R="$(new_sandbox)"
DEVILS_MINIOS_VERSION_EXPECTED="$(run_core "${SBOX_R}" 'printf "%s" "${DEVILS_MINIOS_VERSION}"')"
assert_ne "banner version source is non-empty" "" "${DEVILS_MINIOS_VERSION_EXPECTED}"
out="$(run_core "${SBOX_R}" '
    default_state
    DEVILS_MINIOS_STATE[primary_distro]=debian
    save_state
    save_state
    printf "garbage not kv" > "${DEVILS_MINIOS_STATE_FILE}"
    restore_state_from_backup; printf "restore_rc=%s\n" "$?"
    rm -f "${DEVILS_MINIOS_STATE_BACKUP}"
    printf "garbage not kv" > "${DEVILS_MINIOS_STATE_FILE}"
    restore_state_from_backup; printf "nobackup_rc=%s\n" "$?"
')"
assert_contains "restore_state_from_backup: valid state.bak is restored (status 0)" "${out}" "restore_rc=0"
assert_contains "restore_state_from_backup: restoration logs E406" "${out}" "E406"
assert_contains "restore_state_from_backup: absent backup returns status 1" "${out}" "nobackup_rc=1"
assert_contains "restore_state_from_backup: absent backup logs E405" "${out}" "E405"

out="$(run_core "${SBOX_R}" '
    DEVILS_MINIOS_CURRENT_STATE="IDLE"
    printf "2\n" | trigger_safe_mode "direct-test-reason"
    printf "rc=%s state=%s\n" "$?" "${DEVILS_MINIOS_CURRENT_STATE}"
')"
assert_contains "trigger_safe_mode: shows the Safe Mode banner" "${out}" "SAFE MODE"
assert_contains "trigger_safe_mode: shows the supplied reason" "${out}" "direct-test-reason"
assert_contains "trigger_safe_mode: repair-config option (2) returns 0 and leaves state IDLE" "${out}" "rc=0 state=IDLE"

out="$(run_core "${SBOX_R}" '
    DEVILS_MINIOS_UI_MODE=minimal; DEVILS_MINIOS_CONFIG[banner]=simple; show_banner; printf "END-MINIMAL-UI\n"
    DEVILS_MINIOS_UI_MODE=full
    DEVILS_MINIOS_CONFIG[banner]=simple; show_banner
    DEVILS_MINIOS_CONFIG[banner]=minimal; show_banner
    DEVILS_MINIOS_CONFIG[banner]=cyber; show_banner
    DEVILS_MINIOS_CONFIG[banner]=retro; show_banner
')"
assert_eq "show_banner: minimal UI mode prints nothing" "END-MINIMAL-UI" "$(printf '%s\n' "${out}" | head -1)"
assert_contains "show_banner: simple banner carries the version" "${out}" "Devil's Mini OS Launcher v${DEVILS_MINIOS_VERSION_EXPECTED}"
assert_contains "show_banner: minimal banner" "${out}" "Devil's Mini OS Launcher"
assert_contains "show_banner: cyber banner" "${out}" ">> DEVILS://MINI-OS :: LAUNCHER v${DEVILS_MINIOS_VERSION_EXPECTED}"
assert_contains "show_banner: retro banner" "${out}" "DEVIL'S MINI OS LAUNCHER v${DEVILS_MINIOS_VERSION_EXPECTED}"

out="$(run_core "${SBOX_R}" '
    run_desktop_startup ubuntu notabinary >/dev/null 2>&1; printf "badbin_rc=%s\n" "$?"
    run_desktop_startup nosuchdistro startxfce4 >/dev/null 2>&1; printf "baddistro_rc=%s\n" "$?"
    run_desktop_startup ubuntu startxfce4 >/dev/null 2>&1; printf "norootfs_rc=%s\n" "$?"
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    run_desktop_startup ubuntu startxfce4 "bad;arg" >/dev/null 2>&1; printf "badtoken_rc=%s\n" "$?"
')"
assert_contains "run_desktop_startup: non-allowlisted startup_binary rejected (status 2)" "${out}" "badbin_rc=2"
assert_contains "run_desktop_startup: unknown distro rejected (status 2)" "${out}" "baddistro_rc=2"
assert_contains "run_desktop_startup: missing rootfs returns status 3" "${out}" "norootfs_rc=3"
assert_contains "run_desktop_startup: metacharacter arg token rejected (status 2)" "${out}" "badtoken_rc=2"

# --- §43.4 CI / static validation (repo-level; pure Bash/grep/find, no external runtime) ---
section "§43.4 static validation: syntax, size limits, structure"
_syn_bad=0; _big=""; _sh_n=0
while IFS= read -r _f; do
    _sh_n=$((_sh_n + 1))
    bash -n "${_f}" 2>/dev/null || _syn_bad=$((_syn_bad + 1))
    _ln="$(wc -l < "${_f}" | tr -d ' ')"
    [[ "${_f}" == */test/run_all.sh ]] && continue
    [[ ${_ln} -lt 500 ]] || _big+="${_f}(${_ln}) "
done < <(find "${DMOS_PROJECT_ROOT}" -name '*.sh' -not -path '*/.git/*' | sort)
assert_eq "§43.4: at least 46 shell files were scanned" "1" "$([[ ${_sh_n} -ge 46 ]] && echo 1 || echo 0)"
assert_eq "§43.4: every .sh file passes bash -n" "0" "${_syn_bad}"
assert_eq "§43.4: every .sh file is <500 lines (run_all.sh exempt)" "" "${_big}"
assert_eq "§43.4: exactly 19 mandatory test files" "19" "$(find "${DMOS_PROJECT_ROOT}/test" -maxdepth 1 -name 'test_*.sh' | wc -l | tr -d ' ')"
assert_eq "§43.4: no plugins directory" "0" "$(find "${DMOS_PROJECT_ROOT}" -iname 'plugins' -not -path '*/.git/*' | wc -l | tr -d ' ')"
assert_eq "§43.4: no compiled/foreign-runtime launcher files" "0" "$(find "${DMOS_PROJECT_ROOT}" -not -path '*/.git/*' \( -name '*.py' -o -name '*.js' -o -name '*.go' -o -name '*.rs' -o -name '*.c' -o -name '*.o' -o -name '*.so' -o -name '*.class' \) | wc -l | tr -d ' ')"
assert_eq "§43.4: install.sh is <500 lines" "1" "$([[ $(wc -l < "${DMOS_PROJECT_ROOT}/install.sh") -lt 500 ]] && echo 1 || echo 0)"

section "PRD-17.5-001: all 11 persisted defaults are exact"
assert_eq "default config_version" "1" "$(sed -n 's/^config_version=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default theme" "dracula" "$(sed -n 's/^theme=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default banner" "devil" "$(sed -n 's/^banner=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default banner_animation" "false" "$(sed -n 's/^banner_animation=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default auto_launch" "false" "$(sed -n 's/^auto_launch=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default health_check_interval" "1800" "$(sed -n 's/^health_check_interval=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default log_level" "INFO" "$(sed -n 's/^log_level=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default check_updates" "false" "$(sed -n 's/^check_updates=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default language" "en" "$(sed -n 's/^language=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default network_timeout" "30" "$(sed -n 's/^network_timeout=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"
assert_eq "default network_retries" "3" "$(sed -n 's/^network_retries=//p' "${DMOS_PROJECT_ROOT}/data/defaults.conf")"

section "§43.4 static validation: forbidden constructs (§23 no dynamic shell evaluation, §4 no curl|bash)"
_src=("${DMOS_PROJECT_ROOT}/devils-minios.sh" "${DMOS_PROJECT_ROOT}/install.sh" "${DMOS_PROJECT_ROOT}/modules" "${DMOS_PROJECT_ROOT}/core")
assert_eq "§43.4: no 'eval' in launcher/installer sources" "0" "$(grep -rEn '(^|[;&|(]|[[:space:]])eval[[:space:]]' --include='*.sh' "${_src[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | wc -l | tr -d ' ')"
assert_eq "§43.4: no 'sh -c' / 'bash -c' in launcher/installer sources" "0" "$(grep -rEn '(^|[^A-Za-z_])(ba)?sh[[:space:]]+-c([[:space:]]|$)' --include='*.sh' "${_src[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | wc -l | tr -d ' ')"
assert_eq "§43.4: no curl|bash / wget|bash pipelines in sources" "0" "$(grep -rEn '(curl|wget)[^#]*\|[[:space:]]*(ba)?sh' --include='*.sh' "${_src[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | wc -l | tr -d ' ')"
assert_eq "§43.4: no sudo/su privilege escalation in sources" "0" "$(grep -rEn '(^|[;&|(]|[[:space:]])(sudo|su)[[:space:]]+-?[A-Za-z]' --include='*.sh' "${_src[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#|"[^"]*(sudo|su)[[:space:]]' | wc -l | tr -d ' ')"

section "§43.4 static validation: catalogs, version, docs, manifest"
_db="${DMOS_PROJECT_ROOT}/data/proot_apps.db"
assert_eq "§18.2/§43.4: proot_apps.db has exactly 40 records" "40" "$(grep -vc '^#\|^$' "${_db}")"
assert_eq "§18.2/§43.4: every proot_apps.db record has exactly 7 fields" "0" "$(grep -v '^#\|^$' "${_db}" | awk -F'|' 'NF!=7' | wc -l | tr -d ' ')"
assert_eq "§18.2/§43.4: proot_apps.db represents exactly 13 categories" "13" "$(grep -v '^#\|^$' "${_db}" | cut -d'|' -f3 | sort -u | wc -l | tr -d ' ')"
assert_eq "§21/§43.4: installer and launcher versions agree" "$(sed -n 's/^readonly INSTALLER_VERSION="\(.*\)"/\1/p' "${DMOS_PROJECT_ROOT}/install.sh")" "$(sed -n 's/^readonly DEVILS_MINIOS_VERSION="\(.*\)"/\1/p' "${DMOS_PROJECT_ROOT}/modules/core.sh")"
_docs_missing=""
for _d in INSTALL MODULES TROUBLESHOOTING COMPATIBILITY SECURITY CHANGELOG DATA TRACEABILITY; do
    [[ -f "${DMOS_PROJECT_ROOT}/docs/${_d}.md" ]] || _docs_missing+="${_d} "
done
[[ -f "${DMOS_PROJECT_ROOT}/README.md" ]] || _docs_missing+="README "
assert_eq "§50/§43.4: all required documentation files exist" "" "${_docs_missing}"
_trace_header="$(grep -m1 '^| Requirement ID |' "${DMOS_PROJECT_ROOT}/docs/TRACEABILITY.md" || true)"
assert_eq "§43.5.2: traceability matrix has exactly 13 required columns" "13" "$(printf '%s\n' "${_trace_header}" | awk -F'|' '{print NF-2}')"
assert_contains "§43.5.2: traceability matrix contains Rationale column" "${_trace_header}" "Rationale"
assert_contains "§43.5.2: traceability matrix contains Accountable Owner column" "${_trace_header}" "Accountable Owner"
assert_contains "§43.5.2: traceability matrix contains Approval Authority column" "${_trace_header}" "Approval Authority"
_trace_bad_rows="$(awk '/^\| PRD-/{line=$0; gsub(/\\\|/,"__PIPE__",line); n=split(line,a,"\|"); if (n-2 != 13) bad++} END{print bad+0}' "${DMOS_PROJECT_ROOT}/docs/TRACEABILITY.md")"
assert_eq "§43.5.2: every requirement row has exactly 13 columns" "0" "${_trace_bad_rows}"
_trace_empty_owner="$(awk '/^\| PRD-/{line=$0; gsub(/\\\|/,"__PIPE__",line); n=split(line,a,"\|"); if (n-2==13 && (a[5]=="" || a[6]=="" || a[7]=="")) bad++} END{print bad+0}' "${DMOS_PROJECT_ROOT}/docs/TRACEABILITY.md")"
assert_eq "§43.5.2: every requirement row has populated owner fields" "0" "${_trace_empty_owner}"
_sum_missing=0
while IFS= read -r _l; do
    [[ -z "${_l}" || "${_l}" == \#* ]] && continue
    [[ -f "${DMOS_PROJECT_ROOT}/${_l#*  }" ]] || _sum_missing=$((_sum_missing + 1))
done < "${DMOS_PROJECT_ROOT}/SHA256SUMS"
assert_eq "§30.2/§43.4: every path listed in SHA256SUMS exists" "0" "${_sum_missing}"

section "PRD §22.1 step 1/5: empty and over-length paths rejected; final component . / .. rejected (fix pass 3c)"
SBOX_PV="$(new_sandbox)"
out="$(run_core "${SBOX_PV}" '
    validate_path "" >/dev/null 2>&1; printf "empty_rc=%s step=%s\n" "$?" "${DEVILS_MINIOS_PATH_FAIL_STEP}"
    long="/$(printf "a%.0s" $(seq 1 4100))"
    validate_path "${long}" >/dev/null 2>&1; printf "long_rc=%s step=%s\n" "$?" "${DEVILS_MINIOS_PATH_FAIL_STEP}"
    ok="/$(printf "a%.0s" $(seq 1 100))"
    validate_path "${ok}" >/dev/null 2>&1; printf "normal_rc=%s\n" "$?"
    mkdir -p "${HOME}/w"
    validate_path "${HOME}/w/." "${HOME}/w" >/dev/null 2>&1; printf "dot_rc=%s step=%s\n" "$?" "${DEVILS_MINIOS_PATH_FAIL_STEP}"
    validate_path "${HOME}/w/newfile" "${HOME}/w" >/dev/null 2>&1; printf "nonexistent_final_rc=%s\n" "$?"
')"
assert_contains "empty path rejected at the lexical step" "${out}" "empty_rc=1 step=lexical"
assert_contains "path longer than 4096 rejected at the lexical step" "${out}" "long_rc=1 step=lexical"
assert_contains "a normal-length path is accepted" "${out}" "normal_rc=0"
assert_contains "final component '.' rejected at the final-component step" "${out}" "dot_rc=1 step=final-component"
assert_contains "a nonexistent, well-formed final component is accepted" "${out}" "nonexistent_final_rc=0"

section "PRD §26 step 2 / §26.5: crash flag content, and flag vs crash-window independence (fix pass 3c)"
SBOX_CF="$(new_sandbox)"
out="$(run_core "${SBOX_CF}" '
    load_config >/dev/null 2>&1; load_state >/dev/null 2>&1
    _record_serious_crash "first" >"${HOME}/c1" 2>/dev/null; printf "count1=%s\n" "$(cat "${HOME}/c1")"
    printf "flag=%s\n" "$(cat "${DEVILS_MINIOS_CRASH_FLAG}")"
    ls "${DEVILS_MINIOS_CONFIG_DIR}" | grep -c "crash-flag.tmp" | sed "s/^/flag_tmp_leftovers=/"
    _clear_crash_flag
    [[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && printf "flag_after_clear=present\n" || printf "flag_after_clear=absent\n"
    printf "window_after_flag_clear=%s\n" "$(printf "%s" "${DEVILS_MINIOS_STATE[crash_loop_state]}" | tr "," "\n" | grep -c .)"
    _record_serious_crash "second" >"${HOME}/c2" 2>/dev/null; printf "count2=%s\n" "$(cat "${HOME}/c2")"
    DEVILS_MINIOS_STATE[crash_loop_state]=""; save_state >/dev/null 2>&1
    [[ -f "${DEVILS_MINIOS_CRASH_FLAG}" ]] && printf "flag_after_window_reset=present\n" || printf "flag_after_window_reset=absent\n"
')"
assert_contains "first serious crash counts 1 in the window" "${out}" "count1=1"
assert_contains "crash flag contains only created_at=<ISO-8601 UTC>" "${out}" "flag=created_at=20"
assert_contains "crash flag is written atomically (no temp file left)" "${out}" "flag_tmp_leftovers=0"
assert_contains "clearing the flag removes only the flag" "${out}" "flag_after_clear=absent"
assert_contains "clearing the flag preserves the crash window" "${out}" "window_after_flag_clear=1"
assert_contains "a later crash still sees the earlier window entry (count 2)" "${out}" "count2=2"
assert_contains "resetting the crash window does not clear the flag" "${out}" "flag_after_window_reset=present"
if printf '%s' "${out}" | grep -Eq '^flag=created_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then pass "crash flag timestamp is strict ISO-8601 UTC"; else fail "crash flag timestamp is strict ISO-8601 UTC"; fi

section "PRD §13.8 / §25 no background health daemon; §30.5 integrity-not-authenticity statement (fix pass 3c)"
bg_hits="$(cd "${DMOS_PROJECT_ROOT}" && grep -nE '\b(nohup|disown|setsid|daemonize)\b|(^|[^&])&[[:space:]]*(\)|;|$)' modules/health_check.sh core/core_state.sh core/core_platform.sh 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -vE '2>&1|>&2|&&' || true)"
assert_eq "health_check/state/platform never spawn a background process" "" "${bg_hits}"
sec_flat="$(tr '\n' ' ' < "${DMOS_PROJECT_ROOT}/docs/SECURITY.md")"
if [[ "${sec_flat}" =~ integrity\ only ]] && [[ "${sec_flat}" =~ not\*\*\ an\ independent\ authenticity ]]; then
    pass "docs/SECURITY.md states SHA-256 gives integrity only, not authenticity"
else
    fail "docs/SECURITY.md must state SHA-256 gives integrity only, not authenticity"
fi

section "§13 public function contracts: every public function has name/args/returns/side-effects documentation"
_contract_missing="$(awk '
FNR==1 { prev="" }
/^[A-Za-z][A-Za-z0-9_]*\(\) \{/ {
    name=$0; sub(/\(.*/, "", name)
    if (name !~ /^_/) {
        if (prev !~ /# Contract:/) print FILENAME ":" FNR ":" name
    }
}
{ prev=$0 }' "${DMOS_PROJECT_ROOT}"/modules/*.sh "${DMOS_PROJECT_ROOT}"/core/*.sh)"
assert_eq "§13: every public function has a contract comment" "" "${_contract_missing}"

print_summary "test_utils.sh"
exit $?
