# Devil's Mini OS Launcher
## Master Production-Level Product Requirements Document (Third Hardening Pass, Implementation-Ready, Audit-Ready)

**Document:** Master Production PRD (Hardened Baseline)
**Product:** Devil's Mini OS Launcher
**Release:** v1.0.0
**Status:** Production Baseline / Implementation-Ready
**Author:** buildwithdhanush
**License:** MIT
**Primary Platform:** Termux on Android
**Implementation Language:** Pure Bash (4.3 minimum, 5.x recommended)
**PRD Revision:** 6.2
**Date:** 2026-09-26

---

## 0. Document Control

| Field | Value |
|---|---|
| PRD Version | 6.2 — third hardening pass. Consolidates Sources S1–S5 (§0.1), the S5 remediation findings (§0.2), the S6 second-pass audit findings (§0.3), and the S7 30-Question Connectivity and Delta Audit findings (§0.4). This document is the sole normative specification. |
| Product Version Governed | v1.0.0 (SemVer 2.0.0, sole version scheme) |
| Status | Production Baseline / Implementation-Ready / Audit-Ready |
| Owner / Approved By | buildwithdhanush (BDFL, per §37) |
| Change Control | Any change to an Authoritative Decision requires an explicit PRD revision, never a silent code-side deviation. Every normative number appears in exactly one section. Normative changes are recorded per the change-governance fields in §37.2. |
| Correction scope | This revision is a hardening pass, not a redesign. It resolves every S7 finding (§0.4) against the S1–S6 baseline (§0.1–§0.3) without weakening any prior binding decision (Appendix A) unless an S7 finding explicitly required the change. Only findings classified as a genuine clarification or a genuine requirement addition (companion `PRD-6.2-AUDIT-MAP.md`) modify normative text; findings already satisfied or concerning implementation evidence only leave the underlying requirement unchanged. |

### 0.1 Source Material Used

| # | Input | Role in this PRD |
|---|---|---|
| S1 | Draft baseline (73-section) | Baseline; resolved point-by-point, see Appendix C |
| S2 | Audit item set (26 questions Q1–Q26, 53 decisions AD-01–AD-53, 11 section removals R-01–R-11, 12 cleanup mandates CL-01–CL-12) | Binding audit decisions; traced in Appendix B |
| S3 | 14 Final Design Decisions D1–D14 + consolidated draft | Binding final decisions; traced in Appendix A |
| S4 | Prior implementation baseline (15 modules, in-place `install.sh`, 18 test files, data catalogs) | Implementation baseline; gap analysis in §50, resolution log in Appendix C |
| S5 | First remediation audit report (P0-01…P0-06, P1-01…P1-08, P2-01…P2-05, SC-01) | Binding remediation requirements; traced in §0.2 and Appendix C |
| S6 | Second-pass hardening audit ("Report.md" — P0-1…P0-6, P1-1…P1-7, P2-1…P2-5) | Binding correction requirements for this revision; traced in §0.3 and Appendix E |
| S7 | Third-pass 30-Question Connectivity and Delta Audit (Q1–Q30, PRD 6.1 → 6.2) | Binding hardening/operationalization input for this revision; traced in §0.4 and the companion `PRD-6.2-AUDIT-MAP.md` |

**Reconciliation rule:** S3 is authoritative over S1/S2 where they conflict (Appendix C). S5 is authoritative over all prior sources for the items it addresses. S6 is authoritative over S1–S5 for the items it addresses, and is applied as a correction to the existing S1–S5 baseline rather than as new scope. S7 is authoritative over S1–S6 only for the items it addresses, and is applied as hardening/operationalization of the existing S1–S6 baseline rather than as new scope or a product redesign. No requirement is silently dropped; every input item is mapped in the Appendices (S1–S6) or the companion `PRD-6.2-AUDIT-MAP.md` (S7). No S6 or S7 finding is resolved by inventing implementation data (exact catalog records, exact test bodies, exact generated checksums, exact ownership assignments) not present in S1–S7; where the exact data cannot be established from the supplied sources, this revision defines the required authoritative implementation artifact and its validation/completeness/release-gate/ownership obligations instead (Appendix D, §0.3, §0.4).

### 0.2 Remediation Traceability (S5)

Every finding from the first remediation audit is resolved in this revision. Full detail is in the referenced section; the complete matrix is in §55 (Remediation Report).

| Finding | Resolution section |
|---|---|
| P0-01 Persistent state lifecycle | §26.4 |
| P0-02 Command template grammar | §18.2, §23.1 |
| P0-03 Desktop startup execution | §18.4, §23.2 |
| P0-04 GitHub/script install trust | §18.3, §23.3 |
| P0-05 Update trust anchor | §30.4 |
| P0-06 Integrity vs authenticity | §30.5 |
| P1-01 Performance metric | §20 |
| P1-02 / P1-03 Config vs runtime context | §17 |
| P1-04 Storage thresholds | §25.1 |
| P1-05 Crash flag lifecycle | §26.5 |
| P1-06 Reset/uninstall semantics | §33, §39 |
| P1-07 Safe Mode dependency fallback | §40 |
| P1-08 Installer deletion boundary | §30.1 |
| SC-01 Historical/supersession language | Throughout (neutral Source/Decision/Resolution wording) |

### 0.3 Second-Pass Hardening Traceability (S6)

Every finding from the S6 hardening audit is resolved or, where exact implementation data is out of scope for a PRD, converted into an explicit authoritative-artifact requirement in this revision. Nothing is left as an unresolved release-blocker. The complete matrix, including the audit's own finding text, is in Appendix E.

| Finding | Subject | Resolution section |
|---|---|---|
| S6 P0-1 | Command Execution Contract completeness | §23.0, §23.1 |
| S6 P0-2 | Path Validation Algorithm completeness | §22.1 |
| S6 P0-3 | Automatic Recovery Allowlist (concrete table) | §26.1 |
| S6 P0-4 | Crash-flag lifecycle completeness | §26.5 (confirmed complete; no change required) |
| S6 P0-5 | `terminal_width` persistence contradiction | §17.3, §19.2 (confirmed already runtime-only; no contradiction present) |
| S6 P0-6 | Automatic Git-checkout deletion danger | §30.1 (confirmed already ownership-bounded; no change required) |
| S6 P1-1 | First-boot failure transitions | §39 |
| S6 P1-2 | Nuclear reset state transition | §33.1, §39 (confirmed already `RECOVERY → FIRST_BOOT`; no change required) |
| S6 P1-3 | Proot distro catalog completeness | §18.1, Appendix D, §47.3 |
| S6 P1-4 | Application catalog completeness | §18.2, §18.3, Appendix D, §47.3 |
| S6 P1-5 | `systemd_flag` ambiguity | §35.3 |
| S6 P1-6 | Error-code registry completeness | §48.2 |
| S6 P1-7 | Integrity vs authenticity separation | §30.5 (confirmed already separated; no change required) |
| S6 P2-1 | Complete requirement traceability | §43.5 |
| S6 P2-2 | Test-count over-constraint | §43.1 |
| S6 P2-3 | Performance measurement conditions | §20 |
| S6 P2-4 | `--offline` operation matrix | §15.1 |
| S6 P2-5 | `--no-checks` operation matrix | §15.2 |

### 0.4 Third Hardening Pass Traceability (S7 / 30-Question Audit)

The S7 audit (`PRD-6.1-30-Question-Audit.md`, Q1–Q30) evaluated PRD 6.1 against a 30-question decision framework and concluded that PRD 6.1 is an already-hardened normative baseline; the correct S7 strategy is incremental hardening, not redesign. Full per-question (Q1–Q30) classification, rationale, and disposition are maintained in the companion document `PRD-6.2-AUDIT-MAP.md`, which is authoritative for that finding-by-finding detail and is not duplicated here. This table records only the genuine PRD 6.2 changes S7 produced and where they land.

