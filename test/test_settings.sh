#!/usr/bin/env bash
# test_settings.sh - PRD §43.1: Settings, config validation (§17 grammar,
# runtime_context key rejection), export/import, reset actions (§33.1).
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

section "settings module loads"
out="$(run_module "${SBOX}" "settings" '
    type settings_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "settings_menu defined" "${out}" "menu=ok"

section "config grammar rejects unknown and runtime_context keys"
out="$(run_core "${SBOX}" '
    load_default_config
    save_config
    # Inject forbidden key
    printf "terminal_width=80\n" >> "${DEVILS_MINIOS_CONFIG_FILE}"
    if validate_config 2>/dev/null; then printf "tw=accepted\n"; else printf "tw=rejected\n"; fi
')"
assert_contains "terminal_width in config is rejected" "${out}" "tw=rejected"

section "duplicate keys rejected"
out="$(run_core "${SBOX}" '
    load_default_config
    save_config
    printf "theme=nord\n" >> "${DEVILS_MINIOS_CONFIG_FILE}"
    if validate_config 2>/dev/null; then printf "dup=accepted\n"; else printf "dup=rejected\n"; fi
')"
assert_contains "duplicate key rejected" "${out}" "dup=rejected"

section "configuration reset restores defaults"
out="$(run_core "${SBOX}" '
    load_default_config
    DEVILS_MINIOS_CONFIG[theme]=nord
    save_config
    load_default_config
    save_config
    load_config
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "reset restores dracula theme" "${out}" "theme=dracula"

section "state reset does not touch config"
out="$(run_core "${SBOX}" '
    load_default_config
    DEVILS_MINIOS_CONFIG[theme]=nord
    save_config
    default_state
    save_state
    load_config
    printf "theme_after_state_reset=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "state reset leaves theme intact" "${out}" "theme_after_state_reset=nord"

section "language locked to en (corrupt file injected to exercise validation)"
out="$(run_core "${SBOX}" '
    load_default_config
    save_config || exit 1
    sed "s/^language=en$/language=fr/" "${DEVILS_MINIOS_CONFIG_FILE}" > "${DEVILS_MINIOS_CONFIG_FILE}.injected"
    mv -f "${DEVILS_MINIOS_CONFIG_FILE}.injected" "${DEVILS_MINIOS_CONFIG_FILE}"
    if validate_config 2>/dev/null; then printf "lang=accepted\n"; else printf "lang=rejected\n"; fi
')"
assert_contains "non-en language rejected" "${out}" "lang=rejected"

section "data/defaults.conf is the authoritative defaults source"
out="$(run_core "${SBOX}" '
    defaults="${DEVILS_MINIOS_INSTALL_DIR}/data/defaults.conf"
    cp "${defaults}" "${defaults}.original"
    sed "s/^theme=dracula$/theme=nord/" "${defaults}" > "${defaults}.test"
    mv -f "${defaults}.test" "${defaults}"
    load_default_config || { mv -f "${defaults}.original" "${defaults}"; exit 1; }
    printf "loaded_theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    mv -f "${defaults}.original" "${defaults}"
')"
assert_contains "load_default_config reads the shipped defaults.conf theme" "${out}" "loaded_theme=nord"

section "atomic config write failure preserves the active file and import memory"
out="$(run_core "${SBOX}" '
    load_default_config || exit 1
    save_config || exit 1
    DEVILS_MINIOS_CONFIG[theme]=nord
    save_config || exit 1
    old_disk="$(cat "${DEVILS_MINIOS_CONFIG_FILE}")"
    cat > "${HOME}/valid-import.conf" <<"DMOS_CONFIG"
