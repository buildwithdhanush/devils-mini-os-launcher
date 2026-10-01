#!/usr/bin/env bash
# test_linux_env.sh - PRD §43.1: Official proot-distro catalog matching,
# fixed 8-desktop handling, generate_xstartup (incl. distro-arg rootfs
# selection, allowlisted startup_binary), systemd warning.
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

section "Distro catalog loads and matches by id or proot_id"
out="$(run_module "${SBOX}" linux_env '
    get_distro_record "ubuntu" >/dev/null 2>&1 && printf "by_id=found\n" || printf "by_id=missing\n"
    printf "field2=%s\n" "${DEVILS_MINIOS_RECORD_FIELDS[2]}"
    get_distro_record "debian" >/dev/null 2>&1 && printf "proot_id_match=found\n" || printf "proot_id_match=missing\n"
    get_distro_record "no-such-distro" >/dev/null 2>&1 && printf "unknown=found\n" || printf "unknown=missing\n"
')"
assert_contains "get_distro_record finds ubuntu by catalog id" "${out}" "by_id=found"
assert_contains "ubuntu record's proot_id field is 'ubuntu'" "${out}" "field2=ubuntu"
assert_contains "get_distro_record matches by proot_id fallback" "${out}" "proot_id_match=found"
assert_contains "get_distro_record reports missing for unknown distro" "${out}" "unknown=missing"

section "Fixed 8 Tier-1 desktops (§42, §46)"
out="$(run_module "${SBOX}" linux_env '
    load_database "$(data_file_path desktops.db)" 7 _validate_desktop_record true
    printf "count=%s\n" "${#DEVILS_MINIOS_CATALOG[@]}"
    for expected in xfce4 lxqt lxde mate i3wm openbox fluxbox jwm; do
        found=no
        for line in "${DEVILS_MINIOS_CATALOG[@]}"; do
            [[ "${line}" == "${expected}|"* ]] && found=yes
        done
        printf "%s=%s\n" "${expected}" "${found}"
    done
')"
assert_contains "exactly 8 desktop records load" "${out}" "count=8"
for d in xfce4 lxqt lxde mate i3wm openbox fluxbox jwm; do
    assert_contains "desktop '${d}' is present in the catalog" "${out}" "${d}=yes"
done

section "get_desktop_record()"
out="$(run_module "${SBOX}" linux_env '
    get_desktop_record "xfce4" >/dev/null 2>&1 && printf "xfce4=found\n" || printf "xfce4=missing\n"
    printf "startup_binary=%s\n" "${DEVILS_MINIOS_RECORD_FIELDS[3]}"
    get_desktop_record "gnome" >/dev/null 2>&1 && printf "gnome=found\n" || printf "gnome=missing\n"
')"
assert_contains "get_desktop_record finds xfce4" "${out}" "xfce4=found"
assert_contains "xfce4 startup_binary is startxfce4" "${out}" "startup_binary=startxfce4"
assert_contains "unsupported desktop (gnome) is rejected/absent" "${out}" "gnome=missing"

section "generate_xstartup: success path (distro-arg rootfs selection)"
out="$(run_module "${SBOX}" linux_env '
    rootfs="${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    mkdir -p "${rootfs}"
    generate_xstartup "ubuntu" "startxfce4" "-"
    printf "rc=%s\n" "$?"
    cat "${rootfs}/root/.vnc/xstartup" 2>/dev/null
')"
assert_contains "generate_xstartup succeeds for an installed distro + allowlisted binary" "${out}" "rc=0"
assert_contains "generated xstartup invokes the requested startup binary" "${out}" "startxfce4"

section "generate_xstartup: distro selects the correct rootfs path"
out="$(run_module "${SBOX}" linux_env '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/debian"
    generate_xstartup "debian" "startlxde" "-" >/dev/null 2>&1
    [[ -f "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/debian/root/.vnc/xstartup" ]] && printf "debian_xstartup=written\n" || printf "debian_xstartup=missing\n"
    [[ -f "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu/root/.vnc/xstartup" ]] && printf "ubuntu_xstartup=written\n" || printf "ubuntu_xstartup=missing\n"
')"
assert_contains "xstartup is written under the selected distro's own rootfs" "${out}" "debian_xstartup=written"

section "generate_xstartup: rejects non-allowlisted startup_binary"
out="$(run_module "${SBOX}" linux_env '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    generate_xstartup "ubuntu" "gnome-session" "-" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "generate_xstartup rejects a startup_binary outside the allowlist" "${out}" "rc=2"

section "generate_xstartup: rejects when rootfs is not installed"
out="$(run_module "${SBOX}" linux_env '
    generate_xstartup "fedora" "startxfce4" "-" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "generate_xstartup rejects an uninstalled distro rootfs" "${out}" "rc=3"

