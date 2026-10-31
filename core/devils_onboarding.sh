#!/usr/bin/env bash
# Devil's Mini OS Launcher - core/devils_onboarding.sh
# PRD Reference: §27 (onboarding & first-run), §31 (auto-start), §35.2/§35.3
# Split out of devils-minios.sh to satisfy the PRD 500-line-per-file limit
# (same pattern as core/devils_self_update.sh). Sourced by devils-minios.sh
# after core.sh and the self-update component; relies on core.sh primitives
# (_confirm, _prompt_default, save_config, save_state, warn_play_store,
# warn_proot_limits, apply_theme, set_banner, record_state_transition).

# DEVILS_MINIOS_CONFIG is declared -gA in modules/core.sh. Repeating the bare
# declaration (no assignment; contents are untouched) tells ShellCheck, which
# analyzes this file standalone, that the [key] subscripts below are
# associative keys and not variables.
declare -gA DEVILS_MINIOS_CONFIG

# ONBOARDING (§27) - minimal, idempotent first-run flow
# ============================================================================

# §27.2 auto-start opt-in helper. The boot file must invoke a plain
# `devils-minios` (never --safe-mode, §31). If Termux:Boot is not installed,
# explain and take no action.
_onboarding_enable_auto_start() {
    if [[ ! -d "${HOME}/.termux/boot" ]]; then
        _warn "" "Termux:Boot does not appear to be installed (no ~/.termux/boot); auto-start was not enabled. You can enable it later from Settings."
        return 0
    fi
    local boot_file="${HOME}/.termux/boot/devils-minios-autostart.sh"
    local tmp_file="${boot_file}.tmp.$$"
    {
        printf '#!/data/data/com.termux/files/usr/bin/sh\n'
        printf 'devils-minios\n'
    } > "${tmp_file}" || { rm -f "${tmp_file}"; return 1; }
    chmod 700 "${tmp_file}"
    mv -f "${tmp_file}" "${boot_file}"
    _info "Auto-start enabled (${boot_file})"
}

# Records the first incomplete step (§27.4 resume support). The completion
# marker and state flag are written only after the final step succeeds; the
# progress file is removed at that point.
_onboarding_set_step() {
    local progress_file="${DEVILS_MINIOS_CONFIG_DIR}/.onboarding-progress"
    local tmp_file="${progress_file}.tmp.$$"
    printf '%s\n' "$1" > "${tmp_file}" && mv -f "${tmp_file}" "${progress_file}"
}

_run_onboarding() {
    local force="${1:-false}"
    [[ "${DEVILS_MINIOS_SAFE_MODE}" == true ]] && return 0
    if [[ "${force}" != true ]]; then
        [[ -f "${DEVILS_MINIOS_ONBOARDING_MARKER}" && "${DEVILS_MINIOS_STATE[onboarding_completion]:-false}" == true ]] && return 0
    fi

    local progress_file="${DEVILS_MINIOS_CONFIG_DIR}/.onboarding-progress"
    local step=1
    if [[ -f "${progress_file}" ]]; then
        step="$(cat "${progress_file}" 2>/dev/null || printf '1')"
        [[ "${step}" =~ ^[1-8]$ ]] || step=1
    fi

    # Step 1 (§27.2.1): Welcome + product one-liner.
    if [[ ${step} -le 1 ]]; then
        _onboarding_set_step 1
        clear_screen
        printf "Welcome to Devil's Mini OS Launcher v%s\n" "${DEVILS_MINIOS_VERSION}"
        printf 'Turns Termux into a managed Linux workstation.\n\n'
    fi

    # Step 2 (§27.2.2): Termux source check -> Play Store warning if
    # applicable. The warning is non-blocking but must be acknowledged.
    if [[ ${step} -le 2 ]]; then
        _onboarding_set_step 2
        warn_play_store
        until _confirm "Acknowledge and continue setup"; do
            printf 'Acknowledgement is required to continue setup.\n'
        done
    fi

    # Step 3 (§27.2.3): Proot limitations summary.
    if [[ ${step} -le 3 ]]; then
        _onboarding_set_step 3
        warn_proot_limits
    fi

    # Step 4 (§27.2.4): Optional update checks (default off).
    if [[ ${step} -le 4 ]]; then
        _onboarding_set_step 4
        local old_check_updates="${DEVILS_MINIOS_CONFIG[check_updates]:-false}"
        if _confirm "Enable update checks"; then
            DEVILS_MINIOS_CONFIG[check_updates]=true
        else
            DEVILS_MINIOS_CONFIG[check_updates]=false
        fi
        if ! save_config; then
            DEVILS_MINIOS_CONFIG[check_updates]="${old_check_updates}"
            _error "E900" "Onboarding could not save update-check preference" 0
            return 1
        fi
    fi

    # Step 5 (§27.2.5): Optional theme and banner (defaults offered).
    if [[ ${step} -le 5 ]]; then
        _onboarding_set_step 5
        local theme banner
        theme="$(_prompt_default 'Theme (dracula/nord/solarized/gruvbox)' 'dracula')"
        apply_theme "${theme}" || return 1
        banner="$(_prompt_default 'Banner (devil/minimal/retro/cyber/simple)' 'devil')"
        set_banner "${banner}" || return 1
    fi

    # Step 6 (§27.2.6): Optional auto_launch (default off; explicit opt-in).
    if [[ ${step} -le 6 ]]; then
        _onboarding_set_step 6
        # shellcheck disable=SC2034  # DEVILS_MINIOS_CONFIG is read by save_config (core_config.sh)
        local old_auto_launch="${DEVILS_MINIOS_CONFIG[auto_launch]:-false}"
        if _confirm "Enable auto_launch (resume last workflow on bare invocation)"; then
            DEVILS_MINIOS_CONFIG[auto_launch]=true
        else
            DEVILS_MINIOS_CONFIG[auto_launch]=false
        fi
        if ! save_config; then
            DEVILS_MINIOS_CONFIG[auto_launch]="${old_auto_launch}"
            _error "E900" "Onboarding could not save auto-launch preference" 0
            return 1
        fi
    fi

    # Step 7 (§27.2.7): Optional auto-start (default off; explicit opt-in).
    if [[ ${step} -le 7 ]]; then
        _onboarding_set_step 7
        if _confirm "Enable auto-start at boot (requires the Termux:Boot app)"; then
            _onboarding_enable_auto_start || true
        fi
    fi

    # Step 8 (§27.2.8): Completion summary -> marker + state flag, then the
    # progress file is removed. Written only after the final step succeeds.
    printf 'Onboarding complete. Configuration saved.\n'
    local tmp_marker="${DEVILS_MINIOS_ONBOARDING_MARKER}.tmp.$$"
    printf 'completed_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "${tmp_marker}"
    mv -f "${tmp_marker}" "${DEVILS_MINIOS_ONBOARDING_MARKER}"
    DEVILS_MINIOS_STATE[onboarding_completion]=true
    save_state
    rm -f "${progress_file}"
    record_state_transition "IDLE" 2>/dev/null || _enter_idle_state
}

# Public wrapper so settings.sh can re-run onboarding manually (§27.3:
# re-running re-creates the marker idempotently).
# Contract: run_onboarding_force(none); returns: 0 on success, non-zero on validation/failure/abort; side effects: performs the named workflow and may mutate approved runtime state.
run_onboarding_force() {
    _run_onboarding true
}