config_version=1
theme=gruvbox
banner=devil
banner_animation=false
auto_launch=false
health_check_interval=1800
log_level=INFO
check_updates=false
language=en
network_timeout=30
network_retries=3
DMOS_CONFIG
    mv() {
        if [[ "${4:-}" == "${DEVILS_MINIOS_CONFIG_FILE}" ]]; then return 1; fi
        command mv "$@"
    }
    if import_config "${HOME}/valid-import.conf" >/dev/null 2>&1; then import_rc=0; else import_rc=$?; fi
    unset -f mv
    disk_after="$(cat "${DEVILS_MINIOS_CONFIG_FILE}")"
    printf "import_rc=%s memory_theme=%s disk_unchanged=%s tmp_left=%s\n" \
        "${import_rc}" "${DEVILS_MINIOS_CONFIG[theme]}" \
        "$([[ "${disk_after}" == "${old_disk}" ]] && echo yes || echo no)" \
        "$(find "${DEVILS_MINIOS_CONFIG_DIR}" -maxdepth 1 -type f -name "*.tmp.*" | wc -l | tr -d " ")"
')"
assert_contains "valid import returns failure when atomic rename fails" "${out}" "import_rc=1"
assert_contains "failed valid import rolls back active in-memory settings" "${out}" "memory_theme=nord"
assert_contains "failed valid import keeps the active config file byte-for-byte unchanged" "${out}" "disk_unchanged=yes"
assert_contains "failed config write cleans up staged temporary files" "${out}" "tmp_left=0"

section "failed defaults validation leaves the current in-memory configuration untouched"
out="$(run_core "${SBOX}" '
    load_default_config || exit 1
    DEVILS_MINIOS_CONFIG[theme]=gruvbox
    defaults="${DEVILS_MINIOS_INSTALL_DIR}/data/defaults.conf"
    cp "${defaults}" "${defaults}.original"
    sed "s/^theme=.*/theme=not-a-theme/" "${defaults}" > "${defaults}.invalid"
    mv -f "${defaults}.invalid" "${defaults}"
    if load_default_config >/dev/null 2>&1; then defaults_rc=0; else defaults_rc=$?; fi
    printf "defaults_rc=%s theme_after_failure=%s\n" "${defaults_rc}" "${DEVILS_MINIOS_CONFIG[theme]}"
    mv -f "${defaults}.original" "${defaults}"
')"
assert_contains "invalid defaults file is rejected" "${out}" "defaults_rc=1"
assert_contains "invalid defaults file cannot partially reset active memory" "${out}" "theme_after_failure=gruvbox"

section "config save rejects a symlinked config directory"
SBOX_SYM="$(new_sandbox)"
out="$(run_core "${SBOX_SYM}" '
    outside="${HOME}/outside-config-target"
    mkdir -p "${HOME}/.config" "${outside}"
    rm -rf "${DEVILS_MINIOS_CONFIG_DIR}"
    ln -s "${outside}" "${DEVILS_MINIOS_CONFIG_DIR}"
    load_default_config || exit 1
    if save_config >/dev/null 2>&1; then save_rc=0; else save_rc=$?; fi
    printf "save_rc=%s outside_config=%s\n" "${save_rc}" "$([[ -e "${outside}/config" ]] && echo exists || echo absent)"
')"
assert_contains "symlinked config directory refuses config writes" "${out}" "save_rc=1"
assert_contains "symlinked config directory target remains untouched" "${out}" "outside_config=absent"

section "show_experimental_desktops is a permanently forbidden key (PRD-17-07)"
out="$(run_core "${SBOX}" '
    # It must never appear in the persisted-keys grammar itself...
    known=0
    for k in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
        [[ "${k}" == "show_experimental_desktops" ]] && known=1
    done
    printf "in_key_list=%s\n" "${known}"
    # ...and a config file that injects it as an extra key must be rejected
    # by the same unknown-key grammar path as any other forbidden key.
    load_default_config
    save_config
    printf "show_experimental_desktops=true\n" >> "${DEVILS_MINIOS_CONFIG_FILE}"
    if validate_config 2>/dev/null; then printf "sed=accepted\n"; else printf "sed=rejected\n"; fi
