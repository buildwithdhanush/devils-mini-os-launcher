#!/usr/bin/env bash
# Devil's Mini OS Launcher - Installer
# Version: v1.0.0
# PRD Reference: §30, §30.1

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly INSTALLER_VERSION="1.0.0"
readonly REQUIRED_BASH_MAJOR=4
readonly REQUIRED_BASH_MINOR=3

# Installation paths
readonly INSTALL_TARGET_DIR="${PREFIX:-/data/data/com.termux/files/usr}/opt/devils-minios"
readonly INSTALL_BIN_DIR="${PREFIX:-/data/data/com.termux/files/usr}/bin"
readonly INSTALL_BIN_LINK="${INSTALL_BIN_DIR}/devils-minios"

# Source validation - devils-minios.sh plus exactly the 14 module files (§12,
# §30 step 3/7). No future_plans.sh (D1; absent by construction here).
readonly -a REQUIRED_MODULE_FILES=(
    "core" "linux_env" "file_mgr" "termux_apps" "proot_apps" "android_tools"
    "workspace" "health_check" "log_viewer" "customize" "system_tools"
    "system_info" "update_all" "settings"
)
# Non-module internal components that modules/core.sh and devils-minios.sh
# source from core/ (kept out of modules/ so `modules/` holds exactly the
# 14 files above; see core/*.sh headers).
readonly -a REQUIRED_CORE_FILES=(
    "core_logging" "core_platform" "core_security" "core_executor" "core_config"
    "core_state" "core_recovery" "core_backup" "core_catalog" "core_ui" "devils_self_update"
)
readonly REQUIRED_FILES=(
    "devils-minios.sh"
)

# Storage required for a fresh install: modules + data + docs are small;
# this fixed default matches the §25.1 Termux-app-install floor as a
# conservative estimate for the install itself.
readonly INSTALL_REQUIRED_BYTES=104857600
readonly INSTALL_SAFETY_MARGIN_BYTES=104857600

# ============================================================================
# UTILITIES
# ============================================================================

_log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}"
}

_info() {
    _log "INFO" "$1"
}

_warn() {
    _log "WARN" "$1" >&2
}

_error() {
    # §48.2: optional leading Exxx code (E601/E602/E603 etc.). Backward
    # compatible - a plain message-only call still works exactly as before.
    if [[ "$1" =~ ^E[0-9]{3}$ ]]; then
        _log "ERROR" "[$1] $2" >&2
    else
        _log "ERROR" "$1" >&2
    fi
}

_die() {
    local code=""
    if [[ "$1" =~ ^E[0-9]{3}$ ]]; then
        code="$1"
        shift
    fi
    if [[ -n "${code}" ]]; then
        _error "${code}" "$1"
    else
        _error "$1"
    fi
    exit "${2:-1}"
}

# ============================================================================
# BASH VERSION CHECK
# ============================================================================