section "generate_xstartup: rejects unknown distro"
out="$(run_module "${SBOX}" linux_env '
    generate_xstartup "no-such-distro" "startxfce4" "-" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_contains "generate_xstartup rejects an unknown distro id" "${out}" "rc=2"

section "generate_xstartup: startup_args tokens validated and %q-escaped"
out="$(run_module "${SBOX}" linux_env '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    generate_xstartup "ubuntu" "startxfce4" "arg1,arg2" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
    cat "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu/root/.vnc/xstartup"
')"
assert_contains "valid comma-separated startup_args are accepted" "${out}" "rc=0"
assert_contains "startup_args tokens appear in the generated xstartup" "${out}" "arg1"

out="$(run_module "${SBOX}" linux_env '
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    generate_xstartup "ubuntu" "startxfce4" "bad;arg" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_ne "startup_args containing shell metacharacters are rejected" "0" "$(printf '%s' "${out}" | grep -o 'rc=.' | cut -d= -f2)"

section "Systemd-dependent desktop warning"
out="$(cat modules/linux_env.sh)"
assert_contains "systemd-dependent desktops trigger a warning before continuing" "${out}" "depends on systemd, which is not available under proot"

section "E440: systemd-dependent desktop declined by user -> exit 4, E440 logged at INFO"
SBOX_E440="$(new_sandbox)"
out="$(run_module "${SBOX_E440}" linux_env '
    printf "# name|description|packages|startup_binary|startup_args|systemd_flag|min_ram_mb\njwm|JWM (systemd-flagged for test)|jwm|jwm|-|true|384\n" > "${DEVILS_MINIOS_INSTALL_DIR}/data/desktops.db"
    mkdir -p "${DEVILS_MINIOS_LOG_DIR}"
    printf "jwm\nn\n" | _linux_env_setup_desktop
    printf "rc=%s\n" "${PIPESTATUS[1]}"
    grep -h "E440" "${DEVILS_MINIOS_LOG_DIR}/launcher.log" 2>/dev/null | sed "s/^/logged: /"
')"
assert_contains "E440: declining the systemd acknowledgement logs the registered code (INFO, in launcher.log)" "${out}" "logged: "
assert_contains "E440: the logged entry carries the E440 code and INFO level" "${out}" "INFO"
assert_contains "E440: declined acknowledgement returns exit status 4" "${out}" "rc=4"
assert_not_contains "E440: a decline is INFO, not an ERROR-level entry" "${out}" "ERROR [E440]"

section "systemd_flag=true: acknowledge-then-proceed path continues past the gate (PRD §35.3)"
SBOX_E440OK="$(new_sandbox)"
out="$(run_module "${SBOX_E440OK}" linux_env '
    printf "# name|description|packages|startup_binary|startup_args|systemd_flag|min_ram_mb\njwm|JWM (systemd-flagged for test)|jwm|jwm|-|true|384\n" > "${DEVILS_MINIOS_INSTALL_DIR}/data/desktops.db"
    mkdir -p "${DEVILS_MINIOS_LOG_DIR}"
    printf "jwm\ny\nno-such-distro\n" | _linux_env_setup_desktop >/dev/null 2>&1
    printf "rc=%s\n" "${PIPESTATUS[1]}"
    grep -h "systemd dependency acknowledged; continuing" "${DEVILS_MINIOS_LOG_DIR}/launcher.log" 2>/dev/null | sed "s/^/logged: /"
')"
assert_ne "acknowledging the systemd warning does not return the declined exit status (4)" "4" "$(printf '%s' "${out}" | grep -o 'rc=.' | cut -d= -f2)"
assert_contains "acknowledging the systemd warning logs continuation and proceeds to the next step (distro selection)" "${out}" "logged: "

section "warn_proot_limits: all five limitation classes are present (PRD §35.3)"
out="$(cat core/core_platform.sh)"
assert_contains "warn_proot_limits documents kernel limitations" "${out}" "kernel"
assert_contains "warn_proot_limits documents systemd limitations" "${out}" "systemd"
assert_contains "warn_proot_limits documents GUI limitations" "${out}" "GUI"
assert_contains "warn_proot_limits documents device access limitations" "${out}" "device access"
assert_contains "warn_proot_limits documents root limitations" "${out}" "root"

section "Malformed database record handling (§18, §41.1)"
SBOX2="$(new_sandbox)"
out="$(run_module "${SBOX2}" linux_env '
    {
        printf "# id|name|proot_id|architectures|priority|status|package_manager\n"
        printf "badrow|too|few|fields\n"
        for i in $(seq 1 25); do
            printf "distro%02d|Distro %02d|distro%02d|all|%d|supported|apt\n" "${i}" "${i}" "${i}" "${i}"
        done
    } > "${DEVILS_MINIOS_INSTALL_DIR}/data/proot_distros.db"
    load_database "$(data_file_path proot_distros.db)" 7 _validate_distro_record
    printf "total=%s\n" "${DEVILS_MINIOS_CATALOG_TOTAL}"
    printf "malformed=%s\n" "${DEVILS_MINIOS_CATALOG_MALFORMED}"
    printf "loaded=%s\n" "${#DEVILS_MINIOS_CATALOG[@]}"