| Area | S7 focus (Q#) | Resolution section |
|---|---|---|
| Audience hierarchy | Q3 | §4.4 |
| Requirement identity and traceability fields | Q9, Q10, Q14 | §43.5 |
| Requirement/evidence ownership | Q15, Q27 | §43.5 |
| Global conflict-resolution priority | Q8, Q13 | §37.1 |
| Normative change governance | Q22 | §37.2 |
| Critical-workflow acceptance mapping | Q17, Q18 | §45.1 |
| Requirement-vs-evidence boundary | Q25 | §43.5 |
| Migration verification contract | Q26 | §32.2 |
| Observability/recovery evidence contract | Q28 | §26.6 |
| Production/Implementation/Audit readiness synthesis | Q30 | §54 |

Findings classified by S7 as already covered (Q1, Q2, Q4, Q5, Q6, Q7, Q11, Q12, Q16, Q19, Q20, Q21, Q23, Q24) required no normative change and are confirmed unchanged. Findings classified as implementation/evidence gaps rather than PRD defects are addressed by strengthening the applicable evidence/verification contract, never by fabricating the missing evidence itself (§0.1 reconciliation rule). Q29 (audit report structure) is a governance-artifact matter and is not reflected as product architecture. **S7 disposition after this revision: 0 items remain classified as an unresolved genuine PRD defect.**

---

## 1. Document Purpose

This document is the **single source of truth** for Devil's Mini OS Launcher v1.0.0. It defines product requirements, architecture, modules, configuration, data schemas, security model, runtime/recovery behavior, installation/update lifecycle, testing, release gates, acceptance criteria, and migration obligations. No other document may override it.

---

## 2. Product Definition

### 2.1 Product Name
**Devil's Mini OS Launcher**

### 2.2 Core Positioning
> **The easiest way to turn Termux into a managed Linux workstation on Android.**

The product is not merely a collection of Bash scripts. Its long-term differentiation is: compatibility knowledge, a curated Linux ecosystem, reliability, safety guardrails, proot-awareness, simple onboarding, and community-derived compatibility information. Pure Bash is an engineering constraint, not the primary product moat.

### 2.3 Problem Statement
A Termux power user must manually execute dozens of commands, manage configuration files, diagnose compatibility problems, and repeat setup steps to reach a usable Proot/Linux development environment. This is error-prone, undocumented, and hostile to newcomers.

### 2.4 Success Criteria

| # | Criterion | Target |
|---|---|---|
| SC-1 | Fresh Termux → running Linux workflow | Achievable in under 15 minutes of guided interaction |
| SC-2 | Installer → successful first launch | ≥70% |
| SC-3 | Sessions ending in critical failure | <5% |
| SC-4 | Known critical security vulnerabilities at launch | 0 |
| SC-5 | All **19** mandatory test files passing on `aarch64` and `x86_64` before tag | 100% (§43.1 shows the resolution arithmetic) |

---

## 3. Product Vision

Devil's Mini OS Launcher moves a Termux user from **Fresh Termux → usable Linux environment → development workflow** without manual management of commands, configs, compatibility problems, or repetitive setup. The product behaves as a **small managed environment** — with state, lifecycle, compatibility awareness, observability, recovery, security boundaries, modular functionality, and resource awareness — not merely a menu script.

---

## 4. Users and Personas

### 4.1 Primary User
**Termux power user / developer** — the primary persona for all requirements.

### 4.2 Personas

| Persona | Role | Needs | Key constraint |
|---|---|---|---|
| **Mobile Developer** | Dev on Android | Linux env, git, Node.js, dev tools, GUI desktop, workspace templates | Must not need root |
| **Linux Enthusiast** | Experimenter | Multiple distros, lightweight desktops, safe experimentation, compatibility info | Proot limits must be honestly stated |
| **Security Researcher** | Research/auditing | Kali/proot workflows, networking tools, ADB, fastboot | Root-dependent features never represented as available; the launcher never requests or attempts root escalation |
| **Student / Casual User** | Learner | Guided onboarding, clear terminology, safe defaults, explicit Termux-source guidance | Must be warned away from Play Store builds |
| **Termux Desktop / CLI User** | CLI/TUI user on Android | Proot-based Linux workflow, GUI desktop, file management | Termux/Android platform only |

### 4.3 Core Job
> Turn a fresh Termux installation into a usable Linux development environment without manually managing dozens of commands and configurations.

### 4.4 Audience Hierarchy (S7 Q3 clarification)

This clarifies the relationship between market reach and UX/technical priority; it changes no technical scope, module, or requirement elsewhere in this PRD.

| Layer | Value |
|---|---|
| Primary market | General Termux users |
| UX priority | Beginner-first (onboarding, defaults, terminology, error messages — §27, §19) |
| Primary technical persona | Termux developer / power user (§4.1 — drives the depth and correctness bar for every requirement) |
| Important subgroups | Students, developers, power users, Linux enthusiasts (§4.2) |

**Reading rule:** "Primary technical persona" (§4.1) sets the correctness/security/completeness bar for requirements; "UX priority" governs default behavior, onboarding flow (§27), and terminal-mode presentation (§19) so that a beginner in the primary market is not required to already understand Linux/proot concepts to reach a working result (§54's primary user journey). Neither layer overrides the other; both apply simultaneously, exactly as in §4.2's persona table.

---

## 5. Goals

| Goal | v1.0.0 Requirement |
|---|---|
| Termux compatibility | F-Droid/GitHub Termux supported |
| Android compatibility | Android 10.0+ / API 29+ target |
| Bash | 4.3 minimum, 5.x recommended (identical wording in every section; see §9, §10) |
| Proot distributions | Dynamically discovered from the currently installed official `proot-distro` catalog, matched against `data/proot_distros.db` |
| Desktop environments | Exactly 8 Tier-1 entries (no experimental desktops) |
| Proot applications | Exactly 40 |
| Termux applications | 30–40 |
| Architecture filtering | Required and total (every record filterable; see §18) |
| Safe mode | Required |
| Structured logging | Required |
| Crash recovery | Required (incl. crash-loop protection) |
| Responsive terminal UI | Required (Full / Compact / Minimal) |
| Security validation | Required |
| Test suite | Exactly **19** test files (`run_all.sh` harness exempt; report generator writes `data/reports/report.md`) |
| Module architecture | Exactly **14 active modules**; `future_plans.sh` removed (D1) |

**Explicitly and completely removed for v1.0.0 (absent, not degraded, not hidden):** plugin system; Nix integration; background health daemon; `future_plans.sh`; experimental desktops; `recent_actions.sh`; free-form shell command templates of any kind (§18.2, §18.3, §18.4); the `script` application-install source (§18.3).

---

## 6. Non-Goals for v1.0.0

Third-party plugin execution; Nix package manager integration; `recent_actions.sh`; background health daemon; i18n implementation (the `language` key is reserved and locked to `en`); compiled components; Python runtime; Node.js runtime for the launcher; `curl | bash` installation; automatic privileged/root operations; native Linux host support; GNOME and KDE Plasma desktops; script-based (`install_source=script`) application installation.

---

## 7. Core Technical Constraints

1. **Pure Bash** — only Bash, standard shell utilities, and standard Termux/Android utilities. No Python, Node.js, Go, Rust, or compiled helper binaries.
2. **No unnecessary runtime dependency** may be introduced.
3. **Completely rootless** — the launcher never requests, invokes, or attempts privilege escalation. Root-requiring operations are detected and rejected with a clear explanation.
4. **No `curl | bash` / `wget | bash`.** Documented path: `git clone` → inspect → `bash install.sh` (see §30).
5. **No dynamic shell interpretation anywhere in the product.** No catalog record, configuration value, or user input may ever reach `eval`, `sh -c`, `bash -c`, or an equivalent. This is now enforced structurally, not just by convention (§18.2, §18.3, §18.4, §23).

---

## 8. Supported Platforms

**Termux on Android is the only supported host platform.** Supported Termux sources: F-Droid, GitHub builds. Play Store builds are detected and prominently warned about on every invocation (§35.2). Proot is a compatibility environment, not kernel-level virtualization; proot-sensitive operations receive limitation warnings (§35.3). Native Linux execution is out of scope: no native-Linux-specific installation path, runtime path, shell integration, or compatibility promise may be implemented.

---

## 9. Minimum Requirements

| Requirement | Minimum | Recommended |
|---|---:|---:|
| Android | 10.0 / API 29 | Newer Android |
| Bash | **4.3** (single stated floor; identical in §5, §9, §10, §46) | Latest 5.x |
| Storage | 500 MB | 2 GB+ |
| RAM | 2 GB | 4 GB+ |
| Terminal width | 40 columns (recommended); **<40 columns supported in Minimal mode** (mandatory) | 60+ |
| Architecture | `aarch64`, `x86_64` (canonical names only, no aliases) | `aarch64` |
| Termux | F-Droid/GitHub | F-Droid/GitHub |

---

## 10. Compatibility & Support Matrix

| Component | Supported | Minimum | Notes |
|---|---|---|---|
| Termux source | F-Droid, GitHub | 0.118+ | Play Store unsupported |
| Android API | 29+ | 29 | Android 10.0+ |
| Bash | 4.3, 5.x | **4.3** | 5.x recommended; one stated floor |
| Architectures | `aarch64`, `x86_64` | — | `aarch64` primary |
| Proot-distro | Latest stable | — | Verified at release |

Unsupported combinations fail gracefully with explicit messaging. Canonical architecture names (`aarch64`, `x86_64`) are used in code, data files, tests, and documentation — no aliases.

---

## 11. Architecture

```text
Launcher Entry Point (devils-minios.sh)
        │
        ▼
Core Runtime (modules/core.sh)
        │   ├── Platform Detection │ Configuration │ Logging │ Security │ Recovery │ UI
        ▼
Feature Modules (13 feature modules + core = exactly 14, §12)
        │   ├── Proot/Desktops (linux_env.sh)
        │   ├── Apps (termux_apps.sh, proot_apps.sh)
        │   ├── Android Tools (android_tools.sh)
        │   ├── Workspace (workspace.sh)
        │   ├── System Tools (system_tools.sh, system_info.sh, health_check.sh, update_all.sh)
        │   ├── Configuration (settings.sh, customize.sh)
        │   └── Meta (file_mgr.sh, log_viewer.sh)
        ▼
Static Data (data/)
        ├── proot_distros.db, desktops.db, proot_apps.db, termux_apps.db
        ├── defaults.conf, banners/, themes/, reports/
```

---

## 12. Authoritative Module Architecture — Exactly 14 Modules (D1)

```text
modules/
├── core.sh           ── core runtime (always loaded)
├── linux_env.sh      ├── proot distros + desktops (desktop_env merged in)
├── file_mgr.sh       │
├── termux_apps.sh    │
├── proot_apps.sh     │
├── android_tools.sh  │
├── workspace.sh      │
├── health_check.sh   │
├── log_viewer.sh     │
├── customize.sh      │
├── system_tools.sh   │
├── system_info.sh    │
├── update_all.sh     │
└── settings.sh       ┘
```

This is the complete active module set for v1.0.0. **`modules/future_plans.sh` must not exist, must not be referenced, and must not be loaded.** No roadmap or future-planning module is part of the runtime architecture. No `plugins/` directory is ever created. The `--run-module` alias `future | roadmap` is removed (§15).

---

## 13. Module Responsibilities & Contracts

**Contract standard (D11):** every public module function documents name, args, returns, and side effects; private functions are prefixed `_`. All security-sensitive execution and all configuration/logging mutation are centralized in `core.sh`.

### 13.1 `core.sh`
Platform detection; Termux source detection; path resolution; configuration load/validate/save; runtime-context construction (§17.4); logging; log rotation and retention (sole owner); error handling; crash recovery; crash-loop protection; safe mode; terminal width detection (re-detected every launch, never persisted); UI primitives; input validation; security helpers; **the single centralized structured executor**; theme helpers; banner helpers; signal handling; persistent-state read/write (§26.4).

**Required functions (complete list):**
```text
get_log_file()  write_log_file()  rotate_and_purge_logs()      # sole owner (§24)
get_config_dir()  get_cache_dir()  get_bin_dir()  get_tmp_dir()  get_etc_dir()
detect_platform()  detect_termux_source()  detect_terminal_width()
load_config()  save_config()  load_default_config()  validate_config()      # D12 grammar
build_runtime_context()                                               # §17.4 — never persisted
load_state()  save_state()  validate_state()  restore_state_from_backup()   # §26.4
sanitize_log_for_upload()  warn_play_store()  warn_proot_limits()
draw_box_top()  draw_box_line()  draw_box_bottom()
show_main_menu_full()  show_main_menu_compact()  show_main_menu_minimal()
handle_sigint()  sanitize_input()  validate_path()
apply_theme()  set_banner()  show_banner()
error_handler()  trigger_safe_mode()  record_state_transition()
execute_structured()                                          # §23.1 — the sole command executor
install_proot_package(distro_id, package_id)                  # §18.2 — the only proot-app install path
run_desktop_startup(distro_id, startup_binary, startup_args)  # §18.4 — the only desktop startup path
install_github_artifact(repository, ref, artifact, sha256)    # §18.3 — the only GitHub install path
check_storage_threshold(required_bytes)                       # §25.1
```

Logging primitives (append + atomic write + flock fallback per §23.4) and rotation policy (§24) are implemented here and **only** here. Runtime dirs include `tmp/`, `pids/`, `crashes/`, `templates/`, `banners/` under the config dir plus a cache dir; these are created by the installer (§30) and never on external storage.

### 13.2 `linux_env.sh`
Proot distribution detection/install/launch/backup/restore; clone/import workflows; package-manager detection; desktop management; desktop installation; VNC/X11 preparation; xstartup generation via the structured startup contract (§18.4, §23.2); proot warnings.

**Required function:**
```text
generate_xstartup(distro, startup_binary, startup_args)
```
- `distro` (string, required): proot distro name (e.g. `ubuntu`); selects the rootfs via `proot-distro list --json` resolution / registered rootfs directory so xstartup is written inside the correct distro's filesystem (e.g. `~/.local/share/proot-distro/installed/<distro>/root/.vnc/xstartup`), never assuming Ubuntu paths.
- `startup_binary` (string, required): the desktop's allowlisted startup binary from `desktops.db` (§18.4).
- `startup_args` (comma list, may be empty): validated literal arguments from `desktops.db` (§18.4, §23.2).
- Creates `/root/.vnc/xstartup` **inside the selected distro's rootfs** with a Bash shebang, the validated `startup_binary`/`startup_args` invocation, and executable permission. No shell metacharacter from either field is ever interpolated unescaped; both are written using `printf %q`-equivalent quoting.
- Returns `0` success; `2` unknown distro; `3` distro rootfs not installed; `4` `startup_binary` fails allowlist validation.

### 13.3 `file_mgr.sh`
Browse; search; read; copy; transfer; rename; delete; symlink; bulk delete; hidden-file handling. External-storage file access only with explicit confirmation; execution from external storage always blocked (§22). Destructive operations require confirmation.

### 13.4 `termux_apps.sh`
Termux-native app discovery; categories; source awareness; structured install dispatch (`pkg` via package manager, `github` via `install_github_artifact()`, §18.3, §23.3); graceful degradation when a listed source/package is unavailable. DB: `data/termux_apps.db` (§18.3). Target: **30–40 entries**. Required categories: `development, browsers, desktop, cli, system, security, media, networking`.

### 13.5 `proot_apps.sh`
Curated app discovery; category filtering; **total architecture filtering** (§18.2); proot compatibility filtering; structured install dispatch via `install_proot_package()` (§18.2, §23.1). DB: `data/proot_apps.db` (§18.2). Exactly **40 applications**, all 13 categories represented. Every record has exactly **7 pipe-delimited fields**.

Module menu must include a persistent **"Show incompatible architectures"** toggle (default: hidden). With the toggle on, incompatible apps display with their architecture clearly labeled and are installable only after an explicit confirmation that names the mismatch.

### 13.6 `android_tools.sh`
ADB; fastboot; Termux:API detection; Android-specific helpers. Termux:API is optional: if unavailable, hide unsupported features, provide fallback behavior, never crash (§25.2).

### 13.7 `workspace.sh`
Workspace templates; project creation; dependency detection; HOME enforcement. **Default allowed workspace root: `$HOME/devils-minios/workspaces/` (D3).** User-provided paths validated (§22); workspace creation never silently escapes the allowed directory; external storage is never an execution workspace.

### 13.8 `health_check.sh`
On-demand system diagnostics: platform, Android, storage, battery, proot, configuration. **No background daemon.** Uses the diagnostic result cache (§25.3); `health_check_interval` is its staleness threshold.

### 13.9 `log_viewer.sh`
Read-only log viewing: viewing, filtering, searching, live tail, archive **export**, and an explicit **Exit** action returning to the previous menu/module without terminating the launcher. Boundary: `log_viewer.sh` **never rotates, truncates, or deletes log files**; "Clear logs" and "Export archive" are implemented as **calls into `core.sh`** so a single writer owns mutation (§24).

### 13.10 `customize.sh`
Themes; banners; banner animation; user customization. Theme changes idempotent; no duplicate shell configuration blocks (§38).

### 13.11 `system_tools.sh`
Backup; restore; process management; maintenance. Dangerous process operations require explicit confirmation (§23.4). Never uses unsafe blanket commands such as `pkill -u "$(whoami)"` without controlled targeting and confirmation.

### 13.12 `system_info.sh`
Platform information; Android version; architecture; Bash version; terminal width; storage information; environment information.

### 13.13 `update_all.sh`
Selective updates; dry-run mode; ordered update operations; failure reporting; asks for proot or Termux scope.

### 13.14 `settings.sh`
Configuration editing; reset; export/import in supported formats; validation delegates to `core.sh::validate_config()` (§17.5 strict import). Also exposes the reset actions defined in §33.1 (configuration reset, state reset).

---

# 14. Entry Point

Primary executable: `devils-minios.sh`. Installed command: `devils-minios` (symlink created by the installer, §30).

Startup sequence (deterministic):

1. Verify Bash version (**≥4.3**, before enabling strict shell options)
2. Resolve real installation path (symlink resolution)
3. Initialize runtime paths
4. Load required modules via the `core.sh` loader (exactly the 14 module files per §12)
5. Detect platform (once; cached for the session)
6. Detect Termux source
7. Load and validate persistent state (`load_state()`, §26.4); load and validate configuration (`validate_config()`, §17)
8. Build the in-memory `runtime_context` (§17.4) — never written to disk at this step
9. Install crash traps
10. Read the crash flag if present and apply its lifecycle rules (§26.5)
11. Handle safe mode if flagged (crash flag valid, config corruption, state corruption, or `--safe-mode`)
12. Apply session-level overrides (`--debug`, `--offline`, `--no-checks`)
13. Run onboarding if not completed (§27)
14. Dispatch CLI commands (§15)
15. Execute `auto_launch` action if eligible (§27.5), otherwise enter the interactive menu

---

# 15. CLI Interface

| Flag | Behavior (defined here, in exactly one place) |
|---|---|
| `-h`, `--help` | Print usage and exit 0 |
| `-v`, `--version` | Print SemVer product version (`v1.0.0`) and exit 0 |
| `--safe-mode` | Force safe mode entry regardless of flags or crash state; highest precedence (§40) |
| `--debug` | Session-level override: `log_level=DEBUG` for this invocation only; not persisted to config |
| `--offline` | Disable/bypass all network-dependent operations (§29); complete operation matrix in §15.1 |
| `--no-checks` | Bypass only non-critical startup diagnostics (update check, optional battery/storage diagnostics). Security checks, platform compatibility checks, configuration validation, destructive-operation confirmations, crash-flag handling, and Safe Mode diagnostics still run; complete matrix in §15.2 |
| `--run-module <module>` | Launch one module directly (canonical names + aliases below); skips the interactive menu; `auto_launch` ignored |
| `--update` | Self-update via git against the trust anchor defined in §30.4 |
| `--uninstall` | Uninstall launcher installation per §30.3; preserve user state and Proot environments; only valid from `IDLE` (§39) |
| `--uninstall-auto-start` | Remove Termux:Boot auto-start file idempotently (§31) |
| `install.sh --verify` | Manifest checksum verification (§30.5) — an installer flag, not a launcher flag |

**CLI precedence (D13, deterministic, non-negotiable order):**
1. `-h/--help` and `-v/--version` terminate immediately with exit 0 (mutually exclusive; first wins).
2. `--safe-mode` overrides every other flag: entry into Safe Mode happens before any other dispatch, and crash-loop protection cannot be bypassed by any flag (§26).
3. `--debug`, `--offline`, `--no-checks` are session-level modifiers applied after safe-mode handling.
4. `--run-module <module>` dispatches directly; `auto_launch` is ignored whenever any CLI flag is present.
5. Lifecycle commands (`--update`, `--uninstall`, `--uninstall-auto-start`) run only from a validated startup; conflicting pairs (e.g. `--update --uninstall`) are rejected with an `E400`-class error and exit 2; `--uninstall` additionally requires the current state to be `IDLE` (§39) or it is rejected with `E401` and exit 2.
6. Unknown options print the error to stderr and exit 2.

**`--run-module` canonical names and aliases (14 active modules only):**
```text
linux_env
file_mgr | files
termux_apps
proot_apps
desktop_env | desktops   → resolves to linux_env (merged module)
android_tools | android
workspace
health_check | doctor
logs                      → log_viewer
customize | theme
system_tools | tools
system_info | info
update                    → update_all
settings
```
The alias `future | roadmap` **must not exist** (D1; `future_plans.sh` removed).

## 15.1 `--offline` Operation Matrix (S6 P2-4 resolution)

This table is authoritative and complete for every network-capable operation in v1.0.0. `--offline` (and the equivalent always-on offline detection when connectivity checks fail, §29) applies these rows uniformly regardless of how offline mode was entered.

| Operation | Offline behavior |
|---|---|
| View installed proot distro / launch installed distro | ALLOW (fully local) |
| Install a proot distro (`proot-distro install`) | REJECT — clear error naming the operation as network-dependent |
| Browse local `proot_apps.db` / `termux_apps.db` / `desktops.db` catalogs | ALLOW (static local data, §18) |
| Install a Termux app via `pkg` | REJECT |
| Install a Termux app via `github` (`install_github_artifact()`, §23.3) | REJECT |
| Install a proot app (`install_proot_package()`, §18.2) when the target proot package manager needs to fetch the package | REJECT |
| `--update` (self-update, §30.6) | REJECT at the fetch step (step 3); the command exits cleanly with a network-unavailable message, active installation untouched |
| `install.sh` fresh install from a local Git checkout or local ZIP already on disk | ALLOW (no network step is required once the source is already local) |
| Backup (§32.1) | ALLOW (local read/write only) |
| Restore (§32.1) | ALLOW (local read/write only) |
| Local diagnostics (`health_check.sh`, §13.8) | ALLOW; only the update-check sub-item of startup diagnostics is network-dependent and is skipped |
| Startup update-check (§14 step 12 area, `check_updates`) | REJECT (skipped silently — this is the one startup diagnostic that is inherently network-dependent, distinct from the `--no-checks` diagnostics in §15.2) |
| ADB/fastboot operations (`android_tools.sh`) | ALLOW (local USB/local-network device operations, not `OFFICIAL_REPOSITORY_URL`/GitHub traffic) |

A REJECT row surfaces a clear, specific error identifying the operation and that `--offline` (or detected unavailability) is the cause; it is never a silent no-op and never a generic failure.

## 15.2 `--no-checks` Operation Matrix (S6 P2-5 resolution)

`--no-checks` bypasses **only** the checks in the "May be skipped" column below. Every check in "May never be skipped" runs unconditionally regardless of `--no-checks`, `--offline`, or any other flag combination — this table is the complete and exclusive definition of the flag's scope (§47.1 treats any implementation that skips a "may never be skipped" row as a release-blocking security defect).

| Check | May be skipped by `--no-checks`? |
|---|---|
| Startup update-check network call (`check_updates`) | YES |
| Optional battery-level diagnostic display (informational, not a heavy-operation gate) | YES |
| Optional storage-headroom informational display (informational, not a heavy-operation gate) | YES |
| Non-critical startup banner/theme render diagnostics | YES |
| Bash version check (≥4.3, §14 step 1) | **NO** |
| Platform/Termux-source detection (§35.1) | **NO** |
| Configuration validation (`validate_config()`, §17) | **NO** |
| Persistent state validation (`load_state()`/`validate_state()`, §26.4) | **NO** |
| Crash-flag handling and crash-loop protection (§26, §26.5) | **NO** |
| Safe Mode entry diagnostics/routing (§40) | **NO** |
| Battery/storage gates for heavy operations (§25.1 — as opposed to the purely informational display above) | **NO** |
| Destructive-operation confirmations (§23.4) | **NO** |
| Path validation (§22.1) | **NO** |
| Command-execution denylist/structural checks (§23.0, §23.1) | **NO** |
| Catalog schema/malformed-record validation (§18) | **NO** |
| Manifest/checksum verification (`install.sh --verify`, §30.2, §30.5, update verification §30.6) | **NO** |
| `systemd_flag` acknowledgement gate (§35.3) | **NO** |

`--no-checks` is a startup-diagnostics convenience flag only; it has no effect on any security, integrity, compatibility, or destructive-confirmation boundary in the launcher.

---

# 16. Configuration Locations & Runtime Directories

Termux/Android: `~/.config/devils-minios/`. Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/devils-minios/`. No native Linux path is supported (§8). The launcher never depends on ephemeral Termux locations (`$PREFIX/tmp`, `$PREFIX/var/run`) for persistent state.

```text
~/.config/devils-minios/
├── config                  # user configuration file (key=value, §17)
├── state                   # persistent launcher state (§26.4) — canonical path, mode 0600
├── state.bak                # last-known-good state backup (§26.4)
├── logs/                   # launcher.log + rotated files (§24)
├── pids/
├── crashes/
├── tmp/
├── templates/
├── banners/
└── .crash-flag             # normalized crash marker (§26.5)
~/.cache/devils-minios/
├── health_cache.json       # diagnostic cache (§25.3)
└── banner_draw_count       # per-launch animation counter (§35)
```

The `plugins/` directory **must not be created** in v1.0.0. `terminal_width` and the rest of `runtime_context` (§17.4) never appear in any file on disk.

---

# 17. Configuration Schema

**15 logical keys total (D4), split into three ownership categories.** This split resolves the ambiguity between persisted configuration and ephemeral runtime facts.

## 17.1 `persisted_config` — 11 user-owned keys (written to `~/.config/devils-minios/config`)

```text
config_version  theme  banner  banner_animation  auto_launch
health_check_interval  log_level  check_updates  language
network_timeout  network_retries
```

## 17.2 `persisted_runtime_facts` — 3 informational keys (written to `~/.config/devils-minios/config`, refreshed every launch, never user-editable, never importable)

```text
termux_source  android_version  architecture
```

These are written to the config file purely so `system_info.sh` and support diagnostics can read the last-detected values without a fresh detection pass; `validate_config()` overwrites them with freshly detected values on every launch before any read of stale data can occur.

## 17.3 `runtime_context` — 1 in-memory-only key, never persisted (P1-02, P1-03)

```text
terminal_width
```

`terminal_width` is detected once per launch by `build_runtime_context()` and held only in memory for the lifetime of the process. It is **never written to the `config` file, never included in exports, and never read from disk.** This removes the possibility of stale terminal-width data influencing UI mode across launches (resolves the ambiguity in the prior revision, where terminal width was simultaneously described as runtime-owned and persisted).

## 17.4 Rules (D4, D12)

- `config_version` is mandatory and must equal `1` — a config schema version independent of product SemVer; `--update` runs migration when the stored value differs (§32).
- **Config grammar is strict `key=value` (D12):** one key per line, `#` comment lines ignored, no inline comments, no quoting requirements beyond value, and **duplicate keys, unknown keys, and malformed lines are rejected** by the central `validate_config()` in `core.sh`. No module may parse or write configuration directly.
- All writes are atomic (temp file + `mv` under the §23.4 mutex rules); a failed write never corrupts the active configuration.
- Unknown keys are rejected; a mismatched `config_version` is rejected.
- `language` is reserved for future i18n, locked to `en`; `validate_config()` rejects any other value.
- `show_experimental_desktops` **must never exist** as a key.
- `persisted_runtime_facts` are refreshed at every launch; user edits to them in the config file are ignored and overwritten on the next `save_config()`.
- `runtime_context` (`terminal_width`) is never present in the `config` file; `validate_config()` rejects the key outright if it is ever found there (treated as an unknown-key violation, D12), which also guards against a hand-edited or corrupted file reintroducing it.

## 17.5 Default Configuration File Contents

```text
config_version=1
theme=dracula
banner=devil
banner_animation=false
auto_launch=false
health_check_interval=1800
log_level=INFO
check_updates=false
language=en
network_timeout=30
network_retries=3
termux_source=<detected at launch>
android_version=<detected at launch>
architecture=<detected at launch>
```

Note `terminal_width` does not appear — it lives only in `runtime_context` (§17.3).

## 17.6 Key Consumers (exactly one consumer per key)

| Key | Consumer |
|---|---|
| `config_version` | `validate_config()`; `--update` migration trigger (§30.6, §32) |
| `theme` | `customize.sh` via `core.sh::apply_theme()` |
| `banner` | `customize.sh` via `core.sh::set_banner()` |
| `banner_animation` | `core.sh::show_banner()` (cache draw counter, §34) |
| `auto_launch` | `devils-minios.sh` post-onboarding dispatcher (§27.5) |
| `health_check_interval` | `health_check.sh` cache staleness threshold (§25.3) |
| `log_level` | `core.sh::write_log_file()` (§24) |
| `check_updates` | Startup update check (skipped with `--no-checks` or `--offline`) |
| `language` | `validate_config()` only (reserved) |
| `network_timeout` / `network_retries` | Network operations (§29) |
| `termux_source` | Play Store warning logic — cross-check against fresh detection (§35.2) |
| `android_version` | Compatibility-matrix checks (§10) |
| `architecture` | Architecture filtering (§18.2); info display |
| `terminal_width` (`runtime_context`) | UI mode selection (§19.2); in-memory only, rebuilt every launch |

## 17.7 Configuration Import (strict, atomic)

Configuration import is strict and atomic. The imported document must contain the 11 `persisted_config` keys required by the schema, with **no unknown keys, no duplicate keys, and no invalid values** (D12). `persisted_runtime_facts` and `runtime_context` keys **cannot be imported as overrides** — if present in an import document, the import is rejected as containing unknown/forbidden keys. The complete import is validated **before** replacement; if validation fails, the existing configuration remains untouched and the user receives a clear error with an error code. A successful import replaces the active `persisted_config` atomically.

---

# 18. Data Schemas

All four databases are **pipe-delimited**, one record per line; `#` starts a comment line (ignored). Field count is validated at load. **Malformed-record rule (applies to every data file):** a line that is not a comment and does not contain exactly the specified number of non-empty fields is rejected with a WARN log naming the file and line number, and is skipped; if **>5%** of records in a file are malformed, the module treating that file enters **safe degradation** (empty catalog + explicit error message) rather than partial silent behavior. The "Malformed database record" edge test (§43.3) injects one malformed line and asserts: WARN logged, bad line skipped, good lines loaded.

**Read-only catalogs:** all `data/*.db` files are immutable static catalogs during normal operation. Runtime/user state is stored separately (§16, §26.4) and is never written into catalog files.

**Structural security rule (P0-02, P0-03, P0-04):** no field in any catalog file may ever contain a free-form shell command string. Every field that drives program execution is either (a) a narrowly validated identifier consumed by a fixed, centralized code path, or (b) absent — because the mechanism it used to parameterize has been made a fixed constant in code instead. This rule is enforced by schema validation at load time and is a release gate (§47.1).

## 18.1 `data/proot_distros.db` — 7 fields (D5)

| # | Field | Type | Required | Notes |
|---|---|---|---|---|
| 1 | `id` | string, `[a-z0-9-]+` unique | yes | stable launcher distro ID |
| 2 | `name` | string | yes | display name |
| 3 | `proot_id` | string | yes | exact official `proot-distro` identifier |
| 4 | `architectures` | `all` or comma list | yes | canonical `aarch64`, `x86_64`; `all` = both |
| 5 | `priority` | positive integer | yes | lower value = higher selection priority |
| 6 | `status` | enum | yes | `supported` or `disabled` |
| 7 | `package_manager` | enum: `apt`, `pacman`, `dnf`, `apk`, `xbps` | yes | selects the fixed, hardcoded install-command shape used by `install_proot_package()` (§18.2, §23.1); never itself a command string |

The catalog is the **complete** officially supported v1.0.0 distro set (D5). Runtime discovery from `proot-distro` determines which cataloged distros are installed/available. Uncataloged distros are not officially supported. Schema column header: `id | name | proot_id | architectures | priority | status | package_manager` (D5, amended by P0-02 to add `package_manager` in place of the removed free-form command model — see §18.2).

## 18.2 `data/proot_apps.db` — 7 fields (remediated per P0-02)

| # | Field | Type | Required | Notes |
|---|---|---|---|---|
| 1 | `id` | string, `[a-z0-9-]+` unique | yes | stable key |
| 2 | `name` | string | yes | display name |
| 3 | `category` | enum (13 values §5: `dev-proot, browser, office, graphics, media, communication, security, networking, games, system, education, science, utilities`) | yes | |
| 4 | `description` | string, no pipe chars | yes | ≤120 chars |
| 5 | `install_target` | string, `^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$` | yes | the package identifier to install; **contains no command syntax of any kind** — no shell operators are even expressible under this regex |
| 6 | `architectures` | `all` or comma list | yes | canonical set; `all` = `aarch64 x86_64` |
| 7 | `proot_distros` | `any` or comma list | yes | `any` = all currently discovered official `proot-distro` environments |

**P0-02 resolution.** The prior revision's `install_cmd_template` field (e.g. `proot-distro login {distro} -- pkg install {pkg}`) is **removed entirely**. It is replaced by `install_target`, a bare package identifier validated by the regex above — a string that cannot syntactically contain `;`, `&&`, `||`, `|`, `&`, `` ` ``, `$(`, `)`, `>`, `>>`, `<`, or whitespace. The actual install command is never assembled from catalog data. It is built exclusively by `core.sh::install_proot_package(distro_id, install_target)`, which:

1. Looks up `distro_id` in `data/proot_distros.db` and reads its `package_manager` field.
2. Selects one of exactly five **hardcoded** argument-array templates keyed by `package_manager` (`apt install -y <target>`, `pacman -S --noconfirm <target>`, `dnf install -y <target>`, `apk add <target>`, `xbps-install -y <target>`) — these five templates are code constants, never read from any data file.
3. Invokes `execute_structured()` (§23.1) with `executor=proot-distro`, `action=login`, `distro=<distro_id>`, `inner_argv=<the selected argv array with <target> substituted as a single argv element, never string-concatenated>`.

No `eval`, `sh -c`, or `bash -c` is used at any point. Exactly **40 entries**; all 13 categories represented; every record has exactly 7 non-empty fields. Architecture filtering is **total**: the sentinel `all` expands to both canonical architectures. Incompatible apps are hidden by default, discoverable via the module toggle (§13.5), and always display their architecture.

## 18.3 `data/termux_apps.db` — 11 fields (remediated per P0-04)

| # | Field | Type | Required | Notes |
|---|---|---|---|---|
| 1 | `id` | string, unique | yes | |
| 2 | `name` | string | yes | display name |
| 3 | `category` | enum (8 values §13.4: `development, browsers, desktop, cli, system, security, media, networking`) | yes | |
| 4 | `description` | string, ≤120 chars, no pipes | yes | |
| 5 | `package_name` | string, `^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$` or `-` | required when `install_source=pkg`, else `-` | Termux package name passed only as a validated `pkg install -y <package_name>` argv element |
| 6 | `install_source` | enum: `pkg`, `github` | yes | **`script` is removed for v1.0.0 (P0-04)** |
| 7 | `post_install_note` | string, may be empty (`-`) | yes | shown after install |
| 8 | `github_repository` | `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$` or `-` | required when `install_source=github`, else `-` | `owner/repo` on `github.com` only — no other host is ever contacted |
| 9 | `github_ref` | string matching a pinned tag/ref pattern (`^v?[0-9]+\.[0-9]+\.[0-9]+$` or a 40-char commit SHA) or `-` | required when `install_source=github`, else `-` | never a floating branch name (e.g. never `main`, `master`, `latest`) |
| 10 | `github_artifact` | exact release-asset filename or `-` | required when `install_source=github`, else `-` | the single file downloaded from the pinned release |
| 11 | `github_sha256` | 64-char lowercase hex or `-` | required when `install_source=github`, else `-` | mandatory pinned checksum of `github_artifact` |

Target: **30–40 entries**.

**P0-04 resolution.** `script` is removed as an `install_source` value for v1.0.0; no catalog record may cause a downloaded script to be executed. `pkg` installs are dispatched by `termux_apps.sh` calling `pkg install -y <package_name>` through `execute_structured()` (§23.1) — `package_name` is never concatenated into a larger string. `github` installs are dispatched exclusively through `core.sh::install_github_artifact(github_repository, github_ref, github_artifact, github_sha256)` (§23.3), which downloads the one pinned, checksum-verified asset from `https://github.com/<github_repository>/releases/download/<github_ref>/<github_artifact>` over HTTPS, verifies its SHA-256 against `github_sha256` before any further action, and then either (a) places a verified single binary into a launcher-owned bin directory with no execution during installation, or (b) extracts a verified archive into a launcher-owned app directory with no execution during installation. **No downloaded artifact is ever executed as part of installation itself** — installation only stages the verified file; execution happens later, only when the user explicitly launches the installed app through the normal Termux app invocation path, exactly like a `pkg`-installed binary. Network or checksum failure aborts the install with a clear error and no partial state (§29, §30.5).

## 18.4 `data/desktops.db` — 7 fields (remediated per P0-03)

| # | Field | Type | Required | Notes |
|---|---|---|---|---|
| 1 | `name` | string, unique | yes | e.g. `xfce4` |
| 2 | `description` | string | yes | |
| 3 | `packages` | comma list | yes | installed via the distro package manager (§18.1) |
| 4 | `startup_binary` | enum, allowlisted per-desktop launcher binary (see below) | yes | passed to `generate_xstartup()` (§13.2) as an argv element, never interpolated into a shell string |
| 5 | `startup_args` | comma list of literal tokens matching `^[A-Za-z0-9_.=-]{0,32}$` each, may be empty (`-`) | yes | each token becomes one argv element; no token may contain a shell metacharacter |
| 6 | `systemd_flag` | bool `true`/`false` | yes | `true` → blocking warning (§35.3) |
| 7 | `min_ram_mb` | integer | yes | advisory pre-install check |

Exactly **8 curated Tier-1 desktops** (D2): `xfce4, lxqt, lxde, mate, i3wm, openbox, fluxbox, jwm`. There is exactly one tier in v1.0.0; no `tier` field exists. **No experimental/unsupported desktops exist in v1.0.0.**

**Allowlisted `startup_binary` values (fixed set, one per desktop, defined here and nowhere else):**
```text
xfce4      → startxfce4
lxqt       → startlxqt
lxde       → startlxde
mate       → mate-session
i3wm       → i3
openbox    → openbox-session
fluxbox    → startfluxbox
jwm        → jwm
```

**P0-03 resolution.** The prior revision's free-form `startup_cmd` string field is **removed**. `startup_binary` must be one of the eight fixed values above (schema validation rejects any other value — this makes it impossible for a compromised or malformed catalog record to name an arbitrary executable). `startup_args` may only contain literal, whitespace-free tokens matching the given regex; no `;`, `&&`, `||`, `|`, `&`, `` ` ``, `$(`, `)`, `>`, `>>`, `<`, `$`, or quote character is expressible. `core.sh::generate_xstartup()` and `run_desktop_startup()` write and invoke `startup_binary` and each `startup_args` token as separate argv elements — never as a concatenated shell string, never through `eval`. A malformed `startup_binary` value causes the record to be rejected at load time as a malformed record (§18, >5% rule) rather than reaching execution.

Schemas are documented here and in `docs/DATA.md`; modules must not assume undeclared fields.

---

# 19. UI/UX

## 19.1 Terminal Modes

| Mode | Width | Features |
|---|---|---|
| Full | ≥60 | Banner, box drawing, full labels, emoji where appropriate |
| Compact | 40–59 | No box drawing, full names, plain separators, no emoji dependency |
| Minimal | <40 | No banner, text only, short labels, single-word menu identifiers |

Minimal mode is **mandatory and testable**; §43.3 includes the <40-width test.

## 19.2 Width Detection

`terminal_width` (part of `runtime_context`, §17.3) is detected at every launch (`COLUMNS`, falling back to `tput cols`, falling back to 80). It exists only in memory for that process and selects the UI mode for that launch. It is **never persisted** — there is no "stale cached value" scenario because there is no cache (resolves P1-02).

## 19.3 Input Handling

All interactive input: quoted, validated, range-checked where numeric, path-validated where filesystem-related. Correct quoting and validation are the primary security mechanisms (§23).

---

# 20. Performance Requirements

**P1-01 resolution: a single, unambiguous metric is used for memory.**

| Target | Value | Measurement methodology |
|---|---|---|
| Cold startup (menu visible) | < 2s | Wall time from process start to first menu render, measured on the reference device class; median of 5 cold launches |
| Memory footprint | < 15MB | **Peak resident set size from process start through standard menu render.** Measured by reading the `VmHWM` field (kernel-tracked "high water mark", i.e. the peak RSS observed at any point since process start) from `/proc/self/status` **once**, immediately after the first menu render. Because `VmHWM` is monotonically non-decreasing and kernel-maintained, a single read at that point is definitionally the peak-from-start value — there is no separate "peak during launch" vs "RSS after render" ambiguity to resolve. |
| Log write latency | < 50ms per entry | Timestamp delta around `write_log_file()` for a 1 KB entry; median of 20 writes |
| Health check execution | < 5s total | Wall time for a full fresh (non-cached) `health_check.sh` run |

**Reference device class ("mid-range Android"):** Snapdragon 695-class SoC (or equivalent MediaTek Dimensity 900-class), 4–6 GB RAM, Android 12–14, Termux storage on internal flash. Performance targets are verified on this class or better.

**Standardized measurement conditions (S6 P2-3 resolution) — normative for every figure in the table above:**

| Condition | Requirement |
|---|---|
| Thermal state | Device at ambient/idle thermal state before the first sample; no sustained CPU load in the 5 minutes preceding measurement; a device reporting a thermal-throttling state (where the platform exposes one) is excluded from the sample and re-measured after cooldown |
| Battery state | ≥21% battery (matching the §25.1 "continue normally" band) and not actively charging at high wattage during measurement, to avoid charge-controller-induced CPU/IO variance |
| Network state | Airplane mode / Wi-Fi and mobile data both disabled for cold/warm startup and memory measurements (these paths must not depend on network); network state is irrelevant to log-write-latency and is left at whatever state the device is normally in for health-check timing, since health checks may include an optional, timeout-bounded connectivity probe |
| Storage state | Internal flash storage only (not external SD); ≥20% free space on the filesystem backing `$HOME`, so the measurement is not itself confounded by the storage-pressure conditions §25.1 is designed to detect |
| Cold launch definition | Termux process freshly started (no warm page cache from a prior launcher run in the preceding 60 seconds); this is the default condition for the "Cold startup" and "Memory footprint" targets |
| Warm launch definition | A second launcher invocation within 60 seconds of a prior one on the same device/session, used only for informational comparison — v1.0.0 sets no separate pass/fail target for warm launch, since the normative targets are defined against cold launch |
| Warm-up procedure | One untimed cold launch is performed and discarded immediately before the timed sample sequence begins, to avoid counting one-time filesystem/APK-verification overhead that would not recur in normal use |
| Sample count | Cold startup: 5 cold launches (matches §20's stated median-of-5). Log write latency: 20 writes (matches §20's stated median-of-20). Memory footprint: 5 cold launches, one `VmHWM` read per launch. Health check: 5 fresh (non-cached) runs |
| Statistical measurement | Median of the sample set is the reported and gated figure for every metric above; the full sample set (not just the median) is retained in the performance test's output for variance inspection |
| Acceptable variance | The sample's interquartile range (IQR) must not exceed 25% of the median for the sample to be considered valid; a sample exceeding this is discarded and re-measured once under the same conditions rather than averaged in, since high variance indicates the measurement conditions above were not actually met |

---

# 21. Release Lifecycle & Versioning

**SemVer 2.0.0 is the only version scheme.** The version string `v1.0.0` is the single source of truth across all artifacts.

- `MAJOR`: breaking config or module API changes
- `MINOR`: new desktops, apps, features
- `PATCH`: bug or security fixes
- Release branches: `release/vX.Y.Z` cut from `main`; hotfixes cherry-picked to the active release branch.
- Support window: current `major.minor` supported until the next minor + 90 days; critical security patches backported 1 previous minor.
- Deprecation: feature removal requires 1 minor version of deprecation warning in launcher UI and log.
- **Build metadata:** an optional build stamp may be appended per SemVer §10 as `v1.0.0+YYYY.MM.DD` (date of build). It appears in `--version` verbose output and logs. It is **never** used as a GitHub release tag; release tags are always `vX.Y.Z` (§33.3).

---

# 22. Path Security & External Storage

User-provided paths must: reject empty paths; reject traversal (`..`); resolve safely; verify allowed base directories; prevent access outside the intended scope. Protected areas: workspace paths, file-manager paths, backup/restore paths, installation paths (`core.sh::validate_path()` is the single validator; §13.1).

## 22.1 Deterministic Path Validation Algorithm (S6 P0-2 resolution)

`core.sh::validate_path(input_path, operation, allowed_root)` is the **only** function permitted to approve a path for a filesystem-mutating or filesystem-reading operation outside a pre-validated data file. It runs the following fixed sequence, in order, and returns a specific rejection code the first time a step fails — it never proceeds past a failed step, and no caller may skip a step:

```text
1. Lexical validation
2. Traversal / invalid-form rejection
3. Resolve the existing parent chain
4. Verify the resolved parent is inside operation's allowed_root
5. Validate the final path component
6. Apply operation-specific symlink policy
7. Security-sensitive revalidation (immediately before mutation)
8. Perform the operation
```

**Step detail, normative for every call site:**

1. **Lexical validation.** Reject the empty string, a path containing a NUL byte, and a path exceeding the platform's `PATH_MAX`. Normalize `.` segments away lexically (without touching the filesystem) but do **not** collapse `..` lexically — `..` is handled structurally in step 2, never string-replaced, so a crafted value like `a/../../etc` cannot slip past a naive lexical collapse.
2. **Traversal / invalid-form rejection.** After lexical normalization, reject the path outright if any remaining segment is literally `..`. This applies identically to relative and absolute input paths — an absolute path is not exempt, because `allowed_root` containment (step 4) is verified on the *resolved* path, not on the literal string.
3. **Resolve the existing parent chain.** Walk the path from its root downward, resolving each existing segment (including symlinks encountered along the way) via the platform's real-path resolution, **up to and including the last segment that actually exists on disk.** For an existing path, this is the whole path. For a path whose final component does not yet exist (e.g. creating `newfile`, or a not-yet-created rename destination), this resolves every segment up to and including the last *existing* parent directory, and stops there — the nonexistent final component is not resolved (there is nothing to resolve) and is instead handled lexically in step 5. If any segment in the existing chain does not exist, is not traversable (permission denied), or is a broken symlink encountered mid-path, reject.
4. **Verify the resolved parent is inside `allowed_root`.** Compare the fully resolved existing-parent path (step 3) against the operation's `allowed_root` (e.g. `$HOME/devils-minios/workspaces/` for workspace operations, the installer's own tracked temp root for installer operations, §36, §22). Reject if the resolved parent is not `allowed_root` itself or a descendant of it. This is evaluated on the **resolved** path so that a symlink inside `allowed_root` cannot be used to point the effective location outside it.
5. **Validate the final path component.** For an existing final component, its already-resolved location (from step 3/4) is what is validated. For a nonexistent final component (new-file creation, rename/move destination, new-directory creation), validate it lexically: it must not be `.` or `..`, must not contain a path separator itself (it is a single segment relative to its validated parent), and must not itself be a symlink target string that attempts to escape `allowed_root` (this is a pure string check against the not-yet-created name; there is no filesystem object to resolve).
6. **Apply operation-specific symlink policy.**
   - *Read/browse/copy (File Manager, §13.3):* an existing symlink whose resolved target is confirmed (step 3–4) to sit inside `allowed_root` (or, for File Manager external-storage reads, is an explicitly confirmed external-storage target, §22 External Storage) may be followed. A symlink resolving outside every allowed root for the operation is rejected.
   - *Symlink creation:* the new symlink's parent must pass steps 3–4; the symlink's **target string** is not itself required to resolve inside `allowed_root` at creation time (the target may not exist yet), but the symlink is recorded as a File-Manager-owned object subject to the same execution-block rule as any other path under external storage (§22 External Storage) — a symlink is never used to bypass the execution block.
   - *Rename/move:* both the source (existing path, full step 1–4 validation) and the destination (parent must exist and pass steps 3–4; final component validated per step 5 whether or not it already exists) must independently pass validation before the rename is attempted. A destination that already exists is only overwritten if the operation is explicitly a confirmed overwrite (§23.4 destructive-operation confirmation).
   - *Recursive deletion:* every path is resolved once, in full (step 3, treating the deletion target itself as the "final" existing component), and validated against `allowed_root` **before** recursion begins. The recursive walk itself does not re-resolve symlinks encountered inside the tree into new deletion targets outside `allowed_root` — deletion never follows a symlink out of the tree being deleted; a symlink encountered during the walk is deleted as the symlink object itself, never dereferenced for a "delete what it points to" action.
   - *Directory creation:* parent-chain rule (steps 3–4) applies to the deepest existing ancestor; every nonexistent intermediate segment between that ancestor and the target is created only after the full chain validates, and each created segment is a literal, non-symlink directory.
7. **Security-sensitive revalidation.** For operations classified as security-sensitive (installer activation/deletion §30.1, state/config atomic-write target §17.4/§26.4, workspace execution-path resolution §13.7, and any recursive deletion) the path is revalidated (steps 1–6 repeated) **immediately before** the mutating syscall, using a freshly re-resolved parent chain rather than a cached result from earlier in the operation. This closes the window for a race between validation and use (TOCTOU): validating once at the start of a long-running operation is insufficient for these classes; the second, immediate-before-mutation check is mandatory.
8. **Perform the operation.** Only after every applicable step above has passed does the caller invoke the actual filesystem mutation, and it does so using the resolved absolute path produced by step 3/4 rather than the original unresolved user input, so that no re-interpretation of the original string can occur between validation and use.

**Explicit case coverage (S6 P0-2):**

| Case | Handling |
|---|---|
| Existing path | Steps 1–4 resolve and validate the whole path; step 5 validates the already-resolved final component |
| Nonexistent final component | Steps 3–4 resolve/validate up to the last existing parent; step 5 validates the new component lexically |
| Nonexistent parent directories | Rejected at step 3 unless the operation is directory creation, in which case step 6's "directory creation" rule creates the missing chain only after step 4 validates the deepest existing ancestor |
| Relative paths | Resolved against the operation's defined base (never the process's arbitrary current working directory) before step 1 begins |
| Absolute paths | Not exempt from any step; `allowed_root` containment is still enforced on the resolved form |
| `.` / `..` | `.` is normalized away lexically (step 1); `..` is never lexically collapsed and is rejected structurally (step 2) |
| Symlinks (existing) | Resolved and validated per step 6's read/browse sub-rule |
| Broken symlinks | Rejected at step 3 (an unresolvable segment) unless the operation is specifically "delete this symlink object," which targets the symlink itself, not its target |
| Symlink creation | Step 6's symlink-creation sub-rule |
| Rename/move | Step 6's rename/move sub-rule; both endpoints validated independently |
| Recursive deletion | Step 6's recursive-deletion sub-rule; resolved once before recursion, never re-escapes via an internal symlink |
| Directory creation | Step 6's directory-creation sub-rule |
| Parent-chain validation | Step 3/4, applied uniformly regardless of operation |
| Operation-specific roots | Every call site passes its own `allowed_root` explicitly; there is no global default root |
| Race-sensitive mutations | Step 7 mandatory revalidation immediately before the mutating syscall |

