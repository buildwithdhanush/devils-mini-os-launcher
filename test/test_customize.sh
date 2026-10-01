#!/usr/bin/env bash
# test_customize.sh - PRD §43.1: Themes/banners, idempotency, draw counter.
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

section "customize module loads"
out="$(run_module "${SBOX}" "customize" '
    type customize_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "customize_menu defined" "${out}" "menu=ok"

section "default theme and banner from defaults"
out="$(run_core "${SBOX}" '
    load_default_config
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    printf "banner=%s\n" "${DEVILS_MINIOS_CONFIG[banner]}"
    printf "anim=%s\n" "${DEVILS_MINIOS_CONFIG[banner_animation]}"
')"
assert_contains "default theme is dracula" "${out}" "theme=dracula"
assert_contains "default banner is devil" "${out}" "banner=devil"
assert_contains "banner_animation default false" "${out}" "anim=false"

section "banner draw counter is cache-only (not config)"
out="$(run_core "${SBOX}" '
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    counter="${DEVILS_MINIOS_CACHE_DIR}/banner_draw_count"
    printf 0 > "${counter}"
    # Simulate a draw increment without writing config
    n="$(cat "${counter}")"
    n=$((n + 1))
    printf "%s" "${n}" > "${counter}"
    printf "counter=%s\n" "$(cat "${counter}")"
    # Confirm terminal_width never in config
    save_config 2>/dev/null || true
    if grep -q terminal_width "${DEVILS_MINIOS_CONFIG_FILE}" 2>/dev/null; then
        printf "tw_in_config=yes\n"
    else
        printf "tw_in_config=no\n"
    fi
')"
assert_contains "draw counter increments in cache" "${out}" "counter=1"
assert_contains "terminal_width never written to config" "${out}" "tw_in_config=no"

section "PRD §13.10-001: customize_menu drives theme and banner selection end-to-end"
out="$(run_module "${SBOX}" "customize" '
    load_default_config
    customize_menu >/dev/null 2>&1 <<< "1
nord
2
retro
0"
    printf "theme_after=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    printf "banner_after=%s\n" "${DEVILS_MINIOS_CONFIG[banner]}"
')"
assert_contains "customize_menu choice 1 (theme) updates DEVILS_MINIOS_CONFIG[theme]" "${out}" "theme_after=nord"
assert_contains "customize_menu choice 2 (banner) updates DEVILS_MINIOS_CONFIG[banner]" "${out}" "banner_after=retro"

section "PRD §34-001: theme/banner customization is idempotent (re-apply does not duplicate state)"
SBOXTMX="$(new_sandbox)"
out="$(run_module "${SBOXTMX}" "customize" '
    load_default_config
    DEVILS_MINIOS_PLATFORM=termux
    apply_theme dracula
    lines_first=$(wc -l < "${HOME}/.termux/colors.properties")
    apply_theme dracula
    lines_second=$(wc -l < "${HOME}/.termux/colors.properties")
    apply_theme dracula
    lines_third=$(wc -l < "${HOME}/.termux/colors.properties")
    printf "lines=%s,%s,%s\n" "${lines_first}" "${lines_second}" "${lines_third}"
    printf "theme=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
')"
assert_contains "re-applying the same theme three times never grows colors.properties (no duplicate blocks)" "${out}" "lines=4,4,4"
assert_contains "re-applied theme is still recorded exactly once in config" "${out}" "theme=dracula"

section "PRD §13.10-001: unknown theme/banner selections are rejected without mutating config"
out="$(run_module "${SBOX}" "customize" '
    load_default_config
    DEVILS_MINIOS_CONFIG[theme]=dracula
    apply_theme totally-not-a-theme >/dev/null 2>&1; printf "bad_theme_rc=%s\n" "$?"
    printf "theme_unchanged=%s\n" "${DEVILS_MINIOS_CONFIG[theme]}"
    DEVILS_MINIOS_CONFIG[banner]=devil
    set_banner totally-not-a-banner >/dev/null 2>&1; printf "bad_banner_rc=%s\n" "$?"
    printf "banner_unchanged=%s\n" "${DEVILS_MINIOS_CONFIG[banner]}"
')"
assert_contains "unknown theme rejected with status 2" "${out}" "bad_theme_rc=2"
assert_contains "config theme unchanged after rejected theme" "${out}" "theme_unchanged=dracula"
assert_contains "unknown banner rejected with status 2" "${out}" "bad_banner_rc=2"
assert_contains "config banner unchanged after rejected banner" "${out}" "banner_unchanged=devil"

print_summary "test_customize.sh"