')"
assert_contains "malformed record is counted, not silently ignored" "${out}" "malformed=1"
assert_contains "well-formed records still load when malformed count is within the 5% tolerance" "${out}" "loaded=25"

section "Malformed record is WARN-logged with the offending line number (§18, §41.1)"
SBOX2W="$(new_sandbox)"
out="$(run_module "${SBOX2W}" linux_env '
    mkdir -p "$(get_config_dir)/logs"
    {
        printf "# id|name|proot_id|architectures|priority|status|package_manager\n"
        printf "badrow|too|few|fields\n"
        printf "ubuntu|Ubuntu|ubuntu|all|10|supported|apt\n"
    } > "${DEVILS_MINIOS_INSTALL_DIR}/data/proot_distros.db"
    load_database "$(data_file_path proot_distros.db)" 7 _validate_distro_record >/dev/null
    grep -c "Malformed database record" "$(get_log_file)" 2>/dev/null
')"
assert_contains "a WARN log entry is written for the malformed record" "${out}" "1"

section "Malformed-record tolerance exceeded -> safe degradation (§41.1)"
out="$(run_module "${SBOX2}" linux_env '
    mkdir -p "$(get_config_dir)/logs"
    cat > "${DEVILS_MINIOS_INSTALL_DIR}/data/proot_distros.db" <<EOF
# id|name|proot_id|architectures|priority|status|package_manager
ubuntu|Ubuntu|ubuntu|all|10|supported|apt
badrow|too|few|fields
EOF
    load_database "$(data_file_path proot_distros.db)" 7 _validate_distro_record
    printf "loaded=%s\n" "${#DEVILS_MINIOS_CATALOG[@]}"
    grep -c "exceeds malformed-record tolerance" "$(get_log_file)" 2>/dev/null | tail -1
')"
assert_contains "exceeding the malformed-record tolerance degrades to an empty catalog rather than a crash" "${out}" "loaded=0"
assert_contains "exceeding tolerance logs E105 safe-degradation evidence" "${out}" "exceeds malformed-record tolerance"
section "Missing catalog disables only the dependent feature (§41.1)"
SBOX2M="$(new_sandbox)"
rm -f "${SBOX2M}/usr/opt/devils-minios/data/proot_distros.db"
out="$(run_module "${SBOX2M}" linux_env '
    load_database "$(data_file_path proot_distros.db)" 7 _validate_distro_record >/dev/null 2>&1
    printf "catalog_size=%s\n" "${#DEVILS_MINIOS_CATALOG[@]}"
    type execute_structured >/dev/null 2>&1 && printf "core_alive=yes\n" || printf "core_alive=no\n"
')"
assert_contains "missing catalog yields an empty dependent catalog" "${out}" "catalog_size=0"
assert_contains "missing catalog does not disable unrelated core/module functionality" "${out}" "core_alive=yes"

section "run_desktop_startup: allowlisted binary dispatches via execute_structured (PRD-23.2-01, §23.2)"
SBOX_RDS="$(new_sandbox)"
out="$(run_core "${SBOX_RDS}" '
    execute_structured() { printf "EXEC:%s\n" "$*"; return 0; }
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    run_desktop_startup "ubuntu" "startxfce4" "-"
    printf "rc=%s\n" "$?"
')"
assert_contains "run_desktop_startup dispatches via execute_structured(executor=proot-distro, action=login)" "${out}" "EXEC:proot-distro login ubuntu -- startxfce4"
assert_contains "run_desktop_startup with an allowlisted binary succeeds" "${out}" "rc=0"

out="$(run_core "${SBOX_RDS}" '
    execute_structured() { printf "EXEC:%s\n" "$*"; return 0; }
    mkdir -p "${DEVILS_MINIOS_PROOT_ROOTFS_DIR}/ubuntu"
    run_desktop_startup "ubuntu" "not-a-real-binary" "-" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_ne "run_desktop_startup rejects a non-allowlisted startup_binary (E402)" "0" "$(printf '%s' "${out}" | grep -o 'rc=.' | cut -d= -f2)"

SBOX_RDS2="$(new_sandbox)"
out="$(run_core "${SBOX_RDS2}" '
    execute_structured() { printf "EXEC:%s\n" "$*"; return 0; }
    run_desktop_startup "ubuntu" "startxfce4" "-" >/dev/null 2>&1
    printf "rc=%s\n" "$?"
')"
assert_ne "run_desktop_startup refuses to launch when the distro rootfs is not installed" "0" "$(printf '%s' "${out}" | grep -o 'rc=.' | cut -d= -f2)"

print_summary "test_linux_env.sh"
exit $?