')"
assert_contains "show_experimental_desktops absent from persisted key grammar" "${out}" "in_key_list=0"
assert_contains "show_experimental_desktops key in config file is rejected" "${out}" "sed=rejected"

section "terminal_width is never written to the persisted config file (PRD-17-03)"
out="$(run_core "${SBOX}" '
    load_default_config
    build_runtime_context
    save_config
    if grep -q "^terminal_width=" "${DEVILS_MINIOS_CONFIG_FILE}" 2>/dev/null; then
        printf "tw_on_disk=yes\n"
    else
        printf "tw_on_disk=no\n"
    fi
')"
assert_contains "terminal_width absent from on-disk config" "${out}" "tw_on_disk=no"

section "§27 onboarding: full first-run flow via the real entry point"
SBOX_OB="$(new_sandbox)"
_ob_cli() { HOME="${SBOX_OB}/home" PREFIX="${SBOX_OB}/home/com.termux/files/usr" bash "${SBOX_OB}/usr/opt/devils-minios/devils-minios.sh" 2>&1; }
out="$(printf 'y\nn\n\nretro\nn\nn\n0\n' | _ob_cli)"; rc=$?
assert_status "onboarding completes and launcher exits 0" 0 "${rc}"
assert_contains "welcome shown (§27.2 step 1)" "${out}" "Welcome to Devil"
assert_contains "banner prompt offered with defaults (§27.2 step 5)" "${out}" "Banner (devil/minimal/retro/cyber/simple)"
assert_contains "auto-start opt-in offered (§27.2 step 7)" "${out}" "auto-start at boot"
assert_file_exists "completion marker created with timestamp" "${SBOX_OB}/home/.config/devils-minios/.onboarding-complete"
assert_file_not_exists "progress file removed after completion" "${SBOX_OB}/home/.config/devils-minios/.onboarding-progress"
assert_contains "banner choice persisted" "$(cat "${SBOX_OB}/home/.config/devils-minios/config")" "banner=retro"
assert_contains "state onboarding_completion set true" "$(cat "${SBOX_OB}/home/.config/devils-minios/state")" "onboarding_completion=true"

section "§27.2 step 2: acknowledgement is enforced, not optional"
SBOX_ACK="$(new_sandbox)"
out="$(printf 'n\ny\nn\n\n\nn\nn\n0\n' | HOME="${SBOX_ACK}/home" PREFIX="${SBOX_ACK}/home/com.termux/files/usr" bash "${SBOX_ACK}/usr/opt/devils-minios/devils-minios.sh" 2>&1)"; rc=$?
assert_status "onboarding with initially declined acknowledgement completes" 0 "${rc}"
assert_contains "declined acknowledgement re-prompts" "${out}" "Acknowledgement is required"
assert_file_exists "marker created after enforced acknowledgement" "${SBOX_ACK}/home/.config/devils-minios/.onboarding-complete"

section "§27.4: interrupted onboarding resumes from the first incomplete step"
SBOX_RES="$(new_sandbox)"
mkdir -p "${SBOX_RES}/home/.config/devils-minios"
printf '5\n' > "${SBOX_RES}/home/.config/devils-minios/.onboarding-progress"
out="$(printf '\n\nn\nn\n0\n' | HOME="${SBOX_RES}/home" PREFIX="${SBOX_RES}/home/com.termux/files/usr" bash "${SBOX_RES}/usr/opt/devils-minios/devils-minios.sh" 2>&1)"; rc=$?
assert_status "resumed onboarding completes" 0 "${rc}"
assert_not_contains "welcome skipped when resuming at step 5" "${out}" "Welcome to Devil"
assert_contains "resume lands on the theme/banner step" "${out}" "Banner ("
assert_file_exists "marker created after resumed run" "${SBOX_RES}/home/.config/devils-minios/.onboarding-complete"
assert_file_not_exists "progress file removed after resumed completion" "${SBOX_RES}/home/.config/devils-minios/.onboarding-progress"

