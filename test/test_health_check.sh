#!/usr/bin/env bash
# test_health_check.sh - PRD §43.1: Diagnostics, cache staleness
# (health_check_interval).
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

section "health_check module loads and cache path"
out="$(run_module "${SBOX}" "health_check" '
    cache="$(_health_check_cache_file)"
    printf "cache=%s\n" "${cache}"
    type health_check_menu >/dev/null 2>&1 && printf "menu=ok\n" || printf "menu=missing\n"
')"
assert_contains "cache file under cache dir" "${out}" "health_cache.json"
assert_contains "health_check_menu defined" "${out}" "menu=ok"

section "cache freshness respects health_check_interval"
out="$(run_module "${SBOX}" "health_check" '
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    cache="$(_health_check_cache_file)"
    printf "{}\n" > "${cache}"
    DEVILS_MINIOS_CONFIG[health_check_interval]=1800
    if _health_check_cache_fresh; then printf "fresh=yes\n"; else printf "fresh=no\n"; fi
    # Make cache appear old via touch
    touch -d "2 hours ago" "${cache}" 2>/dev/null || touch -t 202001010000 "${cache}" 2>/dev/null || true
    DEVILS_MINIOS_CONFIG[health_check_interval]=60
    if _health_check_cache_fresh; then printf "stale=yes\n"; else printf "stale=no\n"; fi
')"
assert_contains "fresh cache is served" "${out}" "fresh=yes"
assert_contains "stale cache triggers refresh" "${out}" "stale=no"

section "default health_check_interval is 1800"
out="$(run_core "${SBOX}" '
    load_default_config
    printf "interval=%s\n" "${DEVILS_MINIOS_CONFIG[health_check_interval]}"
')"
assert_contains "default interval is 1800" "${out}" "interval=1800"

section "§25.3 fresh run writes correct cache content with no temp leftovers"
out="$(run_module "${SBOX}" "health_check" '
    _health_check_run; rc=$?
    cache="$(_health_check_cache_file)"
    printf "rc=%s\n" "${rc}"
    grep -q "\"checked_at\"" "${cache}" && printf "content=ok\n" || printf "content=bad\n"
    grep -q "\"config_valid\": true" "${cache}" && printf "format=ok\n" || printf "format=bad\n"
    ls "${DEVILS_MINIOS_CACHE_DIR}"/health_cache.json.tmp.* >/dev/null 2>&1 && printf "tmp=leftover\n" || printf "tmp=none\n"
')"
assert_contains "fresh run succeeds" "${out}" "rc=0"
assert_contains "cache contains checked_at" "${out}" "content=ok"
assert_contains "cache keeps existing format" "${out}" "format=ok"
assert_contains "no temp file left behind" "${out}" "tmp=none"

section "§25.3 atomic replace preserves format and replaces content wholesale"
out="$(run_module "${SBOX}" "health_check" '
    cache="$(_health_check_cache_file)"
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    printf "{\n  \"checked_at\": \"2000-01-01T00:00:00Z\",\n  \"config_valid\": true\n}\n" > "${cache}"
    _health_check_run; rc=$?
    printf "rc=%s\n" "${rc}"
    grep -q "\"config_valid\": true" "${cache}" && printf "format=ok\n" || printf "format=bad\n"
    grep -q "2000-01-01" "${cache}" && printf "stale=present\n" || printf "stale=replaced\n"
')"
assert_contains "replace run succeeds" "${out}" "rc=0"
assert_contains "replaced cache keeps format" "${out}" "format=ok"
assert_contains "stale cache content fully replaced" "${out}" "stale=replaced"

section "§25.3 failed atomic replace leaves previous cache untouched"
out="$(run_module "${SBOX}" "health_check" '
    cache="$(_health_check_cache_file)"
    mkdir -p "${DEVILS_MINIOS_CACHE_DIR}"
    printf "{\n  \"checked_at\": \"2000-01-01T00:00:00Z\",\n  \"config_valid\": true\n}\n" > "${cache}"
    # Root can bypass directory write bits in CI/sandbox. Force the atomic
    # rename itself to fail so this test is privilege-independent.
    mv() { return 1; }
    _health_check_run; rc=$?
    unset -f mv
    printf "rc=%s\n" "${rc}"
    grep -q "2000-01-01" "${cache}" && printf "old=preserved\n" || printf "old=lost\n"
    ls "${DEVILS_MINIOS_CACHE_DIR}"/health_cache.json.tmp.* >/dev/null 2>&1 && printf "tmp=leftover\n" || printf "tmp=none\n"
')"
assert_contains "atomic rename failure makes run fail" "${out}" "rc=1"
assert_contains "previous cache preserved on failure" "${out}" "old=preserved"
assert_contains "no temp file left behind on failure" "${out}" "tmp=none"

section "§25.3 cached notice path still serves fresh cache"
out="$(run_module "${SBOX}" "health_check" '
    _health_check_run >/dev/null 2>&1
    _health_check_show false
')"
assert_contains "fresh cache served with cached notice" "${out}" "cached result"

section "PRD-25.3-001: on-demand health check is independent of --no-checks / --offline"
out="$(run_module "${SBOX}" "health_check" '
    DEVILS_MINIOS_NO_CHECKS=true
    DEVILS_MINIOS_OFFLINE_MODE=true
    rm -f "$(_health_check_cache_file)"
    _health_check_run; printf "rc=%s\n" "$?"
    [[ -f "$(_health_check_cache_file)" ]] && printf "cache=written\n" || printf "cache=missing\n"
')"
assert_contains "--no-checks does not prevent an explicit on-demand health check run" "${out}" "rc=0"
assert_contains "--offline does not prevent an explicit on-demand health check run" "${out}" "cache=written"

print_summary "test_health_check.sh"
