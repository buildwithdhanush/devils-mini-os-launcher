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

# Source validation
readonly REQUIRED_FILES=(
    "devils-minios.sh"
    "modules/core.sh"
)

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
    _log "ERROR" "$1" >&2
}

_die() {
    _error "$1"
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
    
    # Check required files
    local missing=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${source_dir}/${file}" ]]; then
            missing+=("${file}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "Missing required files: ${missing[*]}" 1
    fi
    
    # Check modules directory
    if [[ ! -d "${source_dir}/modules" ]]; then
        _die "Missing modules directory" 1
    fi
    
    # Check data directory
    if [[ ! -d "${source_dir}/data" ]]; then
        _warn "Missing data directory (will be created during first run)"
    fi
    
    _info "Source validation passed"
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
        else
            _die "Installation directory exists but is not a Devil's Mini OS installation: ${INSTALL_TARGET_DIR}" 1
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
    cp -r "${source_dir}/modules" "${staging_dir}/" || _die "Failed to copy modules" 1
    
    # Copy optional directories if they exist
    if [[ -d "${source_dir}/data" ]]; then
        cp -r "${source_dir}/data" "${staging_dir}/" || _die "Failed to copy data" 1
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
    
    # Set permissions
    chmod 755 "${staging_dir}/devils-minios.sh" || _die "Failed to set permissions" 1
    find "${staging_dir}/modules" -name "*.sh" -exec chmod 755 {} \; || _die "Failed to set module permissions" 1
    
    # Validate staged installation
    _info "Validating staged installation..."
    if [[ ! -f "${staging_dir}/devils-minios.sh" ]]; then
        _die "Staged installation validation failed: devils-minios.sh missing" 1
    fi
    
    if [[ ! -d "${staging_dir}/modules" ]]; then
        _die "Staged installation validation failed: modules directory missing" 1
    fi
    
    # Atomic activation
    _info "Activating installation..."
    
    # Remove old installation if it exists
    if [[ -d "${INSTALL_TARGET_DIR}" ]]; then
        rm -rf "${INSTALL_TARGET_DIR}" || _die "Failed to remove old installation" 1
    fi
    
    # Move staging to final location
    mv "${staging_dir}" "${INSTALL_TARGET_DIR}" || _die "Failed to activate installation" 1
    
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
    _info "Devil's Mini OS Launcher Installer v${INSTALLER_VERSION}"
    _info "=============================================="
    
    # Check Bash version
    _check_bash_version
    
    # Detect platform
    _detect_platform || true
    _detect_termux_source
    
    # Determine source directory
    local source_dir
    source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    _info "Source directory: ${source_dir}"
    
    # Validate source
    _validate_source "${source_dir}"
    
    # Prepare installation directory
    _prepare_install_dir
    
    # Copy files
    _copy_files "${source_dir}"
    
    # Create symlink
    _create_symlink
    
    # Post-installation info
    _post_install_info
    
    _info "Installation complete!"
    exit 0
}

# Run main
_main "$@"