section "§27.1: marker absence alone re-triggers onboarding"
SBOX_TRG="$(new_sandbox)"
mkdir -p "${SBOX_TRG}/home/.config/devils-minios"
printf 'state_version=1\nprimary_distro=\nlast_successful_workflow=\nonboarding_completion=true\ncrash_loop_state=\n' > "${SBOX_TRG}/home/.config/devils-minios/state"
out="$(printf 'y\nn\n\n\nn\nn\n0\n' | HOME="${SBOX_TRG}/home" PREFIX="${SBOX_TRG}/home/com.termux/files/usr" bash "${SBOX_TRG}/usr/opt/devils-minios/devils-minios.sh" 2>&1)"; rc=$?
assert_status "onboarding re-runs on marker absence, exit 0" 0 "${rc}"
assert_contains "onboarding runs although state flag was true" "${out}" "Welcome to Devil"
assert_file_exists "marker re-created" "${SBOX_TRG}/home/.config/devils-minios/.onboarding-complete"

section "§27.2 step 7 + §31: auto-start opt-in writes a plain-invocation boot file"
SBOX_AS="$(new_sandbox)"
mkdir -p "${SBOX_AS}/home/.termux/boot"
out="$(printf 'y\nn\n\n\nn\ny\n0\n' | HOME="${SBOX_AS}/home" PREFIX="${SBOX_AS}/home/com.termux/files/usr" bash "${SBOX_AS}/usr/opt/devils-minios/devils-minios.sh" 2>&1)"; rc=$?
assert_status "auto-start opt-in run completes" 0 "${rc}"
assert_file_exists "Termux:Boot file written" "${SBOX_AS}/home/.termux/boot/devils-minios-autostart.sh"
assert_contains "boot file is executable (mode 700)" "$(stat -c '%a' "${SBOX_AS}/home/.termux/boot/devils-minios-autostart.sh")" "700"
assert_contains "boot file invokes devils-minios" "$(cat "${SBOX_AS}/home/.termux/boot/devils-minios-autostart.sh")" "devils-minios"
assert_not_contains "boot file never invokes --safe-mode (§31)" "$(cat "${SBOX_AS}/home/.termux/boot/devils-minios-autostart.sh")" "--safe-mode"

section "§27.1: --safe-mode skips onboarding even when it would otherwise trigger"
SBOX_SM="$(new_sandbox)"
out="$(printf '0\n' | HOME="${SBOX_SM}/home" PREFIX="${SBOX_SM}/home/com.termux/files/usr" bash "${SBOX_SM}/usr/opt/devils-minios/devils-minios.sh" --safe-mode 2>&1)"; rc=$?
assert_status "--safe-mode launch exits 0" 0 "${rc}"
assert_contains "--safe-mode enters Safe Mode" "${out}" "SAFE MODE"
assert_not_contains "onboarding welcome not shown under --safe-mode" "${out}" "Welcome to Devil"
assert_file_not_exists "no completion marker written by --safe-mode" "${SBOX_SM}/home/.config/devils-minios/.onboarding-complete"

section "§27.3: settings exposes the manual onboarding re-run"
out="$(run_module "${SBOX}" "settings" '
    run_onboarding_force() { printf "onboarding-forced=yes\n"; }
    printf "8\n0\n" | settings_menu
')"
assert_contains "menu advertises the re-run entry" "${out}" "Re-run first-run onboarding"
assert_contains "menu item 8 invokes forced onboarding re-run" "${out}" "onboarding-forced=yes"

section "PRD-13.14-001: _settings_edit_key delegates validation to core.sh and never writes a value that core rejects"
out="$(run_module "${SBOX}" "settings" '
    load_default_config
    log_level_before="${DEVILS_MINIOS_CONFIG[log_level]}"
    _settings_edit_key >/dev/null 2>&1 <<< "log_level