No shortcut (string-based `..` stripping in place of structural rejection, resolving only the final component without its parent chain, or trusting a cached validation result across a race window) satisfies this contract. `test_security.sh` (§43.1) is extended to assert each row of the case table above independently.

**External storage:** detect external-storage locations including `/sdcard`, `/storage/*`, and `/storage/emulated/*`.

- **File Manager access:** browsing, searching, reading, copying, and transferring files to/from external storage are allowed only after explicit confirmation that identifies the external-storage operation.
- **Execution:** executing launcher code, scripts, binaries, or installed workflows from external storage is **always blocked**.
- **Workspace execution:** external storage is never an allowed execution workspace (D3).
- Android external-storage `noexec` limitations are explained when a user attempts an execution-related operation.
- Security tests must distinguish allowed file access from blocked execution; "external-storage block" means **execution** block, not file-access denial.

---

# 23. Command Safety & Logging Atomicity

## 23.0 Authoritative Command Execution Contract (S6 P0-1 resolution)

Every `executor` value accepted by `execute_structured()` (§23.1) is defined completely below. This table is the **entire** allowlist; a fixed enum in `core.sh` may contain no `executor` value absent from this table, and no code path may invoke a subprocess by any means other than `execute_structured()` (enforced by the CI grep scan, §43.4). Undefined shell-string construction — building any part of a command as a single interpolated string rather than a discrete `args[]` array element — is prohibited for every row in this table without exception.

| Field | Definition applied to every row |
|---|---|
| Command ID | The `executor` enum value itself (first column below) |
| Argument types | Every `args[]` element is a plain string passed as one argv element; no element may itself contain a path separator meant to expand, a glob, or a shell metacharacter (denylist check, §23.1) |
| Argument validators | Named per row; each validator is a function in `core.sh` invoked before dispatch, never a downstream shell-side check |
| Placeholder/template policy | None. There is no template-substitution model in v1.0.0 (§23.1); every value reaching `args[]` is either a fixed code constant or a value that has already passed its named validator |
| Shell grammar policy | **Prohibited for all rows.** No row's `args[]` is ever passed to `sh -c`/`bash -c`/`eval`; every invocation uses `execve()`-style array dispatch |