_check_bash_version() {
    local current_major="${BASH_VERSINFO[0]}"
    local current_minor="${BASH_VERSINFO[1]}"
    
    if [[ "${current_major}" -lt "${REQUIRED_BASH_MAJOR}" ]] || \
       [[ "${current_major}" -eq "${REQUIRED_BASH_MAJOR}" && "${current_minor}" -lt "${REQUIRED_BASH_MINOR}" ]]; then
        _die "Bash ${REQUIRED_BASH_MAJOR}.${REQUIRED_BASH_MINOR} or higher required. Current: ${BASH_VERSION}" 1
    fi
    
    _info "Bash version check passed: ${BASH_VERSION}"
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

_detect_platform() {
    # Check for Termux
    if [[ -n "${PREFIX:-}" ]] && [[ "${PREFIX}" == */com.termux/* ]]; then
        _info "Termux environment detected"
        return 0
    fi
    
    # Check for Android
    if [[ -d "/data/data/com.termux" ]] || [[ -d "/data/data/com.termux.playstore" ]]; then
        _info "Android/Termux environment detected"
        return 0
    fi
    
    _warn "Not running in Termux environment. Installation may not work correctly."
    return 1
}

_detect_termux_source() {
    local source="unknown"
    
    if [[ -n "${TERMUX_APK_RELEASE:-}" ]]; then
        case "${TERMUX_APK_RELEASE}" in
            github) source="github" ;;
            f-droid) source="f-droid" ;;
            playstore|play-store) source="play-store" ;;
        esac
    elif [[ "${PREFIX:-}" == *"/com.termux.playstore/"* ]]; then
        source="play-store"
    elif [[ "${PREFIX:-}" == *"/com.termux/"* ]]; then
        source="f-droid"
    fi
    
    _info "Termux source: ${source}"
    
    if [[ "${source}" == "play-store" ]]; then
        _warn "Play Store Termux detected. This version is outdated and unsupported."
        _warn "Please install Termux from F-Droid or GitHub for full compatibility."
    fi
    
    return 0
}

# ============================================================================
# SOURCE VALIDATION
# ============================================================================

_validate_source() {
    local source_dir="${1:-.}"
    
    _info "Validating installation source..."
    
    # Check required top-level files
    local missing=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${source_dir}/${file}" ]]; then
            missing+=("${file}")
        fi
    done

    # Check modules directory
    if [[ ! -d "${source_dir}/modules" ]]; then
        _die "Missing modules directory" 1
    fi

    # Check for exactly the 14 required module files (§12); a source tree
    # missing any of them, or shipping a removed one, is rejected rather
    # than silently installed (§46 Definition of Done: no future_plans.sh).
    local mod
    for mod in "${REQUIRED_MODULE_FILES[@]}"; do
        if [[ ! -f "${source_dir}/modules/${mod}.sh" ]]; then
            missing+=("modules/${mod}.sh")
        fi
    done
    if [[ -f "${source_dir}/modules/future_plans.sh" ]]; then
        _die "Source contains modules/future_plans.sh, which must not exist (D1, §46)" 1
    fi

    # core.sh's own body is split across core/core_*.sh (plus the self-update
    # component, core/devils_self_update.sh), loaded internally by
    # modules/core.sh; these are not feature modules and never appear under
    # modules/, but core.sh cannot run without them, so they are required
    # top-level source files just like devils-minios.sh itself.
    if [[ ! -d "${source_dir}/core" ]]; then
        _die "Missing core directory" 1
    fi
    for mod in "${REQUIRED_CORE_FILES[@]}"; do
        if [[ ! -f "${source_dir}/core/${mod}.sh" ]]; then
            missing+=("core/${mod}.sh")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "Missing required files: ${missing[*]}" 1
    fi

    # Check data directory
    if [[ ! -d "${source_dir}/data" ]]; then
        _warn "Missing data directory (will be created during first run)"
    fi

    # Verify SHA256SUMS when present (§30 step 5, §30.5: integrity only).
    if [[ -f "${source_dir}/SHA256SUMS" ]]; then
        _info "SHA256SUMS present; verifying manifest..."
        if ! ( cd "${source_dir}" && sha256sum -c SHA256SUMS --status 2>/dev/null ); then
            _die "E602" "SHA256SUMS verification failed; refusing to install a tampered or corrupt source" 2
        fi
        _info "Manifest checksum verification passed"
    else
        _warn "No SHA256SUMS in source; proceeding without manifest verification (not required for a plain git-clone source)"
    fi

    _info "Source validation passed"
    return 0
}

# install.sh --verify (§15, §30.2): sha256sum -c SHA256SUMS against the
# currently ACTIVE installation, reporting per-file PASS/FAIL; exits 0 only
# if all pass. This checks integrity, not authenticity (§30.5).
_run_verify() {
    local manifest="${INSTALL_TARGET_DIR}/SHA256SUMS"
    if [[ ! -f "${manifest}" ]]; then
        _die "E602" "No SHA256SUMS found in active installation (${INSTALL_TARGET_DIR}); cannot verify" 2
    fi
    _info "Verifying installed files against SHA256SUMS (integrity check only, §30.5)..."
    if ( cd "${INSTALL_TARGET_DIR}" && sha256sum -c SHA256SUMS ); then
        _info "All files verified"
        exit 0
    else
        # §48.2 E602: verification-failure exit status is 2, not 1.
        _error "E602" "One or more files failed verification"
        exit 2
    fi
}

# §25.1 storage gate, applied to the install operation itself (§30 step 4).
_check_install_storage() {
    local target_dir="${INSTALL_TARGET_DIR}"
    local check_dir="${target_dir}"
    [[ -d "${check_dir}" ]] || check_dir="$(dirname "${check_dir}")"
    [[ -d "${check_dir}" ]] || check_dir="${HOME}"
    local available
    available="$(df -B1 "${check_dir}" 2>/dev/null | awk 'NR==2 {print $4}')" || available="" # failing df must not trip set -e
    if [[ ! "${available}" =~ ^[0-9]+$ ]]; then
        _warn "Could not determine available storage; proceeding with caution"
        return 0
    fi
    local required=$((INSTALL_REQUIRED_BYTES + INSTALL_SAFETY_MARGIN_BYTES))
    if [[ ${available} -lt ${required} ]]; then
        # §48.2 E603: exit status 3, matching core.sh's check_storage_threshold().
        _die "E603" "Insufficient storage: required ${required} bytes, available ${available} bytes" 3
    fi
    _info "Storage check passed (${available} bytes available)"
    return 0
}

# ============================================================================
# INSTALLATION
# ============================================================================

_prepare_install_dir() {
    _info "Preparing installation directory: ${INSTALL_TARGET_DIR}"
    
    # Check if directory exists
    if [[ -d "${INSTALL_TARGET_DIR}" ]]; then
        # Check if it's a previous installation
        if [[ -f "${INSTALL_TARGET_DIR}/devils-minios.sh" ]]; then
            _info "Previous installation detected, will be replaced"
        elif [[ -z "$(ls -A "${INSTALL_TARGET_DIR}" 2>/dev/null)" ]]; then
            # §48.2 E601's registered trigger is an existing *non-empty*
            # unrecognized installation directory; an existing but empty
            # directory is not that condition and must not be misclassified
            # as E601 - proceed with installation into it.
            _info "Empty installation directory found; proceeding"
        else
            # §48.2 E601: existing, non-empty, unrecognized installation
            # directory.
            _die "E601" "Installation directory exists but is not a Devil's Mini OS installation: ${INSTALL_TARGET_DIR}" 1
        fi
    fi
    
    # Create parent directory if needed
    local parent_dir
    parent_dir="$(dirname "${INSTALL_TARGET_DIR}")"
    
    if [[ ! -d "${parent_dir}" ]]; then
        mkdir -p "${parent_dir}" || _die "Failed to create parent directory: ${parent_dir}" 1
    fi
    
    return 0
}

_copy_files() {
    local source_dir="${1:-.}"
    
    _info "Copying files to installation directory..."
    # Create temporary staging directory
    local staging_dir
    staging_dir="$(mktemp -d "${INSTALL_TARGET_DIR}.staging.XXXXXX" 2>/dev/null || mktemp -d)"
    
    # Track staging directory for cleanup
    trap 'rm -rf "${staging_dir}"' EXIT
    # Copy files
    cp -r "${source_dir}/devils-minios.sh" "${staging_dir}/" || _die "Failed to copy devils-minios.sh" 1
    cp "${source_dir}/install.sh" "${staging_dir}/" || _die "Failed to copy install.sh" 1
    cp -r "${source_dir}/modules" "${staging_dir}/" || _die "Failed to copy modules" 1
    cp -r "${source_dir}/core" "${staging_dir}/" || _die "Failed to copy core" 1
    
    # Copy optional directories if they exist
    if [[ -d "${source_dir}/data" ]]; then
        cp -r "${source_dir}/data" "${staging_dir}/" || _die "Failed to copy data" 1
        # Test-generated reports are repository evidence, not runtime data.
        [[ ! -d "${staging_dir}/data/reports" ]] || rm -rf -- "${staging_dir}/data/reports"
    fi
    if [[ -d "${source_dir}/docs" ]]; then
        cp -r "${source_dir}/docs" "${staging_dir}/" || _die "Failed to copy docs" 1
    fi
    # Copy documentation files
    for doc in README.md LICENSE CHANGELOG.md SECURITY.md; do
        if [[ -f "${source_dir}/${doc}" ]]; then
            cp "${source_dir}/${doc}" "${staging_dir}/" || _die "Failed to copy ${doc}" 1
        fi
    done
    if [[ -f "${source_dir}/SHA256SUMS" ]]; then
        local active_manifest="${staging_dir}/SHA256SUMS" hash rel
        : > "${active_manifest}" || _die "Failed to create active SHA256SUMS" 1
        while read -r hash rel; do
            rel="${rel#./}"
            [[ -f "${staging_dir}/${rel}" ]] && printf '%s  ./%s\n' "${hash}" "${rel}" >> "${active_manifest}" || true
        done < "${source_dir}/SHA256SUMS"
        local required_rel required_path
        while IFS= read -r -d '' required_path; do
            required_rel="${required_path#"${staging_dir}"/}"; [[ "${required_rel}" == "SHA256SUMS" ]] && continue
            grep -Fq "  ./${required_rel}" "${active_manifest}" || _die "Active SHA256SUMS missing required file: ${required_rel}" 1
        done < <(find "${staging_dir}" -type f -print0)
        ( cd "${staging_dir}" && sha256sum -c SHA256SUMS --status 2>/dev/null ) || _die "E602" "Staged active-manifest verification failed" 2
    fi
    chmod 755 "${staging_dir}/devils-minios.sh" "${staging_dir}/install.sh" || _die "Failed to set executable permissions" 1
    find "${staging_dir}/modules" -name "*.sh" -exec chmod 755 {} \; || _die "Failed to set module permissions" 1
    find "${staging_dir}/core" -name "*.sh" -exec chmod 755 {} \; || _die "Failed to set core permissions" 1
    # Validate staged installation
    _info "Validating staged installation..."
    if [[ ! -f "${staging_dir}/devils-minios.sh" ]]; then
        _die "Staged installation validation failed: devils-minios.sh missing" 1
    fi
    if [[ ! -d "${staging_dir}/modules" ]]; then
        _die "Staged installation validation failed: modules directory missing" 1
    fi
    if [[ ! -d "${staging_dir}/core" ]]; then
        _die "Staged installation validation failed: core directory missing" 1
    fi
    
    # Atomic activation (§30.1). The installer may only rm -rf a path it
    # itself created, in this run, via a call whose exact resulting path was
    # captured into a variable at creation time - never a pre-existing path
    # such as the previous active installation. So the old installation is
    # never `rm -rf`'d directly: it is first renamed out of the way (which
    # *is* an installer-owned creation of that backup path, captured here in
    # old_install_backup), the new installation is swapped into place, and
    # only then is the backup - now installer-owned - deleted via that same
    # captured variable. This also keeps activation atomic: there is never a
    # window with neither a valid old nor a valid new installation on disk.
    _info "Activating installation..."

    local old_install_backup=""
    if [[ -d "${INSTALL_TARGET_DIR}" ]]; then
        old_install_backup="${INSTALL_TARGET_DIR}.old.$$"
        mv "${INSTALL_TARGET_DIR}" "${old_install_backup}" || _die "Failed to move aside old installation" 1
    fi

    # Move staging to final location
    if ! mv "${staging_dir}" "${INSTALL_TARGET_DIR}"; then
        # Roll back: restore the old installation so a failed activation
        # never leaves the system with no working installation at all.
        [[ -n "${old_install_backup}" ]] && mv "${old_install_backup}" "${INSTALL_TARGET_DIR}" 2>/dev/null || true
        _die "Failed to activate installation" 1
    fi

    # Now deletable: old_install_backup was created by this installer in
    # this run (via the mv above) and is only ever referenced through this
    # captured variable, never via glob, pattern, or re-derived path.
    if [[ -n "${old_install_backup}" ]]; then
        rm -rf "${old_install_backup}" || _warn "Failed to remove old installation backup: ${old_install_backup} (activation remains valid)"
    fi

    # Clear trap since we successfully moved
    trap - EXIT
    
    _info "Installation activated successfully"
    return 0
}

_create_symlink() {
    _info "Creating executable symlink..."
    
    # Ensure bin directory exists
    if [[ ! -d "${INSTALL_BIN_DIR}" ]]; then
        mkdir -p "${INSTALL_BIN_DIR}" || _die "Failed to create bin directory" 1
    fi
    
    # Remove existing symlink if present
    if [[ -L "${INSTALL_BIN_LINK}" ]] || [[ -e "${INSTALL_BIN_LINK}" ]]; then
        rm -f "${INSTALL_BIN_LINK}" || _die "Failed to remove existing symlink" 1
    fi
    
    # Create symlink
    ln -s "${INSTALL_TARGET_DIR}/devils-minios.sh" "${INSTALL_BIN_LINK}" || _die "Failed to create symlink" 1
    
    # Make sure the target is executable
    chmod 755 "${INSTALL_TARGET_DIR}/devils-minios.sh" || _die "Failed to set executable permission" 1
    
    _info "Symlink created: ${INSTALL_BIN_LINK}"
    return 0
}

# ============================================================================
# POST-INSTALLATION
# ============================================================================

_post_install_info() {
    cat <<EOF

╔════════════════════════════════════════════════════════════════╗
║  Devil's Mini OS Launcher v${INSTALLER_VERSION} Installed Successfully!      ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Installation directory: ${INSTALL_TARGET_DIR}
║  Executable: ${INSTALL_BIN_LINK}
║                                                                ║
║  To launch:                                                    ║
║    devils-minios                                               ║
║                                                                ║
║  For help:                                                     ║
║    devils-minios --help                                        ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF
}

# ============================================================================
# MAIN
# ============================================================================

_main() {
    # --verify (§15, §30.2) is an installer flag, not a launcher flag, and is
    # handled before anything else in this script.
    if [[ "${1:-}" == "--verify" ]]; then
        _run_verify
    fi

    _info "Devil's Mini OS Launcher Installer v${INSTALLER_VERSION}"
    _info "=============================================="
    
    _check_bash_version
    
    _detect_platform || true
    _detect_termux_source
    
    local source_dir
    source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    _info "Source directory: ${source_dir}"

    # Self-source-overwrite guard (§30.1 explicit prohibition #3): detect a
    # reinstall-in-place by comparing resolved absolute paths. Copying always
    # stages into a sibling temp directory before the active installation is
    # touched (see _copy_files), so this is a defense-in-depth check with a
    # clear message rather than a silent behavior change.
    if [[ -d "${INSTALL_TARGET_DIR}" && "${source_dir}" == "${INSTALL_TARGET_DIR}" ]]; then
        _info "Reinstalling in place over the active installation; staging the new copy before activation"
    fi

    _validate_source "${source_dir}"

    # Storage gate (§25.1, §30 step 4) before any copying begins.
    _check_install_storage

    _prepare_install_dir
    
    _copy_files "${source_dir}"
    
    _create_symlink
    
    _post_install_info
    
    _info "Installation complete!"
    exit 0
}

# Run main
_main "$@"