DEBUG"
    printf "valid_edit_rc=%s\n" "$?"
    printf "log_level_after_valid=%s\n" "${DEVILS_MINIOS_CONFIG[log_level]}"
    _settings_edit_key >/dev/null 2>&1 <<< "log_level
NOT-A-REAL-LEVEL"
    printf "invalid_value_rc=%s\n" "$?"
    printf "log_level_after_invalid=%s\n" "${DEVILS_MINIOS_CONFIG[log_level]}"
    _settings_edit_key >/dev/null 2>&1 <<< "not_an_editable_key
whatever"
    printf "invalid_key_rc=%s\n" "$?"
')"
assert_contains "editing a key with a value core.sh validates succeeds" "${out}" "log_level_after_valid=DEBUG"
assert_contains "editing a key with a value core.sh rejects returns status 2" "${out}" "invalid_value_rc=2"
assert_contains "a value core.sh rejects is never written to config" "${out}" "log_level_after_invalid=DEBUG"
assert_contains "a non-editable/unknown key is rejected with status 2" "${out}" "invalid_key_rc=2"

section "PRD-13.14-001: _settings_export writes exactly the persisted_config keys, nothing else"
SBOXEXP="$(new_sandbox)"
out="$(run_module "${SBOXEXP}" "settings" '
    load_default_config
    dest="${HOME}/exported.conf"
    _settings_export >/dev/null 2>&1 <<< "${dest}"
    printf "export_rc=%s\n" "$?"
    printf "exists=%s\n" "$([[ -f "${dest}" ]] && echo yes || echo no)"
    for key in "${DEVILS_MINIOS_PERSISTED_CONFIG_KEYS[@]}"; do
        grep -q "^${key}=" "${dest}" || printf "missing_key=%s\n" "${key}"
    done
    for key in "${DEVILS_MINIOS_PERSISTED_RUNTIME_FACTS[@]}"; do
        grep -q "^${key}=" "${dest}" && printf "leaked_runtime_key=%s\n" "${key}"
    done
')"
assert_contains "export succeeds" "${out}" "export_rc=0"
assert_contains "export file is written" "${out}" "exists=yes"
assert_not_contains "export does not omit any persisted_config key" "${out}" "missing_key="
assert_not_contains "export never leaks runtime-fact keys (§17.7)" "${out}" "leaked_runtime_key="

section "PRD-13.14-001: _settings_import delegates to core.sh::import_config() (strict grammar, no local parsing)"
SBOXIMP="$(new_sandbox)"
out="$(run_module "${SBOXIMP}" "settings" '
    load_default_config
    good="${HOME}/good-import.conf"
    _settings_export >/dev/null 2>&1 <<< "${good}"
    DEVILS_MINIOS_CONFIG[theme]=nord
    _settings_import >/dev/null 2>&1 <<< "${good}"
    printf "good_import_rc=%s\n" "$?"
    printf "theme_after_good_import=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"

    bad="${HOME}/bad-import.conf"
    printf "theme=nord\nnot_a_real_key=evil\n" > "${bad}"
    _settings_import >/dev/null 2>&1 <<< "${bad}"
    printf "bad_import_rc=%s\n" "$?"
    printf "theme_after_bad_import=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"

    _settings_import >/dev/null 2>&1 <<< "${HOME}/does-not-exist.conf"
    printf "missing_import_rc=%s\n" "$?"
')"
assert_contains "importing a file re-exported via export/core validation succeeds" "${out}" "good_import_rc=0"
assert_contains "a valid import restores the exported theme value" "${out}" "theme_after_good_import=dracula"
assert_contains "import rejects a file with a key outside the strict grammar (status 2, delegated to core)" "${out}" "bad_import_rc=2"
assert_contains "rejected import leaves active in-memory config unchanged" "${out}" "theme_after_bad_import=dracula"
assert_contains "import of a nonexistent file is rejected (status 2)" "${out}" "missing_import_rc=2"

print_summary "test_settings.sh"