| Executor | Allowed subcommands (`action`) | Argument schema / validator | Env-var policy | Working-directory policy | stdin policy | stdout/stderr | Timeout | Exit-code mapping | Interactive? | Network? | Privilege? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `proot-distro` | `login`, `install`, `list --json`, `remove`, `backup`, `restore` | `action` from this fixed set only; distro identifier validated as `[a-z0-9-]+` against `proot_distros.db` (§18.1); inner `login` argv validated per §23.2 | Launcher passes through the current sanitized environment plus `PROOT_TMP_DIR` pinned to the launcher's own tmp dir; no user- or catalog-supplied environment variable is ever injected | Launcher's own working directory at invocation time (never a catalog- or user-supplied directory) | `/dev/null` for `install`/`remove`/`backup`/`restore`; inherited only for interactive `login` sessions the user explicitly started | Captured to the launcher log for non-interactive subcommands; inherited (streamed to the terminal) for interactive `login` | 600s for `install`/`backup`/`restore`; 30s for `list --json`; none for interactive `login` (user-driven session, terminated by user exit or SIGINT handling, §28) | `0` success mapped through; non-zero mapped to the calling module's `E2xx` code (§48) | `login` only (an explicit, user-initiated proot shell/desktop session); all other subcommands non-interactive | Only `install`/`restore` when fetching a distro image; all others offline-capable | None — proot itself is unprivileged; the launcher never elevates |
| `pkg` | `install -y`, `list-installed` | `action` from this fixed set only; package name validated by `^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$` (§18.3) | Passthrough sanitized environment only | Launcher's own working directory | `/dev/null` | Captured to the launcher log; summarized to the user | 180s for `install -y`; 30s for `list-installed` | `0` success; non-zero mapped to `E3xx` (§48) | Never | `install -y` requires network; `list-installed` is offline | None |
| `git` | `clone --branch <tag> --depth 1`, `fetch --tags`, `rev-parse` | `action` from this fixed set only; repository URL restricted to the hardcoded `OFFICIAL_REPOSITORY_URL` (§30.4) for update flows, or the installer's own inspected source for install flows; ref validated as pinned tag/SHA (§18.3, §30.4) | Passthrough sanitized environment; `GIT_TERMINAL_PROMPT=0` forced to prevent an interactive credential prompt from ever appearing | The installer/updater's own controlled temp root (§30.1) — never a user-supplied directory | `/dev/null` (`GIT_TERMINAL_PROMPT=0` guarantees no prompt is expected) | Captured to the launcher log | 120s | `0` success; non-zero mapped to `E5xx` (network) or `E6xx`/`E7xx` (install/update) per §48 | Never | Yes (`clone`, `fetch`); `rev-parse` is local/offline | None |
| `tar` | `-xzf` (extract only) | `action` from this fixed set only; source archive path pre-validated by §22.1 before this call; destination is always the installer/updater's own staging directory (§30.1) | Passthrough sanitized environment | Installer/updater's own controlled temp root | `/dev/null` | Captured to the launcher log | 120s | `0` success; non-zero mapped to `E6xx`/`E7xx` per §48 | Never | Offline (operates on an already-downloaded local file) | None |
| `sha256sum` | `-c` (check against a manifest), plain invocation (compute) | `action` from this fixed set only; target file path pre-validated by §22.1 | Passthrough sanitized environment | Directory containing the file(s) being checked, resolved via §22.1 | `/dev/null` | Captured to the launcher log; PASS/FAIL per file surfaced to the user (§30.2) | 60s | `0` all match; `1` mismatch mapped to `E404`/`E6xx`/`E7xx` per §48 | Never | Offline | None |
| `curl` | `-fsSL -o <tmp-path> <url>` | `action` fixed to this single flag/output shape; `<url>` is always `https://github.com/...` built only from the hardcoded host constant plus already-validated `repository`/`ref`/`artifact` fields (§23.3); `<tmp-path>` pre-validated by §22.1 | Passthrough sanitized environment; no proxy or credential environment variable is ever forwarded from user config | Installer/updater/app-install controlled temp root (§30.1) | `/dev/null` | Captured to the launcher log; only the resulting HTTP status / transfer error is surfaced to the user | `network_timeout` config value (§17.6), default 30s, times `network_retries` attempts (§17.6, §29) | `0` success; non-zero (including HTTP failure codes surfaced via `-f`) mapped to `E404`/`E5xx` per §48 | Never | Yes (this is the launcher's only outbound download path) | None |

**Prohibitions restated (binding for every row above and for any future row added by PRD revision only, never silently by code):** no arbitrary user-controlled shell string; no raw `eval`; no unsafe `bash -c`; no unsafe `sh -c`; structured argument arrays only; centralized execution only through `execute_structured()`, which remains the launcher's sole security boundary for process spawning (§47.1).

## 23.1 The Single Centralized Structured Executor (P0-02)

**No component of the launcher ever builds a shell command string from catalog or user data.** The sole execution primitive is:

```text
execute_structured(executor, action, args[])
```

- `executor` is one of a fixed enum understood by `core.sh` (`proot-distro`, `pkg`, `git`, `tar`, `sha256sum`, `curl`, and a small number of other fixed system tools — never a user- or catalog-supplied string).
- `action` and every element of `args[]` are passed as **separate argv elements** to the underlying `exec`/subprocess call (Bash arrays, never string interpolation, never `eval`, never `sh -c`, never `bash -c`).
- Before dispatch, every `args[]` element is checked against an explicit denylist of shell metacharacters — `;  &&  ||  |  &  $  \`  $(  )  >  >>  <` — and rejected with `E401` if any is present. This denylist check is a defense-in-depth second layer; the primary control is that arrays passed to `execve()`-style invocation are never shell-interpreted in the first place, so these characters have no special meaning even if present, but rejecting them outright also catches upstream construction bugs before they reach execution.
- `execute_structured()` is the **only** function in the entire codebase permitted to spawn a subprocess derived from catalog or configuration data. `grep`-based CI checks (§43.4) enforce that no other file calls `eval`, uses `sh -c`, uses `bash -c`, or performs unquoted command substitution on untrusted data.

Every application-installation path (§18.2, §18.3) and every desktop-startup path (§18.4) reaches this one function. There is no template-substitution model in v1.0.0.

## 23.2 Desktop Startup Execution Contract (P0-03)

`run_desktop_startup(distro_id, startup_binary, startup_args)` validates `startup_binary` against the fixed allowlist in §18.4, validates each `startup_args` token against its regex, and calls `execute_structured(executor="proot-distro", action="login", args=[distro_id, "--", startup_binary, ...startup_args])`. Failure modes: unknown `startup_binary` → `E402`, invalid arg token → `E403`, distro not installed → `E203`.

## 23.3 GitHub Artifact Installation Contract (P0-04)

`install_github_artifact(repository, ref, artifact, sha256)`:

1. Validates `repository` against `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$` and rejects anything else.
2. Validates `ref` as a pinned SemVer tag or 40-char commit SHA — never a branch name.
3. Builds the download URL as `https://github.com/<repository>/releases/download/<ref>/<artifact>` — the host `github.com` is a **hardcoded constant**, never derived from input.
4. Downloads via `execute_structured(executor="curl", ...)` to a temporary file.
5. Computes SHA-256 via `execute_structured(executor="sha256sum", ...)` and compares, constant-time-safe string comparison, against `sha256`. Mismatch → abort, `E404`, temporary file deleted.
6. Only on match: moves the verified file into a launcher-owned location. Never executes it as part of installation.

## 23.4 General Command Safety & Logging Atomicity

No arbitrary user-controlled command strings reach a shell; no raw `eval`; arrays and quoted arguments only; commands and arguments validated; no shell concatenation of untrusted data; dangerous operations restricted. Dangerous patterns (`rm -rf /`, `mkfs`, `dd if=/dev/zero`, `dd if=/dev/null`, `curl ... | sh`, `wget ... | sh`, dangerous device redirection, uncontrolled chaining) are rejected wherever a command is assembled. Blacklist validation is not the only security boundary — structural avoidance of shell interpretation (§23.1) is the primary one.

**Log-write atomicity:** primary mechanism `flock` on the log file descriptor where available. **Fallback (flock unavailable, e.g. base Termux):** (a) take a mutex via `mkdir "$lockdir"` (atomic; spin with bounded retries), (b) write the entry to `log.tmp.$$`, (c) `mv -f` it into place (atomic rename). Both paths guarantee no interleaved or torn entries.

---

# 24. Logging & Retention

**Normative section — the only place log limits are stated.**

- Format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`
- Levels: `ERROR, WARN, INFO, DEBUG`
- **Primary log maximum: 1 MB**
- **Rotation: 4 rotated files maximum** (`launcher.log.1` … `.4`); worst-case total disk usage ≤ 5 MB
- **Age purge: entries older than 30 days are removed at rotation time** (both from the primary log and from rotated files as they are promoted). Age is determined by parsing each log line's timestamp; entries older than 30 days are removed.
- Order of enforcement at each write: (1) if primary log > 1 MB → rotate (shift `.4`→deleted, `.3`→`.4`, … primary→`.1`) then apply age purge; (2) if no rotation needed but purge is due, apply age purge.
- Retention therefore enforces **both** a count/size ceiling and a 30-day ceiling.
- Writes are atomic (§23.4).

**Ownership:** `core.sh` exclusively implements and executes rotation, clear, and archive (`rotate_and_purge_logs()`). `log_viewer.sh` is read-only; its Clear and Export actions call `core.sh` helpers (§13.9). Single-writer boundary; no dual-writer race is possible.

The Privacy section references this regime without restating numbers.

---

# 25. Resource Awareness

## 25.1 Battery & Storage Gates (P1-04 resolution)

For heavy operations (distro install, desktop install, large backups):

| Battery | Behavior |
|---|---|
| **≤9%** | Block operation; message explains why |
| **10–20% inclusive** | Warn; require explicit confirmation |
| **≥21%** | Continue normally |

**Storage — exact deterministic rule:**

```text
allow iff available_bytes >= required_bytes + safety_margin_bytes
```

- `safety_margin_bytes` is a **fixed constant: 100 MB** (104,857,600 bytes), applied to every heavy operation, leaving headroom for logs/temp files/atomic-write staging during the operation.
- `available_bytes` is read via `df -B1` (or POSIX `statvfs` equivalent) on the filesystem backing `$HOME` immediately before the operation begins.
- `required_bytes` is operation-specific, defined in `core.sh::check_storage_threshold()`:

| Operation | `required_bytes` source |
|---|---|
| Proot distro install | Query `proot-distro` for the compressed rootfs size when available; otherwise a conservative fixed default of **1,073,741,824 bytes (1 GiB)** covering download + extraction headroom |
| Desktop package install | Sum of a per-desktop fixed estimate table (§18.4 desktops carry no explicit size field; the estimate table lives in `core.sh` as a constant, default **314,572,800 bytes (300 MB)** per desktop when a specific figure is not defined) |
| Termux `pkg`/GitHub app install | `apt`/`pkg`'s own reported download+install size when obtainable; otherwise a fixed default of **104,857,600 bytes (100 MB)** |
| Backup (§32.1) | Exact size of the source directory tree via `du -sb`, computed immediately before the backup starts |

If `required_bytes` cannot be determined by any of the above, the operation uses its listed fixed default rather than skipping the check (the check itself is never skipped for "unknown size" — an unknown size is not the same as an unmeasurable filesystem).

## 25.2 Termux:API Absent — Fail-Open Rule

Battery level on Termux is readable only via Termux:API (`termux-battery-status`). **When Termux:API is absent, battery-dependent gates fail open: the operation proceeds and `core.sh::write_log_file()` emits exactly one WARN per launch — `battery level unavailable; proceeding`.** The UI must explicitly mark battery-dependent capability as **Unavailable** wherever that status affects the current operation. Storage checks use available local filesystem information when possible; if the required storage capability itself is unavailable, the affected check is marked unavailable rather than causing a launcher crash. The launcher never hard-blocks solely because an optional component is missing. This behavior is mandatory and appears in the edge-case test list (§43.3).

## 25.3 Health Check Cache

`health_check.sh` caches diagnostic results in `$XDG_CACHE_HOME/devils-minios/health_cache.json` with a timestamp. `health_check_interval` (seconds, default 1800) is the staleness threshold: results younger than the threshold are served from cache with a "cached" notice; older or absent cache triggers a fresh run, which atomically replaces the cache. `--no-checks` and `--offline` do not affect on-demand runs.

---

# 26. Crash Recovery & Crash-Loop Protection

On serious runtime failure:

1. Capture error context and write a crash record atomically to `crashes/`.
2. Create the normalized `~/.config/devils-minios/.crash-flag` (§26.5).
3. Add the crash timestamp to the rolling crash window.
4. Remove timestamps older than 10 minutes from the active counting window.
5. If fewer than 3 serious crashes are present, automatic recovery may run **only when the failure is explicitly allowlisted as recoverable** (D7).
6. At **3 or more serious crashes within 10 minutes**, automatic recovery is disabled and the launcher must enter Safe Mode (D6).
7. Crash-loop protection **cannot be bypassed by any CLI flag** (D13).

A serious crash is an unexpected launcher/module failure that triggers the crash handler and prevents the active operation from completing normally. User cancellation and ordinary handled operation errors are not counted as serious crashes.

Crash records contain: timestamp, error, command/context, current state, platform, and relevant recent log context. They remain available throughout the active crash-detection window.

## 26.1 Automatic Recovery Eligibility (D7, concrete allowlist per S6 P0-3)

This table is the **complete and only** automatic-recovery allowlist. A failure not matching a `Failure ID` row below is, by definition, `UNKNOWN` and follows the `UNKNOWN` row (never auto-recovered). No module may introduce an additional auto-recovery path outside this table.

| Failure ID | Detection condition | Data affected | Automatic recovery action | Post-recovery validation | Auto-recover? | Safe Mode behavior if recovery fails |
|---|---|---|---|---|---|---|
| `MOD-INIT-FAIL` | A module's load/init function returns non-zero or is not found during `core.sh` module loading (§14 step 4) | The failing module only; unrelated modules unaffected (§41.1) | Disable the failing module for the current session; continue loading the remaining modules | Confirm remaining modules loaded and `IDLE` is reachable | YES | Module remains disabled for the session; user notified; no forced Safe Mode solely for one module's init failure |
| `RUNTIME-TEMP-CORRUPT` | An in-memory `runtime_context` or session-scoped temp file (under `~/.config/devils-minios/tmp/`) fails its own consumer's validation | Session-scoped temp/runtime data only; never `config` or `state` | Discard and rebuild the affected temp/runtime value from its authoritative source (re-detect, re-read) | Re-validate the rebuilt value against its consumer's own check | YES | If rebuild also fails, enter `SAFE_MODE` |
| `CFG-MISSING` | `load_config()` finds no `config` file at the canonical path | Configuration | Regenerate `config` from `defaults.conf` (§17.5) | Full `validate_config()` pass | YES | N/A — regeneration always succeeds unless the filesystem itself is unwritable, in which case `SAFE_MODE` |
| `CFG-BAD-VALUE` | `validate_config()` finds a known key with a value failing its type/range/enum check | Configuration | Whole-file restore from `defaults.conf`, merged with freshly detected `persisted_runtime_facts` (§17.2). Key-by-key partial repair is not attempted, because no partial-config backup exists (only `state.bak` exists, for state, §26.4) | Full `validate_config()` pass | YES | If the regenerated config also fails validation (not expected against `defaults.conf`), enter `SAFE_MODE` |
| `CFG-UNKNOWN-KEY` | `validate_config()` finds a key not in the §17 schema, or a `runtime_context` key present in the file (§17.4) | Configuration | Same restore action as `CFG-BAD-VALUE` | Full `validate_config()` pass | YES | Same as `CFG-BAD-VALUE` |
| `STATE-CORRUPT-RECOVERABLE` | `load_state()` finds a grammar violation, unknown key, missing required key, or unrecognized `state_version` with no defined migration, **and** `state.bak` validates | Persistent state | `restore_state_from_backup()` per §26.4 | Full `validate_state()` pass on the restored file | YES | If `state.bak` also fails validation, falls through to `STATE-CORRUPT-UNRECOVERABLE` |
| `STATE-CORRUPT-UNRECOVERABLE` | As above, but `state.bak` is also invalid or absent | Persistent state | Reinitialize `state` to fresh defaults (§26.4) | Full `validate_state()` pass on the fresh defaults (definitionally passes) | YES (this is itself the defined recovery, not a failure to recover) | Not applicable — this path always succeeds and returns the launcher to `FIRST_BOOT` (§26.4, §39); it is not a Safe Mode entry |
| `CFG-TAMPER` | Configuration fails validation in a way consistent with deliberate modification rather than accidental corruption (e.g. the update trust-anchor area of `core.sh`/`devils-minios.sh` itself reports a checksum mismatch against the installed manifest, §30.5, while parsing `config`) — any signal that implicates integrity rather than ordinary malformation | Configuration and/or installation integrity | **None** | — | **NO** | Enter `SAFE_MODE` immediately; Safe Mode Core offers configuration reset (§33.1) as a user-confirmed action, never automatic |
| `INSTALL-HASH` | Manifest checksum verification fails during install/update activation (§30.2, §30.5, §30.6) | Installation/update payload | **None** | — | **NO** | Enter `SAFE_MODE` (fresh install) or execute the defined update rollback (§30.6 step 10) then, if rollback itself fails, enter `SAFE_MODE` |
| `SECURITY-VALIDATION-FAIL` | `execute_structured()` denylist rejection, path-validation rejection (§22.1), or any other security-boundary check fails | Varies by call site; never auto-modified | **None** | — | **NO** | The triggering operation is aborted with the applicable `E4xx` code (§48); `SAFE_MODE` is entered only if the failure recurs to crash-loop threshold (§26) |
| `CRASH-LOOP-THRESHOLD` | 3rd serious crash within the rolling 10-minute window (§26) | N/A (meta-condition over crash history) | **None** | — | **NO** | Enter `SAFE_MODE` unconditionally; not bypassable by any CLI flag (D13) |
| `UNKNOWN` | A failure not matching any `Failure ID` above | Unknown by definition | **None** | — | **NO** | Enter `SAFE_MODE`; the crash record (§26) is preserved with the full available context for user/developer inspection |

Automatic recovery must never claim success unless the recovery operation **and** its required post-validation both succeed; a recovery action that completes its mechanical step but fails post-validation is treated as a failed recovery (§26.2), not a partial success.

## 26.2 Recovery Failure

If an eligible recovery fails, or the failure is not eligible for automatic recovery, transition to `SAFE_MODE` (§39/§40). If rollback/restore validation also fails, remain in Safe Mode and preserve failed-recovery evidence.

## 26.3 Persistent State Schema (D8)

Persistent launcher state is **independent** from user configuration and uses an independent `state_version=1` with an explicit schema:

```text
state_version=1
primary_distro
last_successful_workflow
onboarding_completion
crash_loop_state
```

- `last_successful_workflow` is a typed structure containing the workflow kind and canonical identifiers required to reproduce the workflow; arbitrary shell commands are never stored as workflow state.
- `crash_loop_state` contains the active serious-crash timestamps and automatic-recovery lockout status required by §26.
- Configuration (§17) and state (§26.3) migrate independently (D9).

## 26.4 Persistent State Storage Contract (P0-01 resolution)

**Canonical location:** `~/.config/devils-minios/state` (single file, no alternate location is ever consulted).

**File format:** the same strict `key=value` grammar as `config` (§17.4), one key per line, `#` comments ignored, no inline comments, no duplicate keys. Validated by `validate_state()`, structurally identical in rigor to `validate_config()` but with the field set from §26.3.

**Fields:** exactly the five listed in §26.3 (`state_version`, `primary_distro`, `last_successful_workflow`, `onboarding_completion`, `crash_loop_state`). `last_successful_workflow` and `crash_loop_state` are serialized as single-line, pipe-delimited sub-records within their `value` (never nested `key=value` blocks, to keep the file's grammar a flat, single-pass-parseable format).

**Permissions:** created with mode `0600` (owner read/write only) at first write; the installer never pre-creates it — `core.sh::save_state()` creates it on first legitimate write with the correct mode via `umask`-safe file creation.

**Atomic write procedure:** identical pattern to configuration (§17.4) — write to `state.tmp.$$` in the same directory, `fsync` the temp file, then `mv -f` it over `state` (atomic rename on the same filesystem). Before the rename, the previous valid `state` is copied to `state.bak` (also atomic, same temp+rename pattern) so a last-known-good copy always exists once at least one successful state write has occurred.

**Corruption detection:** on `load_state()`, the file is parsed under the same strict grammar as configuration; any grammar violation, unknown key, missing required key, or a `state_version` the running launcher does not recognize is treated as corruption. `state_version` mismatches follow the migration path (§32) rather than being treated as corruption when a defined N→N+1 migration exists; an undefined version jump **is** treated as corruption.

**Last-known-good / restore behavior:** on detected corruption of `state`, `restore_state_from_backup()` is invoked automatically: `state.bak` is validated (same grammar/schema check); if it validates, it is atomically copied to `state`, a WARN is logged (`state corrupted; restored from last-known-good backup`), and normal startup continues. If `state.bak` is also invalid or absent, the launcher regenerates a fresh default state (`state_version=1`, `primary_distro=` empty, `last_successful_workflow=` empty, `onboarding_completion=false`, `crash_loop_state=` empty), logs a WARN (`state unrecoverable; reinitialized to defaults`), and — because `onboarding_completion` is now `false` — the state machine's `FIRST_BOOT → ONBOARDING` transition (§39) naturally re-runs onboarding rather than requiring a special-cased recovery path.

**Backup behavior:** `state.bak` is updated on every successful `save_state()` call, always reflecting the last state that was itself successfully validated and written (never a stale multi-generation-old copy).

**Migration behavior:** governed by §32 — an explicit N→N+1 path only; a rollback backup is taken (distinct from the routine `state.bak` — this is the §32.1 manifest-based backup) before migration; migration failure restores the pre-migration state and, if that restoration also fails, enters Safe Mode.

**Safe Mode behavior:** Safe Mode always attempts `load_state()` using the same corruption-detection/restore path above before offering any state-dependent recovery action; if state cannot be recovered even via `state.bak`, Safe Mode proceeds using the freshly regenerated default state (never blocks Safe Mode itself from being usable — see §40).

**Acceptance:** a developer implementing this contract makes no location, format, permission, atomicity, corruption, backup, migration, or Safe Mode decision independently — every one is specified above.

## 26.5 Crash Flag Lifecycle (P1-05 resolution)

The crash flag (`~/.config/devils-minios/.crash-flag`) is a small marker file, distinct from both `state`'s `crash_loop_state` field and the crash-record files under `crashes/`. Its complete lifecycle:

1. **Creation:** written atomically (temp+rename) the moment a serious crash is detected (§26 step 2), containing a single line: `created_at=<ISO-8601 timestamp>`.
2. **Reading:** read once, early in startup (§14 step 10), before Safe Mode routing is decided.
3. **Stale detection:** a crash flag whose `created_at` is more than 24 hours in the past, **and** whose timestamp does not fall within the active 10-minute crash-counting window (§26), is treated as **stale** rather than an active trigger: it is deleted with a WARN log (`stale crash flag cleared; created_at=<ts>`), and startup proceeds without forcing Safe Mode on its account alone. This distinguishes "a crash happened once, days ago, and was never explicitly cleared" from "a crash just happened."
4. **Non-stale (active) crash flag:** routes startup into Safe Mode entry (§39, §40) exactly as in the base crash-recovery flow (§26).
5. **Clearing on successful launch:** once the launcher reaches `IDLE` via a normal (non-Safe-Mode) startup with no new crash recorded in this session, the crash flag — if present and already determined non-stale-but-otherwise-benign (e.g. a single isolated crash below the loop threshold that the user has now successfully relaunched past) — is cleared. Concretely: the flag is cleared the first time `IDLE` is reached in a session where `execute_structured()`/module dispatch has not recorded a new crash.
6. **Clearing on successful recovery:** the `RECOVERY → IDLE` transition (§39), once its post-recovery validation passes, clears the crash flag as part of that transition's action.
7. **Clearing in Safe Mode:** a user-invoked Safe Mode "clear crash state" action explicitly deletes the flag after the user confirms the underlying issue is resolved; an automatic Safe Mode repair action that succeeds and passes validation also clears it as part of that success path.
8. **Corruption handling:** if the crash-flag file exists but cannot be parsed (missing/invalid `created_at`), it is treated as an **active, non-stale** trigger (fail closed — an unparseable crash flag is assumed to indicate a real, recent problem) and routes to Safe Mode; Safe Mode's own diagnostics then allow the user to clear it.
9. **Interaction with crash history:** clearing the crash flag never clears the rolling crash-timestamp window used for the 3-in-10-minute threshold (§26), and vice versa — they are independent signals. A user can clear the flag and still hit the crash-loop threshold if crashes continue within the 10-minute window.

## 26.6 Recovery & Observability Evidence Contract (S7 Q28 clarification)

This clarifies an evidence obligation on the recovery/logging architecture already defined above; it does not redesign that architecture. Every recovery-capable code path (§26.1's allowlist, the crash-flag lifecycle §26.5, and Safe Mode §40) must leave sufficient **local** evidence for diagnosis, drawing only on mechanisms already specified elsewhere in this PRD:

| Evidence element | Already-specified source |
|---|---|
| Structured error code | §48 error-code registry — every recovery-relevant failure already carries a code |
| Relevant state transition | §39 — "every crash logs current state + transition attempted" |
| Recovery attempt/result | §26.1's per-`Failure ID` action and post-recovery validation columns |
| Crash/recovery evidence | §26's crash records (`crashes/`), retained through the active crash-detection window |
| Safe Mode evidence | §40/§40.1 Safe Mode diagnostics |
| Sanitized support-safe diagnostic output | `sanitize_log_for_upload()` (§49) |

No new logging subsystem, log field, or retention rule is introduced by this contract; §24's single retention regime and §49's zero-telemetry, local-first privacy model remain unchanged and are not restated here. This contract is a completeness check on existing mechanisms (docs/TRACEABILITY.md, §43.5), not a new architectural layer.

---

# 27. Onboarding & First-Run

## 27.1 Trigger
Onboarding runs when `~/.config/devils-minios/.onboarding-complete` is absent, or when persistent state's `onboarding_completion` is `false` (§26.4) — both signals are kept in sync by the same write. It runs exactly once per installation under normal conditions; `--safe-mode` skips it.

## 27.2 Steps

1. Welcome + product one-liner
2. Termux source check → Play Store warning if applicable (non-blocking but must be acknowledged)
3. Proot limitations summary (`warn_proot_limits()`)
4. Optional: enable update checks (`check_updates=true|false`)
5. Optional: pick theme and banner (defaults offered)
6. Optional: enable `auto_launch` (default off; explicit opt-in)
7. Optional: enable auto-start (default off; §31)
8. Completion summary → create `~/.config/devils-minios/.onboarding-complete` (marker file, content: timestamp) and set state's `onboarding_completion=true`

## 27.3 Skip and Idempotency
Any step may be skipped (defaults applied). Re-running onboarding manually (via settings) re-creates the marker idempotently. If the marker exists, onboarding never auto-runs again — including after `--update`, unless a migration explicitly invalidates it.

## 27.4 Failure
Each accepted onboarding preference is saved atomically immediately. The completion marker and state flag are written **only after the final step succeeds**. If onboarding is interrupted, accepted preferences remain and onboarding resumes from the first incomplete step on the next launch.

## 27.5 `auto_launch` Behavior
When `auto_launch=true` and the launcher is invoked **without arguments**, the launcher skips the interactive main menu and instead executes the user's configured default action — the most recent successfully completed workflow (`last_successful_workflow` from persistent state, §26.3), falling back to the main menu if none exists. With any CLI flag or `--run-module`, `auto_launch` is ignored (§15). Explicit opt-in only; default `false`.

---

# 28. SIGINT Handling

`Ctrl+C` does not immediately terminate the launcher. Prompt: `Are you sure you want to exit? [Y/n]`. `Y/y`/Enter → exit; other input → continue.

---

# 29. Network Behavior

Network operations: check connectivity; respect `network_timeout` and `network_retries`; provide useful errors; no infinite retry loops; support `--offline` (disables/bypasses network-dependent operations rather than attempting them unexpectedly). No telemetry or "calling home" of any kind (§49).

---

# 30. Installation & Lifecycle

`install.sh` installs the launcher from a **user-inspectable source (Git checkout or ZIP archive)** into a **separate runtime installation directory**. The source (Git checkout or extracted ZIP) is temporary for installation and is **automatically deleted after a successful verified install**, bounded by the ownership rule in §30.1.

**Default installation directory:** `$PREFIX/opt/devils-minios` on Termux/Android — the launcher runtime/source installation, never the Git checkout directory.

**Existing installation directory policy:** if `$PREFIX/opt/devils-minios` already exists and is non-empty, the installer must refuse with a clear error unless it is identified as a prior verified Devil's Mini OS Launcher installation. A prior verified installation may be replaced only after its current state/configuration is backed up and the replacement installation passes validation; an unrecognized or unverified non-empty directory is never silently replaced or deleted.

**Installation sequence (Git and ZIP produce the same validated installation):**

1. Verify Bash ≥4.3.
2. Detect Android/Termux platform and Termux source; warn on Play Store.
3. Validate the source: for Git, a Git working tree containing `devils-minios.sh` and the required release files; for ZIP, a verified release archive (checksums verified before extraction when `SHA256SUMS` ships with it). A non-Git/non-ZIP source is rejected.
4. Estimate required storage per §25.1's install-operation table and block clearly insufficient storage before copying.
5. Validate the source manifest/checksums when `SHA256SUMS` is present (§30.5).
6. Create the separate installation directory atomically, **as an installer-owned directory tracked by the exact path the installer itself created** (§30.1), or in a temporary sibling directory that is equally installer-owned.
7. Copy the verified launcher, all **14** module files, data, and required runtime assets into the temporary installation directory.
8. Validate the copied installation **before** activation.
9. Replace/activate the previous installation only after the new installation passes validation; preserve user config/state outside the installation directory.
10. Create symlink `$PREFIX/bin/devils-minios` pointing to the activated installation entry point.
11. Configure optional Termux shell integration idempotently (single marked block, no duplication).
12. Never silently auto-launch.
13. After successful activation and verification, **automatically delete only the installer-owned source paths recorded in step 6** (§30.1). If deletion fails, installation remains valid and the failure is logged.

The installer never executes arbitrary remote scripts and never uses `curl | bash` / `wget | bash`. The user can inspect the source before running `bash install.sh`.

## 30.1 Installer Deletion Ownership Boundary (P1-08 resolution)

The installer may delete **only** paths that meet both conditions:

1. The path was **created by the installer itself, in this run**, via an installer-issued `mkdir`/checkout/extract call whose exact resulting path was captured into a shell variable **at creation time** (e.g. `INSTALL_SOURCE_TMPDIR="$(mktemp -d ...)"` or an explicit `git clone` target the installer itself chose under a controlled temp root such as `${TMPDIR:-/data/data/com.termux/files/usr/tmp}/devils-minios-install-XXXXXXXX/`).
2. The path is deleted **only via the variable captured in (1)** — never via glob expansion, never via a pattern match, never via a user-supplied or environment-supplied path, never via re-deriving "the directory install.sh was run from."

**Explicit prohibitions:**
- The installer must never `rm -rf` a directory it did not itself `mkdir` (or an equivalent creation call) in the current run.
- If the user ran `install.sh` from a directory they cloned themselves (e.g. `~/my-clone/Devils-Mini-OS-Launcher`), that directory is **the user's Git checkout**, not an installer-owned temporary — it is never a deletion candidate under this contract, even if it happens to be the Git source being installed from. Only an installer-managed **copy or clone made into the controlled temp root** is deletable.
- If the user re-runs `install.sh` from inside the currently-active installation directory (`$PREFIX/opt/devils-minios`) — e.g. reinstalling in place — the installer must detect this (by comparing the resolved absolute path of its own source location against the resolved absolute path of the active installation) and refuse to delete or overwrite its own running source mid-execution; it must stage the new copy elsewhere first and only then atomically activate it (per steps 6–9), exactly as any other install.

## 30.2 `install.sh --verify` (Manifest Verification)

See §30.5 for the full integrity/authenticity model. Mechanically: `install.sh --verify` runs `sha256sum -c SHA256SUMS`, covering `install.sh`, `devils-minios.sh`, all **14** module files, and all data files, reporting per-file PASS/FAIL, exiting 0 only if all pass.

## 30.3 Uninstall — `devils-minios --uninstall`

Uninstall removes **launcher installation only**, and is the sole path to the `UNINSTALLED` state (§33.1, §39). It is only invocable from `IDLE` (§15, §39):

1. Require explicit confirmation.
2. Remove the launcher installation directory and launcher symlink.
3. Remove launcher-owned shell RC integration (idempotent cleanup).
4. Preserve `~/.config/devils-minios/` user configuration and state.
5. Preserve launcher cache, logs, workspaces, banners/templates, **and all installed Proot environments**.
6. Preserve user-created data outside the launcher installation directory.

## 30.4 Update Trust Anchor (P0-05 resolution)

```text
OFFICIAL_REPOSITORY_URL=https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher
```

This is a **hardcoded constant compiled into `devils-minios.sh`/`core.sh`**, not a configuration value. There is no configuration key, environment variable, or CLI flag that can change it — the 15-key configuration schema (§17) contains no such key by design, which is itself the enforcement mechanism: a modified local `config` file has no field capable of redirecting `--update`.

- **Allowed protocol:** HTTPS only. Any non-HTTPS URL derived from this constant is a defect, not a configuration option.
- **Tag validation:** release tags matching `^v[0-9]+\.[0-9]+\.[0-9]+$` only (strict SemVer, `vMAJOR.MINOR.PATCH`).
- **Stable-tag rule:** only tags matching the pattern above are candidates; any tag containing a pre-release suffix (`-rc1`, `-beta`, etc.) or build metadata is excluded from automatic `--update` selection.
- **SemVer selection:** the highest valid stable tag strictly newer than the installed version is selected; ties or no-newer-tag exits successfully with no change.
- **Checksum verification:** the selected release's `SHA256SUMS` (fetched from the same `OFFICIAL_REPOSITORY_URL` release) is verified per §30.5 before activation.
- **Rollback:** on any verification or activation failure, the previous installation and configuration/state backup (§32.1) are restored, and a specific error code is returned; see §30.6 step 10.
- **Network failure:** `--update` aborts cleanly with a clear network-error message; the active installation is untouched.
- **Repository-compromise assumption (explicit threat-model statement):** this model protects against (a) network-path tampering (HTTPS), (b) accidental corruption in transit or storage (SHA-256), and (c) a malicious local configuration silently redirecting updates (no config key exists to do so). It does **not** protect against the `OFFICIAL_REPOSITORY_URL` GitHub account itself being compromised and a malicious release being published there with a matching checksum it also controls — that residual risk is accepted for v1.0.0 and is explicitly out of scope, mitigated only by GitHub's own account-security controls and by the fact that `SHA256SUMS` is not itself signed (§30.5). This is stated plainly rather than implied to be covered.

## 30.5 Integrity vs. Authenticity Model (P0-06 resolution)

These are **two different guarantees** and this PRD never conflates them:

```text
SHA-256 (SHA256SUMS)        = integrity / corruption detection only.
                               Proves "the file you have matches the file
                               the checksum was computed from." Does NOT
                               prove who computed that checksum.

Trusted-channel delivery     = the actual authenticity boundary for v1.0.0.
(HTTPS + OFFICIAL_REPOSITORY_URL
 + GitHub account control)
```

**v1.0.0 trusted-release model (minimum, explicit):**

```text
Official repository (hardcoded URL, §30.4)
+ HTTPS transport
+ SHA-256 manifest (SHA256SUMS) for integrity
```

**Not included in v1.0.0 (explicitly out of scope, not silently assumed):** cryptographic signing of releases or of `SHA256SUMS` itself (e.g. GPG-signed tags/releases). Because `SHA256SUMS` travels through the same channel as the code it checksums, it proves *consistency*, not independent *authenticity* — a statement this PRD makes explicitly rather than implying SHA-256 alone constitutes a full supply-chain-authenticity guarantee. This is the same residual-risk boundary described in §30.4's repository-compromise assumption. A future PRD revision may add release signing; until then, the threat model above is the complete and accurate one.

## 30.6 Self-Update — `devils-minios --update`

The active installation is **not itself a Git working tree**. Update uses a temporary Git checkout under the launcher's controlled temporary directory (installer-owned per §30.1's ownership rule, applied identically to the updater). **Release selection policy:** §30.4.

1. Verify the current installation and configuration.
2. Create a state/config backup (manifest per §32.1, which also serves disaster recovery).
3. Fetch the selected release into a temporary Git checkout.
4. Verify the release manifest and required files (§30.5).
5. Stage the new installation beside the active installation.
6. Run migration when `config_version` or `state_version` changes (§32).
7. Validate the staged installation.
8. Atomically switch the launcher symlink/activation to the new installation.
9. Verify post-update launch.
10. On any failure, restore the previous installation and configuration/state backup and return a specific error code.
11. Delete temporary Git and staging directories after success or rollback (installer-owned per §30.1).

No update is considered successful until verification completes.

---

# 31. Termux:Boot Auto-Start

Auto-start, when enabled during onboarding (§27.2) or via Settings, writes a Termux:Boot script that invokes the launcher.

**The boot file must NOT invoke `--safe-mode`**: `--safe-mode` would mask crash-flag handling and crash-loop protection at every boot. A plain invocation bootstraps to the normal startup sequence; crash detection and recovery behave identically to interactive launches. If Termux:Boot is not installed, enabling auto-start shows an explanatory message and takes no action.

**Detection:** auto-start is considered enabled iff that file exists and references `devils-minios`.

**Removal:** `devils-minios --uninstall-auto-start` deletes the file if present, is idempotent (exit 0 when already absent), and logs the action.

---

# 32. Migration

Configuration (§17) and persistent state (§26.4) migrate **independently** (D9). Only explicit version-to-next-version paths are supported.

For each domain:

```text
detect version
→ validate source
→ create required rollback backup
→ run exact N → N+1 migration
→ validate migrated result
→ atomically activate
```

Skip-level migrations are unsupported unless an explicit path is defined. A migration failure restores the previous valid configuration/state. If restoration fails, enter Safe Mode. Migration never silently destroys user data.

## 32.1 Backup Manifest Contract (D10)

Rollback backups contain only launcher-owned recovery data:

```text
launcher files
launcher version metadata
user configuration
persistent launcher state
migration metadata
```

They do **not** duplicate workspaces, Proot user data, user files, normal caches, or temporary files.

Each backup contains a manifest with:

```text
backup_version
created_at
launcher_version
config_version
state_version
hash_algorithm=SHA-256
entries[]
```

Each entry records its relative path and SHA-256 hash. Restore is staged and atomic:

```text
validate manifest
→ verify hashes
→ restore into staging
→ validate restored configuration/state/files
→ atomically activate
```

A failed validation never activates the restore (D10). No user/workspace duplication occurs in backups.

## 32.2 Migration Verification Contract (S7 Q26 clarification)

This adds a verification obligation on the migration model above; it does not redesign §32 or §32.1. For each defined N→N+1 migration path (configuration or state, migrated independently per D9), the following must each be traceable per §43.5:

| Verification dimension | Already-specified basis |
|---|---|
| Schema/version | `config_version` / `state_version` fields (§17.4, §26.3) |
| Source state | Pre-migration configuration/state, validated before migration begins (§32's `validate source` step) |
| Target state | Post-migration configuration/state, validated before activation (§32's `validate migrated result` step) |
| Backward compatibility | Whether the N→N+1 path is skip-level-safe or requires the prior version exactly (§32 — skip-level migrations unsupported unless explicitly defined) |
| Failure behavior | Restoration of the previous valid configuration/state on migration failure (§32) |
| Rollback/recovery | The §32.1 manifest-based rollback backup taken before migration, and Safe Mode entry if restoration itself fails (§32, §26.4) |
| Automated coverage | Test reference where migration can be exercised without a live device (§43.1/§43.3) |
| Manual acceptance | Acceptance item where the migration path is environment-dependent (§45) |
| Release gate | The applicable §47 gate blocking release if the migration path is unverified |

Where a migration path has not yet been exercised against real prior-version data, its evidence status is `NOT VERIFIED` (§43.5) — this contract never substitutes for that evidence, and it never claims a migration path works merely because it is specified here.

---

# 33. Disaster Recovery & Reset Semantics (P1-06 resolution)

Four distinct operations exist. Each has exactly one deterministic state-machine outcome (§39). **This PRD never uses `UNINSTALLED` for anything other than the launcher no longer being installed.**

## 33.1 The Four Operations

| Operation | Scope | Trigger | Precondition | Action | Success state | Failure state |
|---|---|---|---|---|---|---|
| **Configuration reset** | `persisted_config` only (§17.1); `state` untouched | User selects "Reset configuration" in `settings.sh` or Safe Mode | Any state where Safe Mode/Settings is reachable | `save_config()` writes `defaults.conf` atomically over the existing `config` | `IDLE` (from Safe Mode: `SAFE_MODE → IDLE`; from Settings during normal operation: no transition, config takes effect on next read) | If write fails, existing config is untouched (atomic write guarantee, §17.4); no state change |
| **State reset** | `state` only (§26.4); `persisted_config` untouched | User selects "Reset state" in `settings.sh` or Safe Mode | Any state where Safe Mode/Settings is reachable | `save_state()` writes fresh defaults (`state_version=1`, all fields empty/false) atomically over `state` | Same as configuration reset | Same as configuration reset |
| **Nuclear reset** | Both `persisted_config` **and** `state`, via the full directory-level disaster-recovery procedure below | User explicitly confirms "Nuclear reset" in Safe Mode, typically after configuration reset and state reset have both failed to resolve corruption | `SAFE_MODE` only — never offered from `IDLE`/`RECOVERY` | See §33.2 | `RECOVERY → FIRST_BOOT` (onboarding marker is deliberately **not** restored — see §33.2) | If the rename step itself fails (e.g. filesystem error), remain in `SAFE_MODE` with the original corrupted directory untouched |
| **Uninstall** | Launcher installation directory + symlink only (§30.3); explicitly preserves `~/.config/devils-minios/` in full | `devils-minios --uninstall` (CLI only) | `IDLE` only (§15, §39) | §30.3 steps 1–6 | `IDLE → UNINSTALLED` | Confirmation declined → remain `IDLE`, no change |

## 33.2 Nuclear Reset Procedure

If `~/.config/devils-minios/` is corrupted beyond the repair capability of configuration reset and state reset individually (e.g. the directory itself has permission corruption, or multiple files are simultaneously unreadable): rename the entire corrupted directory to a sibling path `~/.config/devils-minios-corrupted-YYYYMMDD-HHMMSS/` (outside the directory being replaced), regenerate defaults at `~/.config/devils-minios/` (fresh `config`, fresh `state`, no `.onboarding-complete` marker), then copy `banners/` and `templates/` back from the renamed directory if they individually validate. Because the onboarding marker and `state.onboarding_completion` are both freshly `false`/absent after this procedure, the state machine's existing `FIRST_BOOT → ONBOARDING` transition handles re-onboarding without any special-cased logic — this is why nuclear reset's destination state is `FIRST_BOOT`, not `IDLE` and not `UNINSTALLED`. Manual recovery command (unchanged as a documented escape hatch, equivalent to clearing the crash flag and forcing Safe Mode): `rm ~/.config/devils-minios/.crash-flag && bash devils-minios.sh --safe-mode`.

---

# 34. Theme & Banner Systems

**Themes:** Termux via `~/.termux/colors.properties` + `termux-reload-settings`; no native Linux shell integration (single platform, §8); no duplicate configuration blocks; theme changes are idempotent.

**Banners:** built-ins `devil, minimal, retro, cyber, simple`. Custom banners in `~/.config/devils-minios/banners/` take precedence.

**Animation:** when `banner_animation=true`, `core.sh::show_banner()` tracks a draw counter in `$XDG_CACHE_HOME/devils-minios/banner_draw_count` (created on first use). The counter **resets to 0 at each launcher launch**; the visual state cycles every fifth draw within that launch (draws 5, 10, 15…). No config write occurs per draw (the visual system is fully specified and optional/non-critical; Safe/Minimal Mode never depends on it).

---

# 35. Platform Detection, Termux Source & Proot Safety

## 35.1 Platform / Termux Source Detection

The launcher identifies the platform and the Termux source (`f-droid`, `github`, `play-store`, or `unknown`).

**Detection mechanism (single, concrete):** read the `TERMUX_APK_RELEASE` environment variable (set by Termux ≥0.118: values `github` / `f-droid` / `playstore`). If unset, infer from `$PREFIX`: if `$PREFIX` matches `/data/data/com.termux/files/usr` → `f-droid|github` (ambiguous, warn once to reinstall from F-Droid/GitHub if issues occur); if it matches `/data/data/com.termux.playstore/files/usr` → `play-store`; otherwise → `unknown`.

## 35.2 Play Store Warning

If `play-store` (or `unknown` with a play-store-like prefix):

- Display a prominent warning on **every launcher invocation**
- Explain compatibility concerns; recommend F-Droid/GitHub
- Continue non-blockingly (warning must be acknowledged during onboarding)

## 35.3 Proot Safety

Before proot operations, `warn_proot_limits()` explains relevant limitations: kernel limitations, systemd limitations, GUI limitations, device access limitations, root limitations.

**`systemd_flag=true` behavior (S6 P1-5 resolution) — exact sequence, no other implementation is conformant:**

```text
systemd_flag=true detected for the selected desktop
    ↓
Installation is paused (no package installation step runs yet)
    ↓
The systemd limitation is explained (kernel/init limitations under proot;
this desktop's session manager or components expect systemd and will not
behave identically)
    ↓
User must explicitly acknowledge the limitation (a distinct confirmation
prompt naming the desktop and the limitation; declining aborts the
installation with no changes made)
    ↓
Acknowledgement records only that the limitation was explained and
accepted — it MUST NOT be interpreted, logged, or displayed anywhere as
"systemd is supported" or "systemd works." No config or state field
named or implying systemd support is ever set to true.
    ↓
Installation may then continue exactly as any other desktop install (§18.4)
```

This is a blocking gate on proceeding past the warning, not a blocking failure of the install itself: the user's explicit acknowledgement is the only way past it, and there is no way to configure it to be skipped (`--no-checks` does not apply — this is a destructive/consequential-operation confirmation, not a diagnostic, per §15.2).

---

# 36. Workspace Security

**Default allowed workspace root: `$HOME/devils-minios/workspaces/` (D3) — a dedicated launcher-owned directory.** External storage is never an execution workspace; user-provided paths are validated against the allowed root (§22) and workspace creation never silently escapes it. Prevent `..` traversal, absolute-path escape, and symlink-based escape where relevant. External storage may be accessed through the File Manager for explicit file operations only (§22).

---

# 37. Governance Model

BDFL with lazy consensus for non-breaking changes. Breaking changes require PR + 7-day comment window. Issue templates: Bug Report, Feature Request, Compatibility Report, Security. PR template: test results, module affected, breaking change Y/N. Project change authority remains BDFL. No AI-specific governance exists in this document; no separate final-authority section exists — authority lives in each domain section.

## 37.1 Conflict-Resolution Priority (S7 Q8/Q13 clarification)

When two normative requirements genuinely conflict and no more specific rule in this PRD already resolves the conflict, the following global priority applies, highest first:

```text
1. Security
2. Reliability / recovery
3. Usability / accessibility
4. Feature completeness
```

**This is a conflict-resolution mechanism only.** It exists to break ties when requirements cannot both be satisfied; it must never be invoked to silently override a more specific normative requirement that already governs the situation (e.g. it does not permit skipping a §15.2 "may never be skipped" check on usability grounds, and it does not permit weakening §23's structural command-safety rules on feature-completeness grounds). Any actual invocation of this hierarchy — where two explicit requirements genuinely conflict and this priority order is used to decide between them — is recorded using the change-governance fields in §37.2, so the decision remains traceable rather than silent.

## 37.2 Normative Change Governance (S7 Q22 clarification)

This defines the record required whenever a normative requirement in this PRD is added, changed, or removed by a future revision, or whenever §37.1's conflict-resolution priority is invoked to decide between two conflicting requirements. It does not create a duplicate governance authority — approval authority remains BDFL per §37, and this section only fixes the minimum fields that change must be traceable through. It does not itself constitute a revision-history log of past changes.

A recorded normative change must identify:

```text
Affected Requirement ID(s)   (§43.5 scheme)
Changed section
Rationale
Impact
Verification impact          (which tests/acceptance items are affected)
Release-gate impact          (which §47 gate(s) are affected)
Approval                     (Approval Authority per §43.5, ultimately BDFL per §37)
```

---

# 38. Android / Termux:API Degradation

Capability-based degradation: if Termux:API is unavailable — do not crash; hide unsupported functionality per capability; provide fallback behavior; clearly explain each unavailable capability. Battery/storage gates fail open per §25.2. The UI must show each affected capability as **Unavailable**, never as missing functionality.

---

# 39. Launcher State Machine (D13, amended per P1-06 and S6 P1-1)

**States:** `UNINSTALLED, INSTALLING, FIRST_BOOT, ONBOARDING, IDLE, MODULE_RUNNING, SAFE_MODE, RECOVERY, UPDATING`

**Valid transitions (complete table — only these pairs are legal):**

| From → To | Trigger |
|---|---|
| UNINSTALLED → INSTALLING | `install.sh` execution |
| INSTALLING → FIRST_BOOT | install success |
| INSTALLING → UNINSTALLED | install failure/abort (cleanup) |
| FIRST_BOOT → ONBOARDING | onboarding marker absent / `state.onboarding_completion=false` |
| FIRST_BOOT → IDLE | onboarding marker present / `state.onboarding_completion=true` |
| **FIRST_BOOT → RECOVERY** | **first-boot initialization fails in a way eligible for automatic recovery per §26.1 (e.g. `CFG-MISSING`/`CFG-BAD-VALUE`/`CFG-UNKNOWN-KEY` while building the very first `config`/`state` pair) — newly added per S6 P1-1** |
| **FIRST_BOOT → SAFE_MODE** | **first-boot initialization fails with a non-recoverable condition per §26.1 (e.g. `CFG-TAMPER`, `INSTALL-HASH`, `SECURITY-VALIDATION-FAIL`, or `UNKNOWN`) — newly added per S6 P1-1** |
| ONBOARDING → IDLE | onboarding complete |
| ONBOARDING → FIRST_BOOT | onboarding interrupted (marker not written) |
| IDLE → MODULE_RUNNING | module dispatch |
| MODULE_RUNNING → IDLE | module exit (success or handled failure) |
| IDLE → SAFE_MODE | crash flag valid (non-stale, §26.5) / config corruption / state corruption unrecoverable via backup / `--safe-mode` |
| MODULE_RUNNING → RECOVERY | module failure requiring automatic recovery |
| RECOVERY → IDLE | automatic recovery succeeds (crash flag cleared, §26.5) |
| RECOVERY → SAFE_MODE | automatic recovery fails or is unsafe |
| SAFE_MODE → RECOVERY | user selects recovery action |
| SAFE_MODE → IDLE | configuration reset or state reset succeeds (§33.1) |
| **RECOVERY → FIRST_BOOT** | **nuclear reset (§33.1, §33.2) — replaces the prior `RECOVERY → UNINSTALLED` row, which incorrectly conflated a config/state reset with uninstallation** |
| **IDLE → UNINSTALLED** | **`--uninstall` confirmed (§30.3, §33.1) — the only path to `UNINSTALLED` after initial install; newly added to correct the prior revision's missing transition** |
| IDLE → UPDATING | `--update` |
| UPDATING → IDLE | update success |
| UPDATING → IDLE (rollback) | update failure with successful restore |
| UPDATING → SAFE_MODE | update failure with failed restore |

Every crash logs current state + transition attempted (§26). Invalid transitions are logged as `E400`-class errors and refused (§48). `--uninstall` issued from any state other than `IDLE` is rejected per §15's CLI precedence rule (error `E401`) rather than silently mapped to a transition — there is no `SAFE_MODE → UNINSTALLED` or `RECOVERY → UNINSTALLED` transition in v1.0.0.

---

# 40. Safe Mode (amended per P1-07)

Entered when: forced by `--safe-mode` (highest CLI precedence, §15); a valid (non-stale) crash flag exists (§26.5); configuration corruption requires recovery; state corruption unrecoverable via `state.bak` requires recovery; crash-loop threshold reached (§26); recovery failed (§26.2). Provides: diagnostics; configuration repair; state repair; reset options (§33.1); log inspection; recovery actions. `--safe-mode` skips onboarding (§27.1).

## 40.1 Safe Mode Dependency Fallback Hierarchy (P1-07 resolution)

```text
Safe Mode Core
    (config repair, state repair, reset actions [§33.1], log viewing,
     diagnostics — implemented entirely in core.sh, zero external
     dependencies, always reachable and always usable)
    ↓
Optional: Proot-based recovery actions
    (offered ONLY if a primary_distro is recorded in state AND its
     rootfs validates as present; e.g. "repair proot environment")
    ↓
Optional: Desktop-based recovery actions
    (offered ONLY if explicitly supported for recovery use AND the
     desktop's startup_binary is present in the primary distro's
     rootfs; e.g. "relaunch desktop for manual inspection")
```

**Rule:** Safe Mode Core's availability and usability **never** depends on Proot or Desktop availability. If the primary distro's rootfs is missing, corrupted, or its `startup_binary` is absent, the corresponding menu items are hidden or explicitly marked **Unavailable** (§38) rather than causing Safe Mode itself to fail to start or to error out. A user with a completely broken or absent Proot environment can still repair configuration/state, view logs, and perform any reset action (§33.1) entirely through Safe Mode Core.

---

# 41. Data File Rules

All database files: documented schemas (§18); consistent delimiters; validated field counts; malformed records rejected per the §18 rule; read-only static catalogs; no hidden assumptions in module code.

## 41.1 Missing or Corrupt Database Behavior

If a database is missing or fails schema validation beyond the malformed-record tolerance, **only the feature/module that depends on that database** is disabled or placed into safe degradation. The launcher remains operational, unrelated modules remain available, and the user receives a clear error plus the applicable error code. Missing or corrupt data must never cause an unrecoverable launcher crash.

---

# 42. Repository Structure

```text
Devils-Mini-OS-Launcher/
├── install.sh
├── devils-minios.sh
├── SHA256SUMS
├── README.md
├── LICENSE
├── CODE_OF_CONDUCT.md
├── .gitignore
│
├── modules/          (exactly 14 files, §12 — no future_plans.sh, no plugins/)
│
├── data/
│   ├── defaults.conf
│   ├── proot_distros.db      (D5, §18.1 — includes package_manager, P0-02)
│   ├── desktops.db           (§18.4 — startup_binary/startup_args, P0-03)
│   ├── proot_apps.db         (§18.2 — install_target, P0-02)
│   ├── termux_apps.db        (§18.3 — github_* fields, P0-04)
│   ├── banners/
│   ├── themes/
│   └── reports/              (report.md written by the test report generator, §43)
│
├── test/
│   ├── run_all.sh            (harness — NOT counted)
│   ├── 19 mandatory test files (§43.1)
│
└── docs/
    ├── INSTALL.md, MODULES.md, TROUBLESHOOTING.md,
    ├── COMPATIBILITY.md, SECURITY.md, CHANGELOG.md, DATA.md
```

Runtime installation writes `~/.config/devils-minios/state` and `state.bak` (§26.4) alongside `config` — these are user-profile artifacts, never part of the repository structure above.

---

# 43. Test Suite

## 43.1 Mandatory Test Files — exactly 19

The mandatory suite is **19 test files** (the harness `run_all.sh` is exempt). Resolution arithmetic: 18 test files in the implementation baseline (S4), minus `test_future_plans.sh` (its module is removed by D1), plus `test_install.sh` and `test_report_generator.sh` (S2 additions that write `data/reports/report.md`) = **19**. SC-5 (100% pass on `aarch64` and `x86_64` before tag) applies to these 19.

No Bats dependency; assertion-based pure Bash. Additional helper scripts/fixtures may live under test support directories but do not change the mandatory count.

**Coverage floor, not coverage ceiling (S6 P2-2 resolution):** the 19-file structure is a required baseline, not a maximum. Required security/reliability coverage identified anywhere in this PRD (including new coverage added by this revision, §22.1, §23.0, §26.1, §35.3, §39, §15.1, §15.2) **must not** be reduced, thinned, or omitted merely to preserve the file count. New assertions belong first in the existing file whose responsibility already covers the area (per the table below); a new mandatory test **file** is added only through an explicit PRD revision that updates this count, never silently by an implementer choosing to split coverage differently.

| Test | Responsibility |
|---|---|
| `test_core.sh` | Core runtime: paths, logging, rotation/purge, recovery (incl. crash-loop window), SIGINT |
| `test_utils.sh` | Utility functions defined in `core.sh` (string/path helpers, sanitizers, validation primitives) |
| `test_security.sh` | Path traversal, dangerous patterns, external-storage execution block vs allowed file access, confirmation gates, rootless policy, **`execute_structured()` denylist rejection (§23.1), forbidden-token rejection for `install_target`/`startup_args`/GitHub fields (§18.2–§18.4)** |
| `test_linux_env.sh` | Official `proot-distro` catalog matching, fixed 8-desktop handling, `generate_xstartup` (incl. distro-arg rootfs selection, allowlisted `startup_binary`), systemd warning |
| `test_file_mgr.sh` | Browse/search/read/copy/transfer incl. external storage, execution block, confirmations |
| `test_termux_apps.sh` | Termux apps, 11-field schema validation, `pkg`/`github` dispatch, **`script` source rejected at schema validation**, graceful degradation |
| `test_proot_apps.sh` | Proot apps, 7-field schema, `install_target` grammar validation, architecture filtering, incompatible toggle, **`install_proot_package()` per-package-manager argv construction** |
| `test_android_tools.sh` | Android tools, Android 10+/API 29+ checks, Termux:API absent fail-open + unavailable-capability UI state |
| `test_workspace.sh` | Workspace confinement to `$HOME/devils-minios/workspaces/` (D3) |
| `test_health_check.sh` | Diagnostics, cache staleness (`health_check_interval`) |
| `test_log_viewer.sh` | Read-only boundary, Exit action, clear/export delegates to core.sh |
| `test_customize.sh` | Themes/banners, idempotency, draw counter |
| `test_system_tools.sh` | System operations, kill confirmations |
| `test_system_info.sh` | System information |
| `test_update_all.sh` | Updates, dry-run, **trust-anchor constant immutability, tag/SemVer validation, checksum verification (§30.4, §30.5)** |
| `test_settings.sh` | Settings, config validation (§17 grammar, `runtime_context` key rejection), export/import, **reset actions (§33.1)** |
| `test_integration.sh` | End-to-end: fresh install → onboarding → distro → desktop → xstartup |
| `test_install.sh` | Installation lifecycle: Git + ZIP sources, separate-install activation, existing-installation policy, **installer-owned deletion boundary (§30.1), self-source-overwrite guard** |
| `test_report_generator.sh` | Report generator writes `data/reports/report.md` with complete output + status of the suite; failure to generate is a test-system failure |

**New coverage required by this revision** is additionally mapped in the state/recovery-specific tests below:

| Test area | Responsibility |
|---|---|
| `test_core.sh` (extended) | `load_state()`/`save_state()` atomic write, `state.bak` restore path, corruption → default reinitialization, crash-flag lifecycle stages 1–9 (§26.5) |

## 43.2 Run Conventions

Phase 6 verification command: `bash test/run_all.sh` — discovers and executes all 19 files and reports an aggregate result. All 19 must pass on `aarch64` and `x86_64` before any release tag.

## 43.3 Required Edge-Case Tests

Play Store detection; repeated Play Store warnings; Android <10/API <29 rejection; missing `proot-distro`; official proot-distro discovery and catalog matching (D5); missing Termux:API (**assert fail-open: WARN `battery level unavailable; proceeding`, operation proceeds, unavailable capability marked in UI, no crash, no hard block**); low battery (≤9% block, 10–20% inclusive confirm, ≥21% continue); insufficient storage (**against the exact §25.1 formula and per-operation `required_bytes` table**); corrupt configuration with last-known-good restore; **corrupt persistent state with `state.bak` restore, and with both `state` and `state.bak` invalid (defaults reinitialization → `FIRST_BOOT`)**; terminal width <40 (Minimal mode renders; **assert `terminal_width` never appears in the written `config` file**); external-storage file access with confirmation; external-storage execution block; architecture mismatch for `aarch64`/`x86_64`; systemd-dependent desktop selection; unsupported desktop rejection; **malformed `startup_binary` value rejected at schema load (§18.4)**; **`install_target`/`package_name` values containing shell metacharacters rejected at schema load (§18.2, §18.3)**; **GitHub install with `ref` set to a branch name (not pinned) rejected (§18.3)**; **GitHub install with checksum mismatch aborted, no partial state (§23.3)**; invalid menu input; SIGINT; module failure auto-recovery; safe-mode fallback (**incl. Safe Mode Core usable with no primary distro installed, §40.1**); **crash-loop threshold (3 crashes in 10 min → Safe Mode, not bypassable by flags)**; **stale crash flag (>24h, outside crash window) cleared without forcing Safe Mode (§26.5)**; **corrupted/unparseable crash flag treated as active trigger (fail closed, §26.5)**; failed network operations; failed Git clone; separate-install activation; automatic install-source deletion (**bounded to installer-owned paths only, §30.1**); existing broken installation; migration failure; missing module; missing database; malformed database record (§18 rule); log-viewer Exit action; config grammar violations (duplicate/unknown/malformed keys rejected, D12; **`runtime_context` keys rejected if present in `config`**); `--update` rollback with failed restore → Safe Mode; **`--update` against a tampered/non-matching `OFFICIAL_REPOSITORY_URL`-hosted release is impossible to configure (no such config key exists) — assert `install.sh`/`devils-minios --update` never read any config key resembling a repository URL**; **configuration reset vs state reset vs nuclear reset vs uninstall each produce their §33.1-specified state-machine outcome and nothing else**; **`--uninstall` rejected with `E401` from any state other than `IDLE`**.

## 43.4 CI / Static Validation

Development-time checks (never a runtime dependency, §7):

```text
bash -n                                  (syntax check, all files)
ShellCheck                               (all files)
schema validation                        (all data/*.db files against §18)
forbidden-shell-construct scan           (grep for eval, sh -c, bash -c
                                           outside execute_structured();
                                           fails CI if found anywhere else)
repository structure validation          (§42)
SemVer consistency                       (§21)
checksum manifest validation             (SHA256SUMS completeness, §30.5)
full test suite execution                (all 19 files, §43.1)
```

## 43.5 Complete Requirement Traceability Framework (S6 P2-1 resolution; requirement identity, ownership, and evidence model strengthened per S7)

Appendices A–C trace this PRD's **decisions and audit inputs** (S1–S5) to the sections that incorporate them — that traceability is complete as written and is not the gap this section closes. The gap S6 P2-1 identifies, and S7 further operationalizes, is a second, finer-grained mapping: **every individual normative requirement** (not just every decision), with a stable identity, accountable ownership, and an explicit requirement-vs-evidence boundary.

### 43.5.1 Requirement Identifier Scheme (S7 Q9/Q10/Q14)

Every normative requirement that receives a traceability row (per the completeness requirement below) is assigned a stable identifier of the form:

```text
PRD-<SECTION>-<NNN>
```

- `<SECTION>` is the defining PRD section or subsection number (e.g. `22`, `18.2`, `23.0`).
- `<NNN>` is a zero-padded three-digit sequence number, unique within that section, assigned in the order requirements are enumerated for that section and never reused if a requirement is later removed.
- Example: `PRD-22-001` (first traceable requirement of §22, path validation); `PRD-18.2-001` (`proot_apps.db` field 5's `install_target` grammar, §18.2).

IDs are **stable** (never reassigned to a different requirement once published in `docs/TRACEABILITY.md`), **unique**, **human-readable**, and **traceable** to their defining section. IDs are assigned when `docs/TRACEABILITY.md` (below) is generated/regenerated in Phase 6 and thereafter maintained incrementally; this PRD does not require every sentence in the body text above to carry an inline ID tag, and IDs are never created merely to inflate a count — a requirement is one traceable, testable normative statement, not one sentence.

### 43.5.2 Traceability Fields and Ownership (S7 Q14/Q15/Q27)

**Required framework, authoritative for the implementation phase:** a generated artifact `docs/TRACEABILITY.md`, produced in Phase 6 (§53) and re-generated whenever a requirement, test, gate, or owner changes, containing one row per requirement with exactly these columns:

```text
Requirement ID       — stable identity per §43.5.1
PRD Section          — the PRD section defining the requirement
Requirement          — the testable statement itself
Rationale            — why the requirement exists
Module               — the module(s) responsible for implementing it
Implementation Artifact — the specific function(s)/data file(s) that
                       carry it out (§13.1's required-function list
                       and §18's schemas are the primary source)
Test Reference        — the specific test file/case(s) from
                       §43.1/§43.3 that assert it (automated)
Manual Acceptance     — the specific §45 acceptance-test item, if any
Release Gate          — which of §47.1–§47.4's gates blocks release
                       if this requirement is unmet
Evidence              — the actual proof recorded per §43.5.3
Status                — Verified / Partial / Not Verified (§43.5.3)
Accountable Owner     — responsible for the requirement's correctness
Verification Owner    — responsible for carrying out verification
Approval Authority     — final acceptance authority (BDFL per §37,
                       or a role BDFL delegates)
```

This is a **lean** ownership model — exactly three role fields (Accountable Owner, Verification Owner, Approval Authority), not a separate governance layer. Implementation ownership is represented in the Implementation Artifact field rather than a fourth role. Owner fields must be populated in `docs/TRACEABILITY.md` itself (never fabricated in this PRD, §43.5.4); an unpopulated owner field is a Release Candidate Gate defect (§47.3), not a silent gap.

**Completeness requirement:** every requirement in §§9–41 and §§48–52 (including the S7 additions at §4.4, §26.6, §32.2, §37.1, §37.2, and §45.1) that uses normative language ("must," "required," "exactly," "never," a named field/schema, or a named function) receives a row. A requirement with no automated test maps its "Test Reference" column to the manual acceptance item instead, and is flagged for follow-up rather than silently omitted; a requirement with neither an automated nor a manual test mapped is itself a defect the framework is designed to surface, not a state the framework may hide.

### 43.5.3 Requirement-vs-Evidence Boundary (S7 Q25)

**A requirement being written in this PRD is not evidence that it has been implemented.** The PRD is the normative authority; `docs/TRACEABILITY.md`'s Evidence and Status columns are the only place implementation status is asserted, and only when backed by one of:

```text
Source/artifact existence         Static analysis result
Schema validation                 Security test result
Automated test result             Manual acceptance result
Compatibility result              Performance result
Release verification              Approval record
```

Every row's Status is exactly one of `Verified` (evidence exists and passes), `Partial` (some but not all required evidence exists), or `Not Verified` (no qualifying evidence yet exists). Evidence that is unavailable at PRD-authoring time must be marked `Not Verified` — never omitted, never inferred from the requirement's existence, and never marked `Verified` on the strength of this document alone. This boundary applies uniformly to every evidence obligation introduced elsewhere in this revision (§26.6, §32.2, §45.1).

### 43.5.4 Non-Fabrication and Release Gating

**This PRD does not fabricate the row-by-row contents of `docs/TRACEABILITY.md`** — doing so from §18's stated field counts, from Appendix D's explicitly-marked assumptions, or by asserting owner names or `Verified` status not actually established, would misrepresent an implementation-phase artifact as already-verified fact. Instead, `docs/TRACEABILITY.md`'s existence, schema (§43.5.2), ID scheme (§43.5.1), and 100%-of-normative-requirements completeness — with every row's owner fields populated and every row's Status honestly recorded — are themselves made a **Phase 6 exit criterion and a Release Candidate Gate item** (§47.3), so that "traceability exists" is verified as a completeness obligation covering every normative requirement, never satisfiable by a partial or representative sample, and never satisfiable by unpopulated ownership or inflated Status values.

---

# 44. Release Artifacts

Every release produces: source tarball `devils-minios-vX.Y.Z.tar.gz`; `devils-minios-vX.Y.Z.tar.gz.sha256`; and `SHA256SUMS` in the repo (consumed by `install.sh --verify`, §30.5). **ZIP archives are supported as an installation source** and ship with the same checksums. No compiled artifacts. Release tags are SemVer only (§21). Per §30.5, these checksums provide integrity, not independent authenticity — release notes should state this plainly rather than imply otherwise.

---

# 45. Manual Acceptance Tests

**Installation:** fresh F-Droid Termux; Play Store Termux; Android 10+/API 29+ supported device; unsupported Android rejection; Git source install; ZIP source install; separate-install activation and automatic source deletion (installer-owned only); existing broken installation; reinstall-in-place self-overwrite guard. **Desktop:** install each of the 8 Tier-1 desktops; unsupported desktop rejected; xstartup generation (per-distro path, allowlisted binary); startup-argument validation; systemd warning behavior. **Apps:** Termux `pkg` install; Termux `github` install (pinned ref + checksum); proot app install via structured executor; architecture filtering. **Android:** ADB; fastboot; Termux:API present/absent. **UI:** 60+ / 40–59 / <40 columns; log-viewer Exit returns to the previous menu. **Recovery:** configuration corruption; state corruption; last-known-good restore for both; simulated crash; automatic recovery; safe-mode fallback with and without a primary distro installed; crash-loop → Safe Mode; configuration reset; state reset; nuclear reset; uninstall.

## 45.1 Critical Workflow Acceptance Model (S7 Q17/Q18 clarification)

This strengthens *how* the critical workflows already listed above (and elsewhere in this PRD) are accepted; it does not add new workflow behavior or duplicate the detailed behavioral requirements already specified in their authoritative sections. A workflow is **critical** if its failure blocks the primary user journey (§54): install (§30), onboarding (§27), proot distro install (§18.1/§23.1), desktop install/startup (§18.4/§23.2), app install (§18.2/§18.3/§23.1/§23.3), crash recovery/Safe Mode (§26/§40), update (§30.6), migration (§32/§32.2), and uninstall/reset (§33).

For each critical workflow, traceability (§43.5) must be able to answer, without duplicating the underlying behavior text:

```text
Normal path              — the already-specified success behavior
Important edge cases     — the §43.3 edge cases applicable to this workflow
Failure path             — the already-specified failure behavior
User-facing behavior     — what the user sees (message class, §48)
Recovery behavior        — the already-specified recovery/rollback action
Automated test           — §43.5's Test Reference, where automatable
Manual acceptance        — the applicable item above, where environment-dependent
Release gate / evidence  — §43.5's Release Gate and Evidence/Status columns
```

Each of the eight critical workflows above must have at least one traceability row per dimension it is subject to; a workflow with no automated coverage relies on its manual-acceptance row instead (§43.5.2), and a workflow with neither is a Release Candidate Gate defect (§47.3), not a silent gap.

---

# 46. Definition of Done

v1.0.0 is **not complete** until all of the following are true:

**Architecture**
- [ ] Exactly **14** modules; no `future_plans.sh` (file absent, unreferenced, unloadable); no plugin directory; no Nix module; no recent-actions module; desktop functionality merged into `linux_env.sh`

**Data**
- [ ] Exactly 8 Tier-1 desktops (`xfce4, lxqt, lxde, mate, i3wm, openbox, fluxbox, jwm`) — no experimental desktops; exactly 40 proot applications using `install_target` (no `install_cmd_template`); 30–40 Termux applications with `script` source removed; `proot_distros.db` includes `package_manager` per record; `desktops.db` uses `startup_binary`/`startup_args`; all required categories represented; no malformed database records

**Security**
- [ ] No raw `eval`/`sh -c`/`bash -c` anywhere outside `execute_structured()` (CI-enforced, §43.4); path traversal blocked; external-storage execution blocked while permitted file access remains confirmation-gated; dangerous command patterns handled; installer hardened with an explicit deletion-ownership boundary (§30.1); destructive operations confirmed; no unsafe process-kill implementation; root escalation rejected; centralized structured execution in `core.sh` (§23.1); config grammar strict key=value with duplicate/unknown/malformed rejection, including rejection of `runtime_context` keys (§17); update trust anchor is a hardcoded constant with no config override (§30.4); integrity vs authenticity distinction documented and matches actual release process (§30.5)

**Runtime**
- [ ] Bash ≥4.3 check present (single stated floor, identical in header, Goals, Compatibility Matrix, Minimum Requirements)
- [ ] Correct symlink resolution; crash traps; crash-loop protection (3-in-10-min → Safe Mode, not bypassable); automatic recovery only for allowlisted failures (D7); SIGINT handling; last-known-good configuration **and state** restoration (§26.4); platform-aware module loading; error codes in all modules; state-machine logging; one module failure never unrecoverably crashes the launcher; persistent state schema `state_version=1` with full lifecycle contract implemented (§26.4); crash-flag lifecycle fully implemented (§26.5); `terminal_width` never written to disk (§17.3); reset/uninstall semantics match §33.1 exactly, including the corrected `RECOVERY → FIRST_BOOT` and new `IDLE → UNINSTALLED` transitions (§39)

**UX**
- [ ] Full UI; Compact UI; Minimal UI (mandatory <40 col); Play Store warning every launch; proot warning before relevant operations; clear user-facing module errors; unavailable optional capabilities explicitly marked; log viewer has an Exit action; no misleading capabilities; onboarding completes with marker

**Testing**
- [ ] All **19** mandatory test files present; all pass via `test/run_all.sh` on `aarch64` and `x86_64` before tag; integration + manual acceptance tests pass; report generator produces `data/reports/report.md`; new P0/P1 edge cases from §43.3 covered
- [ ] Manual acceptance test on fresh F-Droid Termux / supported Android 10+ device before every minor release
- [ ] No unresolved release-blocking error conditions

**Documentation**
- [ ] README complete; CHANGELOG.md updated; SECURITY.md published (states the integrity-vs-authenticity boundary, §30.5); COMPATIBILITY.md published; MODULES.md published; DATA.md published (documents the remediated schemas, §18)

**Release**
- [ ] SemVer consistent across all files; SHA-256 checksums generated; GitHub Release artifacts attached (SemVer tag only)

---

# 47. Release Gates

## 47.1 Security Release Gate
v1.0.0 cannot ship if: a known critical security vulnerability remains; arbitrary command execution is possible through normal user input **or through any catalog record field**; a shell-metacharacter-bearing catalog field can reach execution; path traversal remains exploitable; the installer executes unreviewed remote code; the installer can delete a path it did not itself create (§30.1); destructive operations can execute without confirmation; configuration or state corruption causes uncontrolled behavior; the update mechanism can be redirected via any configuration value; `SHA256SUMS` is represented as proving authenticity rather than integrity.

## 47.2 Reliability Release Gate
Demonstrate: successful clean installation; normal launch; automatic recovery followed by Safe Mode fallback when recovery fails; correct platform detection; correct module loading; correct configuration **and state** initialization; no known critical crash path; correct handling of unsupported/experimental capabilities; no unrecoverable module failure; Safe Mode Core usable with zero Proot/Desktop dependencies present (§40.1).

## 47.3 Release Candidate Gate
Engineering: mandatory modules/functions implemented; **all required tests pass**; no test failure may be waived for release. Security: no known critical vulnerabilities; installer reviewed against §30.1; input paths validated per §22.1; catalog schemas validated against §18's structural security rule; destructive operations protected; root escalation rejected. Compatibility: supported F-Droid/GitHub Termux on Android 10+/API 29+ tested; both architectures tested; dynamic proot-distro discovery tested; narrow terminal tested. UX: onboarding works; primary workflow works; errors understandable; unavailable capabilities explicit; log-viewer Exit works. Acceptance: required manual acceptance tests completed. **Catalog completeness (S6 P1-3/P1-4):** `data/proot_distros.db`, `data/proot_apps.db`, and `data/termux_apps.db` each validate against their §18 schema **and** satisfy their stated completeness requirement (§18.1's complete-supported-set requirement; §18.2's exactly-40/all-13-categories requirement; §18.3's 30–40/required-categories requirement, §13.4) — the exact record contents remain an implementation deliverable (Appendix D, A-1/A-2/A-3), but a release cannot ship with a catalog that is schema-valid yet incomplete against these stated requirements. **Traceability completeness (S6 P2-1, strengthened per S7):** `docs/TRACEABILITY.md` (§43.5) exists and covers 100% of this PRD's normative requirements with no unmapped row, every row carries a stable Requirement ID (§43.5.1), every row's Accountable Owner/Verification Owner/Approval Authority fields are populated (§43.5.2, no "TBD" left in a released artifact), every row's Status honestly reflects its actual Evidence (§43.5.3 — a status of `Verified` is a release-blocking defect if the cited evidence does not actually exist), and every critical workflow in §45.1 has at least one row per applicable acceptance dimension.

## 47.4 Production Launch Gate

```text
Critical security issues = 0        Critical runtime bugs = 0
Required tests = PASS               Primary workflow = PASS
No required test failure = BLOCK    Second consistency audit = PASS
Installation = PASS                 Recovery (config+state) = PASS
Documentation = COMPLETE            Acceptance validation = PASS
SemVer consistent = YES             SHA-256 checksums = GENERATED
Error codes = IMPLEMENTED           State machine = LOGGED
Command execution = STRUCTURED-ONLY Update trust anchor = HARDCODED
```

## 47.5 Rollback Policy
On a production release introducing critical security vulnerability / data loss / unrecoverable installation failure / widespread crash: stop promotion; mark release affected; publish warning; identify affected versions; provide recovery instructions; restore previous stable where appropriate; fix; re-test; publish corrected release.

---

# 48. Error Code Taxonomy

## 48.1 Module Failure Handling
A feature-module failure must never unrecoverably terminate the launcher. `error_handler()` must: (1) present a clear user-facing error; (2) include the applicable `E100`–`E999` error code; (3) write structured log context; (4) return the launcher to a safe state; and (5) attempt automatic recovery when the failure is recoverable (§26.1). If recovery succeeds, the launcher continues from `IDLE`. If recovery fails or is unsafe, transition to `SAFE_MODE`. A module that cannot be recovered may be disabled for the session while unrelated modules remain available (central mechanism in `core.sh`; modules retain domain-specific error ownership).

- `E100`–`E199`: Core/Platform
- `E200`–`E299`: Linux/Proot
- `E300`–`E399`: App installation
- `E400`–`E499`: Security/Validation
- `E500`–`E599`: Network/IO
- `E600`–`E699`: Installation lifecycle (§30)
- `E700`–`E799`: Update & migration lifecycle (§30.6, §32)
- `E900`–`E999`: Unknown/Crash

## 48.2 Complete Error-Code Registry (S6 P1-6 resolution)

This table is the **complete** registry of every error code this PRD names anywhere. A code not listed here may not be introduced by an implementer independently; a new code requires a PRD revision that adds it to this table, keeping the range assignment above authoritative and non-overlapping. `Retryability` states whether re-attempting the exact same operation without a state change is expected to succeed. `Recovery eligibility` cross-references the §26.1 `Failure ID` (or states "N/A" for codes that are not crash/recovery-flow errors at all, such as ordinary CLI usage rejections).

| Code | Meaning | Trigger | Owner | Log level | User-facing message class | Retryability | Recovery eligibility (§26.1) | Exit status |
|---|---|---|---|---|---|---|---|---|
| `E203` | Distro rootfs not installed | `run_desktop_startup()` targets a distro with no installed rootfs | `linux_env.sh` | WARN | Actionable — "install the distro first" | Retryable after user installs the distro | N/A (user-action-required, not a recovery-flow failure) | 3 |
| `E400` | Invalid state transition attempted / conflicting CLI flags | State machine (§39) or CLI precedence (§15) violation | `core.sh` | ERROR | Actionable — names the invalid transition/flags | Retryable with corrected input | N/A | 2 |
| `E401` | `--uninstall` issued outside `IDLE` | CLI dispatch (§15, §39) | `core.sh` | ERROR | Actionable — "resolve current state first" | Retryable once state is `IDLE` | N/A | 2 |
| `E402` | Unknown `startup_binary` | `run_desktop_startup()` / schema load (§18.4, §23.2) | `linux_env.sh` | WARN | Informational — desktop marked unavailable | Not retryable until the catalog record is fixed | N/A (malformed-record path, §18) | 2 |
| `E403` | Invalid `startup_args` token | `run_desktop_startup()` (§23.2) | `linux_env.sh` | WARN | Actionable — desktop launch aborted with clear error | Not retryable until the catalog record is fixed | N/A | 2 |
| `E404` | GitHub artifact checksum mismatch | `install_github_artifact()` (§23.3) | `termux_apps.sh` | ERROR | Actionable — "downloaded file failed verification, install aborted" | Retryable (may be a transient transfer corruption) | N/A (aborts before any state change) | 2 |
| `E405` | Persistent state corruption, `state.bak` also invalid | `load_state()` (§26.4) | `core.sh` | WARN | Informational — state reinitialized to defaults | Not applicable (self-healed) | `STATE-CORRUPT-UNRECOVERABLE` | 0 (self-healed) |
| `E406` | Persistent state corruption, `state.bak` valid | `load_state()` (§26.4) | `core.sh` | WARN | Informational — state restored from backup | Not applicable (self-healed) | `STATE-CORRUPT-RECOVERABLE` | 0 (self-healed) |
| `E410` | Configuration missing | `load_config()` (§17) | `core.sh` | WARN | Informational — configuration regenerated from defaults | Not applicable (self-healed) | `CFG-MISSING` | 0 (self-healed) |
| `E411` | Configuration value/key invalid (bad value, unknown key, or `runtime_context` key present in file) | `validate_config()` (§17.4) | `core.sh` | WARN | Informational — configuration restored from defaults | Not applicable (self-healed) | `CFG-BAD-VALUE` / `CFG-UNKNOWN-KEY` | 0 (self-healed) |
| `E412` | Configuration/installation tamper signal | `validate_config()` cross-checked against manifest integrity (§30.5) | `core.sh` | ERROR | Non-actionable by automatic means — Safe Mode entry explained to user | Not retryable automatically | `CFG-TAMPER` (never auto-recovered) | 1 |
| `E420`–`E429` | `execute_structured()` denylist / structural rejection (§23.0, §23.1) | Any `execute_structured()` call site | `core.sh` | ERROR | Actionable — operation aborted, no partial effect | Not retryable with the same input | `SECURITY-VALIDATION-FAIL` (never auto-recovered) | 2 |
| `E430`–`E439` | Path validation rejection (§22.1), one sub-code per failed step (lexical, traversal, root-containment, final-component, symlink-policy, revalidation) | `core.sh::validate_path()` | `core.sh` | WARN | Actionable — names the rejected path and reason class (never the full resolved filesystem layout) | Retryable with a corrected path | N/A | 2 |
| `E440` | `systemd_flag` acknowledgement declined | Desktop install flow (§35.3) | `linux_env.sh` | INFO | Informational — install aborted, no changes made | Retryable (re-attempt install and acknowledge) | N/A | 4 |
| `E601` | Existing non-empty, unrecognized installation directory | `install.sh` (§30) | `install.sh` | ERROR | Actionable — refuses to overwrite; explains manual resolution | Retryable after user clears/relocates the directory | N/A | 1 |
| `E602` | Install manifest/checksum verification failure | `install.sh --verify` / installation activation (§30.2, §30.5) | `install.sh` | ERROR | Actionable — "installation failed verification" | Retryable with a fresh download | `INSTALL-HASH` (never auto-recovered) | 2 |
| `E603` | Insufficient storage for the requested install/heavy operation | `check_storage_threshold()` (§25.1) | `core.sh` | WARN | Actionable — explains the exact shortfall against the §25.1 formula | Retryable after freeing space | N/A | 3 |
| `E701` | Update release verification failure | `--update` (§30.6 step 4) | `core.sh` | ERROR | Actionable — "update failed verification, no changes made" | Retryable | `INSTALL-HASH` (never auto-recovered) | 2 |
| `E702` | Update activation failure with successful rollback | `--update` (§30.6 step 10) | `core.sh` | ERROR | Actionable — "update failed, previous version restored" | Retryable | N/A (rollback is the defined action, not §26.1 auto-recovery) | 1 |
| `E703` | Update/migration failure with failed rollback | `--update` (§30.6 step 10) / `§32` migration | `core.sh` | ERROR | Non-actionable by automatic means — Safe Mode entry explained | Not retryable automatically | N/A (never auto-recovered; enters `SAFE_MODE` directly) | 1 |
| `E900` | Unrecognized/unclassified failure | Any call site whose failure matches no other defined code | `core.sh` | ERROR | Non-actionable by automatic means — generic crash message, crash record saved (§26) | Unknown | `UNKNOWN` (never auto-recovered) | 1 |

Every module uses these codes in `write_log_file()` and `error_handler()`. Standard return codes: `0` success; `1` generic failure; `2` validation error; `3` resource unavailable; `4` user abort; `5` platform unsupported. Function signature template (name, args, returns, side effects) is mandatory for public functions; private functions prefixed `_`. No two rows in this table may share a numeric code, and no code in the ranges above may be used by an implementer for a purpose not listed here without a PRD revision extending this table (this is itself a release-gate check, §47.1).

---

# 49. Privacy & Data Policy

Zero network telemetry by default; no analytics; no crash reporter calling home. Configuration, state, logs, and crash reports remain local (operational data remains local unless an explicitly defined product operation requires otherwise). Log retention follows the single regime in §24 (referenced, not restated). `sanitize_log_for_upload()` strips paths, usernames, and IP-like strings before manual copy-paste to GitHub issues. Optional external reporting is always explicit. The only network destination the launcher ever contacts for its own code is `github.com`, and only at the fixed `OFFICIAL_REPOSITORY_URL` (§30.4) for updates, or a pinned per-record GitHub release URL for `install_source=github` Termux apps (§18.3) — never a dynamically constructed or user-supplied host.

---

# 50. Documentation Requirements

README explains: what Termux is; supported sources; why Play Store builds are warned about; installation (Git and ZIP); first launch; basic workflows; proot limitations; security model (including the integrity-vs-authenticity distinction, §30.5); recovery (including configuration reset / state reset / nuclear reset / uninstall as four distinct operations, §33.1); troubleshooting; supported architectures; supported desktops; supported applications; contributing; reporting security issues. `docs/` contains INSTALL.md, MODULES.md, TROUBLESHOOTING.md, COMPATIBILITY.md, SECURITY.md, CHANGELOG.md, DATA.md. README links, never duplicates.

---

# 51. Security Policy & Changelog Standards

Vulnerability reporting via GitHub private vulnerability reporting. Response SLA: acknowledge 7 days; patch 30 days critical / 90 days moderate. Releases include SHA-256 checksums and `SHA256SUMS` for manifest verification, documented as an integrity control (§30.5), not an authenticity guarantee. Post-install/migration verifies removed modules (e.g. `future_plans.sh`) are absent and deletes them if found. Changelog follows Keep a Changelog 1.1.0; release notes include compatible Termux versions, breaking changes, migration steps, SHA-256 checksums.

---

# 52. Dependencies & Assumptions (Index)

**Dependencies:** git (install/update path); `proot-distro` (Linux/proot workflows); Termux:API (optional — fail-open, §25.2); `termux-wake-lock` (auto-start only); Termux:Boot app (auto-start only); `curl` and `sha256sum` (GitHub artifact installs, §23.3). All optional components degrade per §38.

**Assumptions:** users install Termux from F-Droid/GitHub; devices meet §9 minimums; users can inspect shell scripts before execution; the official `proot-distro` catalog is authoritative for runtime discovery (D5); the `OFFICIAL_REPOSITORY_URL` GitHub account (§30.4) is not compromised — an explicitly accepted residual risk, not a silent one.

Failure handling is defined directly in the authoritative security, runtime, installation, and data sections. Actionable risk controls are merged into their authoritative sections; no standalone risk register exists.

---

# 53. Implementation Order

Dependency-gated phases:

```text
Phase 0  Security + architecture cleanup (remove future_plans.sh + its test + its alias;
         re-author DBs to the remediated §18 schemas: proot_apps.db install_target,
         termux_apps.db github_* fields with script removed, desktops.db
         startup_binary/startup_args, proot_distros.db package_manager)
Phase 1  Core runtime + installer (separate-install model + ZIP path + §30.1 deletion
         boundary) + entry point + persistent-state contract (§26.4)
Phase 2  Configuration + data layer (defaults + 4 DBs, §18 schemas, runtime_context
         split §17)
Phase 3  Proot + desktop functionality (incl. onboarding §27, structured startup §23.2)
Phase 4  Apps + Android tools + workspace (D3 root; structured install §23.1, §23.3)
Phase 5  Health + logs + customization + system tools
Phase 6  Complete test suite — bash test/run_all.sh, all 19 files; report generator
Phase 7  Documentation + release preparation (docs/, SHA256SUMS, LICENSE, README,
         update trust anchor §30.4 hardcoded, integrity/authenticity docs §30.5)
Phase 8  Production release gate (§47)
```

Phase 6 verification command: `bash test/run_all.sh`. All 19 mandatory test files must execute; no known critical test failure may remain.

---

# 54. Master Acceptance Statement

Devil's Mini OS Launcher v1.0.0 is production-ready only when it reliably performs the primary user journey:

```text
Fresh supported Termux → Secure installation → Successful launcher start
→ Guided onboarding → Linux/proot environment installation
→ Tier-1 desktop installation → Desktop configuration
→ Development/application workflow → Successful Linux task
→ Safe shutdown/restart → Successful recovery if failure occurs
```

while simultaneously satisfying: **Security + Compatibility + Reliability + Testability + Usability + Documentation + Product validation.** The product is evaluated both as a secure Bash software system and as a usable Linux-workstation management product for Termux — optimizing for *"Can a real Termux user reliably reach a useful Linux workflow with minimal manual configuration?"*, not feature count.

**Readiness synthesis (S7 Q30):** this PRD is structurally **Production-ready** (behavior, UX, security, reliability/recovery, performance, compatibility, error handling, acceptance, and release gates are all normatively defined), **Implementation-ready** (every normative requirement carries enough information, via §43.5, to implement and verify it), and **Audit-ready** (every requirement is traceable through implementation, testing, acceptance, release evidence, and approval, per §43.5's Requirement ID/ownership/evidence-status fields). None of this means the implementation itself is complete — that status is what `docs/TRACEABILITY.md`'s actual Evidence/Status columns report, never what this PRD asserts on its own.

---

# 55. Remediation Report (S5, S6)

See the companion document `Remediation-Report-and-Score.md` for the full S5 finding-by-finding table, the updated scorecard, and the release decision as of the S5 pass. Summary: **all 6 S5 P0 findings, all 8 S5 P1 findings, and the SC-01 structural finding are resolved in the prior revision; the 5 S5 P2 findings were addressed to the extent practical at the PRD layer, with the remainder flagged as implementation-phase deliverables (Phase 0–7, §53).**

**S6 second-pass hardening summary (this revision, §0.3, Appendix E):** the S6 audit ("Report.md") identified 6 P0, 7 P1, and 5 P2 findings against an interim draft. Applying those findings to the S1–S5 baseline in this revision: `S6 P0-4` (crash-flag lifecycle), `S6 P0-5` (`terminal_width` persistence), `S6 P0-6` (installer deletion boundary), `S6 P1-2` (nuclear-reset transition), and `S6 P1-7` (integrity vs authenticity) were found **already resolved** in the S1–S5 baseline (§26.5, §17.3/§19.2, §30.1, §33.1/§39, §30.5 respectively) and required no further change beyond confirmation. The remaining 12 findings (`S6 P0-1`, `P0-2`, `P0-3`, `P1-1`, `P1-3`, `P1-4`, `P1-5`, `P1-6`, `P2-1`, `P2-2`, `P2-3`, `P2-4`, `P2-5`) required and received concrete additions in this revision (§23.0, §22.1, §26.1, §39, Appendix D/§47.3, Appendix D/§47.3, §35.3, §48.2, §43.5, §43.1, §20, §15.1, §15.2 respectively). **P0 = 0, P1 = 0, P2 = 0 unresolved after this revision.**

---

# Appendix A — Traceability of the 14 Final Design Decisions (D1–D14)

Source: S3. Every decision is binding; none is silently dropped.

| ID | Decision | Final ruling | PRD section(s) | Status |
|---|---|---|---|---|
| D1 | Module architecture | Exactly **14 active modules**; `future_plans.sh` removed | §5, §12, §15, §42 | Incorporated |
| D2 | Desktop scope | Exactly **8** desktops: `xfce4, lxqt, lxde, mate, i3wm, openbox, fluxbox, jwm`; **no experimental desktops** | §18.4, §6 | Incorporated |
| D3 | Workspace root | Dedicated `$HOME/devils-minios/workspaces/`; external storage never an execution workspace | §13.7, §36, §22 | Incorporated |
| D4 | Configuration ownership | **11 persisted user-owned keys + 4 runtime-owned facts**, now split into 3 categories per P1-02/P1-03 | §17 | Incorporated, refined |
| D5 | Proot distro catalog | `data/proot_distros.db`, schema amended to add `package_manager` (P0-02) | §18.1 | Incorporated, amended |
| D6 | Crash-loop protection | **3 serious crashes within 10 minutes → disable automatic recovery → Safe Mode** | §26, §43.3 | Incorporated |
| D7 | Recovery eligibility | Explicit allowlist; security, integrity, unknown/unsafe, crash-loop failures never auto-recover | §26.1 | Incorporated |
| D8 | Persistent state | Independent `state_version=1` + explicit schema, now with a full storage contract (P0-01) | §26.3, §26.4 | Incorporated, extended |
| D9 | State migration | Independent, version-by-version config and state migrations | §32 | Incorporated |
| D10 | Backup/restore | Manifest + SHA-256 hashes + metadata + staged atomic restore; no user/workspace duplication | §32.1 | Incorporated |
| D11 | Command execution | Strict allowlisted grammar + structured arguments + centralized `core.sh` execution, now the **sole** executor with no template model (P0-02, P0-03) | §23.1, §13.1 | Incorporated, hardened |
| D12 | Config grammar | Strict `key=value`; central validation; duplicate/unknown/malformed rejection; atomic writes; now also rejects `runtime_context` keys | §17 | Incorporated, extended |
| D13 | CLI/state machine | Deterministic CLI precedence + complete failure transitions; failed rollback → Safe Mode; reset/uninstall transitions corrected (P1-06) | §15, §39 | Incorporated, corrected |
| D14 | PRD structure | Production specification; no revision history, no historical/supersession language (SC-01), no duplicate authority material | §0, §6; neutral wording throughout | Incorporated |

---

# Appendix B — Traceability of the Audit Item Set (S2)

## B.1 Question decisions Q1–Q26

Source: S2. Every item resolves to a section in this PRD; nothing is silently dropped. (Unchanged from the prior revision's mapping; see Appendix C for any item touched by this revision's remediation.)

| ID | Subject | Decision | PRD section(s) |
|---|---|---|---|
| Q1 | Theme & Banner Systems | Fully specify, optional/non-critical, Safe/Minimal independent | §34 |
| Q2 | Workspace Security | Strong security + execution protection | §36, §22 |
| Q3 | Android / Termux:API Degradation | Capability-based degradation, per-capability failure | §38, §25.2 |
| Q4 | Data File Rules | Immutable/read-only static catalogs, separate from runtime state | §18, §41 |
| Q5 | Repository Structure | Exact repo/runtime separation; 14 active modules | §12, §42 |
| Q6 | Test Suite | 18 base + 2 additions → 19 (resolved) | §43.1, §42 |
| Q7 | Required Edge-Case Tests | Full coverage with traceability | §43.3 |
| Q8 | Manual Acceptance Tests | End-to-end user-flow coverage | §45 |
| Q9 | Definition of Done | Separate implementation/automated/manual/validation/readiness | §46 |
| Q10 | Product Metrics & Funnel | Removed; no user tracking | absent (§2.4 keeps only non-tracking success criteria) |
| Q11 | Beta Strategy | Removed entirely | absent |
| Q12 | Feature Prioritization | Merged into implementation/release structure | §53, §47 |
| Q13 | Release Gates | Mandatory gates hard-blocking | §47 |
| Q14 | Error Code Taxonomy | Central mechanism in `core.sh`; modules keep domain ownership | §48 |
| Q15 | Launcher State Machine | Fully specified deterministic states/transitions/precedence | §39 |
| Q16 | Privacy & Data Policy | Strong local-first; no tracking/analytics/telemetry/profiling | §49 |
| Q17 | Documentation Requirements | Fully specify docs + coverage | §50 |
| Q18 | Security Policy & Changelog | High-level policy; no duplicate security authority | §51 |
| Q19 | Risks & Mitigations | Merged into authoritative sections; no standalone register | §52, domain sections |
| Q20 | Dependencies & Assumptions | Concise index only | §52 |
| Q21 | Baseline Decisions & Deferred | Merged into authoritative sections/scope | §6, §53, Appendices |
| Q22 | AI Engineering Governance | Removed entirely | absent |
| Q23 | Implementation Order | Dependency-gated phases | §53 |
| Q24 | User Stories | Merged into Product Definition/Personas/Goals | §2, §4, §5, §54 |
| Q25 | Final Authoritative Decisions | Merged into domain sections; no duplicate authority section | throughout; Appendices are traceability only |
| Q26 | Final input check | Produce final PRD + audit report | §0 (this document + its appendices) |

## B.2 Structural-cleanup mandates CL-01–CL-12 ("The production PRD must not contain …")

| ID | Must not contain | Verified disposition |
|---|---|---|
| CL-01 | Historical revision history | Absent (§0 lists only the current reconciliation lineage) |
| CL-02 | Historical/supersession language ("supersedes", "superseded", version-literal comparisons) | **Resolved this revision (SC-01):** replaced throughout with neutral Source/Decision/Resolution/Final Requirement/Traceability wording; sources are referenced as S1–S5, not as version numbers |
| CL-03 | A Removed Modules section | Absent |
| CL-04 | `--run-module` implementation as a standalone section | Flag itself retained (§15); no standalone section |
| CL-05 | Community & Support as a numbered requirement section | Absent |
| CL-06 | User analytics/funnel requirements | Absent |
| CL-07 | Beta strategy requirements | Absent |
| CL-08 | Standalone feature prioritization | Absent (merged) |
| CL-09 | Standalone risk register | Absent (merged) |
| CL-10 | Standalone user stories | Absent (merged) |
| CL-11 | Duplicate final-authority lists | Absent (authority lives in domain sections; appendices are traceability) |
| CL-12 | AI engineering-governance instructions | Absent |

---

# Appendix C — Resolution Log

Every conflict or finding requiring adjudication, with the binding resolution, stated in neutral traceability terms (Source → Decision → Resolution → Final Requirement) rather than historical/supersession language (SC-01).

| ID | Item | Sources | Resolution (binding) | PRD § |
|---|---|---|---|---|
| CF-01 | Desktop scope | S2 vs S3 | D2 is authoritative: exactly `xfce4, lxqt, lxde, mate, i3wm, openbox, fluxbox, jwm` | §18.4, §6 |
| CF-02 | Architecture set | S1/S2 vs S3 | Canonical `aarch64`, `x86_64` only | §9, §10, §18 |
| CF-03 | Android minimum | S1 vs S3 | Android 10.0 / API 29+ | §9, §10, §43.3 |
| CF-04 | Workspace root | S1 vs S3 | Dedicated `$HOME/devils-minios/workspaces/` | §13.7, §36 |
| CF-05 | External storage | S1 vs S3 | Block execution; allow explicit file access with confirmation | §22 |
| CF-06 | Battery gates | S1 vs S3 | `≤9%` block / `10–20%` inclusive confirm / `≥21%` continue | §25.1 |
| CF-07 | Configuration key count | S1 vs S3 | 11 persisted + 4 runtime-owned = 15 total; refined this revision into 3 categories (P1-02/P1-03) | §17 |
| CF-08 | Module count | S3 vs S4 | 14 modules; `future_plans.sh` removed | §12, §42, §43.1 |
| CF-09 | Test-file count | S2 vs S3 vs S4 | 19 (18 baseline − `test_future_plans.sh` + `test_install.sh` + `test_report_generator.sh`) | §2.4, §5, §43, §46 |
| CF-10 | Installation model | S1/S4 vs S3 | Separate-install model, Git + ZIP, auto source cleanup bounded to installer-owned paths (refined by P1-08 this revision) | §30, §30.1 |
| CF-11 | Auto-start flag | S1/S3 vs S2 | Boot file invokes plain `devils-minios` | §31 |
| CF-12 | Experimental desktops | S1/S3 vs S3 | No experimental desktops in v1.0.0 | §18.4, §6 |
| CF-13 | Config key `show_experimental_desktops` | S1/S4 vs S2 | Key must never exist | §17 |
| CF-14 | Crash recovery | S1 vs S3 | 3-in-10-min threshold + recovery allowlist, not bypassable by flags | §26, §39 |
| CF-15 | Data schemas vs implementation baseline | S3 vs S4 | Re-author all DBs to §18 schemas; field counts validated at load | §18, §41 |
| CF-16 | Implementation baseline missing required assets | S3 vs S4 | Gap analysis §50-equivalent: listed items are required implementation deliverables | §30.1, §42, §43, §13.1 |
| **CF-17** | **Command execution model for proot app installs (P0-02)** | **S5 vs S3(D11)** | **`install_cmd_template` removed; replaced by `install_target` + centralized `install_proot_package()`** | **§18.2, §23.1** |
| **CF-18** | **Desktop startup execution model (P0-03)** | **S5 vs S3** | **`startup_cmd` removed; replaced by `startup_binary`/`startup_args` + `run_desktop_startup()`** | **§18.4, §23.2** |
| **CF-19** | **Remote application-install trust (P0-04)** | **S5 vs S1** | **`script` source removed; `github` source given a complete pinned-ref + checksum contract** | **§18.3, §23.3** |
| **CF-20** | **Update repository trust anchor (P0-05)** | **S5** | **`OFFICIAL_REPOSITORY_URL` is a hardcoded constant with no configuration override** | **§30.4** |
| **CF-21** | **Checksum integrity vs authenticity (P0-06)** | **S5** | **Explicitly documented as two different guarantees; v1.0.0 provides integrity only** | **§30.5** |
| **CF-22** | **Persistent state storage contract (P0-01)** | **S5 vs S3(D8)** | **Full location/format/permissions/atomicity/corruption/backup/migration/Safe-Mode contract added** | **§26.4** |
| **CF-23** | **`terminal_width` persistence (P1-02, P1-03)** | **S5** | **Never persisted; lives only in `runtime_context`** | **§17.3, §19.2** |
| **CF-24** | **Storage threshold formula (P1-04)** | **S5** | **`available_bytes >= required_bytes + safety_margin_bytes`, both terms defined exactly** | **§25.1** |
| **CF-25** | **Crash flag lifecycle (P1-05)** | **S5** | **9-stage lifecycle defined: creation, reading, stale detection, two clearing paths, Safe Mode clearing, corruption handling, crash-history independence** | **§26.5** |
| **CF-26** | **Reset/uninstall semantics (P1-06)** | **S5 vs S3(D13)** | **Four distinct operations defined; `RECOVERY → UNINSTALLED` row corrected to `RECOVERY → FIRST_BOOT`; `IDLE → UNINSTALLED` added** | **§33.1, §39** |
| **CF-27** | **Safe Mode dependency fallback (P1-07)** | **S5** | **Safe Mode Core has zero external dependencies; Proot/Desktop recovery actions are additive and optional** | **§40.1** |
| **CF-28** | **Installer deletion ownership (P1-08)** | **S5** | **Only paths created by the installer itself in the current run, tracked by captured variable, are deletable** | **§30.1** |
| **CF-29** | **Historical/supersession language (SC-01)** | **S5** | **All prose replaced with neutral Source/Decision/Resolution/Final Requirement/Traceability wording; version literals (v1.4/v1.5) replaced with Source IDs (S1–S5)** | **Throughout; Appendices A–C** |

---

# Appendix D — Explicit Assumptions & Open Items

Items below are **marked assumptions** (not invented scope): they are defaults consistent with the existing implementation and the binding decisions, recorded explicitly so they can be challenged in review.

| ID | Item | Assumption / note |
|---|---|---|
| A-1 | `proot_distros.db` concrete catalog, incl. `package_manager` per entry | The DB is the complete supported set (D5). Minimum expected entries (Ubuntu, Debian, Arch, Fedora, Alpine, Void) each need a correct `package_manager` value assigned as an implementation deliverable frozen at Phase 0/2 (§53). **Authoritative artifact (S6 P1-3):** `data/proot_distros.db` itself is the authoritative release artifact; its schema (§18.1) and completeness against D5's "complete supported set" statement are validated at every load (malformed-record rule, §18) and are a Release Candidate Gate item (§47.3) — this PRD defines the contract and the gate, not the exact record list. |
| A-2 | Proot app catalog contents | Exactly 40 records, all 13 categories, per §18.2 — the specific app list and each `install_target` value is an implementation deliverable. **Authoritative artifact (S6 P1-4):** `data/proot_apps.db` is the authoritative release artifact for exact contents; the 40-record/13-category completeness requirement is schema-validated at load and gated at release (§47.3), not asserted here by naming applications this PRD's source material does not enumerate. |
| A-3 | Termux app catalog contents | 30–40 records per §18.3 — specific list, and which records use `pkg` vs `github`, is an implementation deliverable; any record previously modeled as `script` must be re-homed to `pkg` or `github` or dropped. **Authoritative artifact (S6 P1-4):** `data/termux_apps.db` is the authoritative release artifact for exact contents; the 30–40-record/required-category completeness requirement (§13.4) is schema-validated at load and gated at release (§47.3). |
| A-4 | No network API surface | The launcher has no remote API, authentication model, or external SLAs beyond `github.com` per §49; all functionality is local to Termux. |
| A-5 | Performance reference device | Defined normatively in §20 (Snapdragon 695-class / Dimensity 900-class, 4–6 GB, Android 12–14). |
| A-6 | Test report location | `data/reports/report.md`; generated by `test_report_generator.sh`. |
| A-7 | Per-desktop storage estimates (§25.1) | The 300 MB default is a conservative placeholder; Phase 2 (§53) should populate a per-desktop table from real measured package-set sizes where available, without changing the formula itself. |
| A-8 | Release signing (§30.5) | Explicitly deferred, not silently assumed present. A future PRD revision may add GPG-signed releases; until then §30.5's stated boundary is the accurate one. |
| A-9 | PRD versioning forward | Future PRD revisions MUST update §0 Document Control, re-run the consistency audit, keep every normative number in exactly one section, and continue using neutral Source/Decision/Resolution wording (no reintroduction of supersession language, per SC-01/CL-02). |

---

# Appendix E — Second-Pass Hardening Traceability (S6 / "Report.md")

Every S6 finding, its subject, its verdict against the S1–S5 baseline, and its resolution in this revision. Findings marked "Already resolved" required no PRD change; findings marked "Corrected" required the cited addition.

| ID | Subject | Verdict vs. S1–S5 baseline | Resolution (binding) | PRD § |
|---|---|---|---|---|
| S6 P0-1 | Command Execution Contract incomplete | Baseline had the executor/denylist model (§23.1) but not a per-executor field-by-field contract | **Corrected:** added the complete per-executor table (Command ID, argument schema/validators, env policy, working-directory policy, stdin/stdout policy, timeout, exit-code mapping, interactive mode, network/privilege requirement) | §23.0 |
| S6 P0-2 | Path validation algorithm not implementation-complete for nonexistent/symlink/race cases | Baseline had the security rule (§22) but not a deterministic step sequence covering nonexistent components, symlink creation, rename/move, recursive deletion, and TOCTOU revalidation | **Corrected:** added the 8-step deterministic algorithm with explicit case-coverage table | §22.1 |
| S6 P0-3 | Automatic recovery allowlist not concrete | Baseline had a category-level table (module init / temp corruption / allowlisted config corruption) without named failure IDs | **Corrected:** replaced with a concrete `Failure ID`-keyed table (`CFG-MISSING`, `CFG-BAD-VALUE`, `CFG-UNKNOWN-KEY`, `CFG-TAMPER`, `STATE-CORRUPT-RECOVERABLE`, `STATE-CORRUPT-UNRECOVERABLE`, `INSTALL-HASH`, `SECURITY-VALIDATION-FAIL`, `CRASH-LOOP-THRESHOLD`, `MOD-INIT-FAIL`, `RUNTIME-TEMP-CORRUPT`, `UNKNOWN`) | §26.1 |
| S6 P0-4 | Crash-flag lifecycle incomplete (risk of clear-then-reloop) | **Already resolved** — the baseline's 9-stage lifecycle (creation, reading, stale detection, non-stale routing, clearing-on-success, clearing-on-recovery, clearing-in-Safe-Mode, corruption handling, independence from crash-history window) already covers creation through clearing and stale/malformed handling | Confirmed; no change | §26.5 |
| S6 P0-5 | `terminal_width` simultaneously non-persistent and persisted | **Already resolved** — the baseline already defines `terminal_width` as the sole `runtime_context` key, explicitly never written to `config`, with `validate_config()` rejecting the key outright if found in the file | Confirmed; no change | §17.3, §19.2 |
| S6 P0-6 | Automatic deletion of Git checkout too dangerous | **Already resolved** — the baseline's installer deletion-ownership boundary (§30.1) already restricts deletion to installer-created, variable-tracked temp paths and explicitly protects a user's own clone and the currently-active installation from deletion | Confirmed; no change | §30.1 |
| S6 P1-1 | First-boot failure transitions missing | Baseline defined `FIRST_BOOT → ONBOARDING` and `FIRST_BOOT → IDLE` but no failure path | **Corrected:** added `FIRST_BOOT → RECOVERY` (recoverable init failure) and `FIRST_BOOT → SAFE_MODE` (non-recoverable init failure), keyed to the §26.1 allowlist | §39 |
| S6 P1-2 | Nuclear reset transitioning to `UNINSTALLED` | **Already resolved** — the baseline already corrects this to `RECOVERY → FIRST_BOOT`, distinct from `IDLE → UNINSTALLED` (which is reserved for `--uninstall` only) | Confirmed; no change | §33.1, §39 |
| S6 P1-3 | Proot distro catalog contents not fully defined | Baseline already treats exact contents as an implementation deliverable (Appendix D, A-1) but did not tie completeness to a named release gate | **Corrected:** added an explicit Release Candidate Gate item requiring schema validity **and** stated completeness (not just schema validity) before release | §18.1, Appendix D (A-1), §47.3 |
| S6 P1-4 | Application catalog contents not fully defined | Same pattern as P1-3 (Appendix D, A-2/A-3) | **Corrected:** same gate addition applied to `proot_apps.db` and `termux_apps.db` | §18.2, §18.3, Appendix D (A-2/A-3), §47.3 |
| S6 P1-5 | `systemd_flag` "blocking" vs. "acknowledge and continue" ambiguity | Baseline stated "blocking warning" without the full pause/explain/acknowledge/continue sequence or an explicit non-implication clause | **Corrected:** added the exact sequence and the explicit "acknowledgement does not imply systemd support" clause | §35.3 |
| S6 P1-6 | Error-code registry incomplete | Baseline named 7 codes plus ranges; referenced `E4xx`-class errors elsewhere without full enumeration | **Corrected:** added the complete registry (log level, retryability, §26.1 recovery-eligibility cross-reference for every named code) and two new ranges (`E600`–`E699` Installation, `E700`–`E799` Update/Migration) to house codes already implied by §30/§30.6/§32 | §48.2 |
| S6 P1-7 | Integrity vs authenticity conflation | **Already resolved** — the baseline already states SHA-256 as integrity-only and names trusted-channel delivery as the v1.0.0 authenticity boundary, with signing explicitly out of scope | Confirmed; no change | §30.5 |
| S6 P2-1 | Traceability matrix only representative | Baseline's Appendices A–C trace decisions/audit inputs completely, but no per-requirement test/gate matrix existed | **Corrected:** defined the `docs/TRACEABILITY.md` framework and schema, and made its 100%-completeness a Release Candidate Gate item, without fabricating its row contents | §43.5, §47.3 |
| S6 P2-2 | Exact test count over-constrained | Baseline stated the count and rationale but not that coverage must never be reduced to preserve it | **Corrected:** added the explicit coverage-floor-not-ceiling statement | §43.1 |
| S6 P2-3 | Performance measurement conditions underspecified | Baseline defined targets, sample counts, and a reference device class, but not thermal/battery/network/storage conditions or variance handling | **Corrected:** added the full condition table (thermal, battery, network, storage, cold/warm definitions, warm-up, sample counts, statistical measure, acceptable variance) | §20 |
| S6 P2-4 | `--offline` needs an operation matrix | Baseline stated the general behavior (§29) without an exhaustive per-operation table | **Corrected:** added the complete operation matrix | §15.1 |
| S6 P2-5 | `--no-checks` needs an explicit matrix | Baseline distinguished "non-critical diagnostics" from security/critical checks in prose without an exhaustive table | **Corrected:** added the complete skippable/never-skippable matrix | §15.2 |

---

*End of Master Production PRD v6.2 (third hardening pass). Consistency-verification pass: all numeric limits appear once (1 MB / 4 rotated / 30 days §24; 14 modules §12; 8 desktops §18.4; 15 logical config keys across 3 categories §17; 40/30–40 apps §18; 19 tests §43; 7-field proot_distros/proot_apps schemas, 11-field termux_apps schema, 7-field desktops schema §18); every CLI flag defined in §15, with `--offline` (§15.1) and `--no-checks` (§15.2) carrying complete operation matrices; every required function listed in its module section §13.1; canonical `aarch64`/`x86_64` naming throughout; no removed feature (`script` install source, `install_cmd_template`, `startup_cmd`) referenced as a v1.0.0 capability; every decision (Appendix A), question item (Appendix B), S5 resolution-log entry (Appendix C, CF-17…CF-29), and S6 hardening finding (Appendix E) is traced; the S7 30-question audit (Q1–Q30) is traced in §0.4 and the companion `PRD-6.2-AUDIT-MAP.md`; no historical/supersession language remains (SC-01, verified against CL-02, and against the S7 additions at §0.4, §4.4, §26.6, §32.2, §37.1, §37.2, §43.5, §45.1); the command-execution contract (§23.0), path-validation algorithm (§22.1), recovery allowlist (§26.1), error-code registry (§48.2), performance/offline/no-checks matrices (§20, §15.1, §15.2), and the S7 requirement-ID/ownership/evidence scheme (§43.5) use terminology and section-numbering consistent with the surrounding S1–S6 baseline and introduce no new numeric contradiction. **Status: PRODUCTION BASELINE — IMPLEMENTATION-READY — AUDIT-READY. P0 = 0, P1 = 0, P2 = 0 unresolved**, with catalog exact-contents (§18.1–§18.3, Appendix D) and the generated `docs/TRACEABILITY.md` (§43.5, including its Requirement ID assignments, owner-field population, and Evidence/Status values) explicitly and honestly carried forward as implementation-phase artifacts rather than invented in this document.*
