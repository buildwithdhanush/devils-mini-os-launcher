# Changelog

All notable changes to this project are documented in this file. The
format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning 2.0.0](https://semver.org/).

## [Unreleased]

### Changed
- Moved the internal `core_logging.sh`, `core_platform.sh`,
  `core_security.sh`, `core_config.sh`, `core_state.sh`, `core_catalog.sh`,
  `core_ui.sh`, and `devils_self_update.sh` files out of `modules/` into a
  new top-level `core/` directory, so `modules/` holds exactly the 14
  PRD-defined module files and nothing else. These were never feature
  modules (not in `DEVILS_MINIOS_FEATURE_MODULES`, not reachable via
  `--run-module`); only their on-disk location changed. Updated every
  `source` path that pointed at them (`modules/core.sh`'s
  `_load_core_split_files()`, `devils-minios.sh`'s `_source_self_update()`,
  `install.sh`'s source validation/staging/activation, and
  `test/lib/harness.sh`'s sandbox setup) so the launcher, installer, and
  test suite all continue to work exactly as before. No behavior,
  function, or security control changed — only file locations and the
  `source`/`cp` paths that reference them.

### Fixed
- Corrected the §14 startup sequence so persistent state/configuration are loaded and validated before the runtime context and feature modules, and session CLI overrides are applied before onboarding/dispatch.
- Enforced `--offline` at every network-capable application/distro installation boundary covered by §15.1; local launch, backup/restore, ADB, catalogs, health checks, and startup diagnostics remain available offline.
- Made `--debug` a real session-level DEBUG override before onboarding/dispatch without persisting `log_level=DEBUG`.
- Added direct release-gate coverage for all lifecycle conflict pairs, uninstall-state enforcement, Safe Mode precedence, crash-loop routing/non-bypassability, runtime-context non-persistence, and the §18 catalog cardinality/schema checks.

- `SHA256SUMS` incorrectly included `data/reports/report.md`, which
  `test/test_report_generator.sh` regenerates (with a fresh timestamp) on
  every test run (see `docs/DATA.md`). Since the manifest is meant to
  detect corruption/tampering of static release payload files (§30.2,
  §30.5), a routine test run made `sha256sum -c SHA256SUMS` report a false
  mismatch for this one entry even though nothing was tampered with.
  Removed `data/reports/report.md` from `SHA256SUMS`; no other entry
  changed. `install.sh --verify` / self-update integrity checks are
  unaffected since the report was never runtime-consumed.
- ShellCheck SC2034 on 15 global constants in `modules/core.sh`
  (`DEVILS_MINIOS_CONFIG_VERSION`, `STATE_VERSION`, `CONFIG_FILE`,
  `STATE_FILE`, `STATE_BACKUP`, `ALLOWED_THEMES`, `ALLOWED_BANNERS`,
  `ALLOWED_DESKTOPS`, `PERSISTED_CONFIG_KEYS`, `PERSISTED_RUNTIME_FACTS`,
  `STATE_KEYS`, `LOG_MAX_BYTES`, `LOG_ROTATIONS`, `LOG_RETENTION_DAYS`,
  `SAFETY_MARGIN_BYTES`): each is a legitimate cross-file global consumed
  only by `core/*.sh` (loaded dynamically at runtime via a variable path
  that ShellCheck cannot follow, even with `-x`) or by `modules/*.sh` /
  `test/*.sh`. Added narrowly-scoped `# shellcheck disable=SC2034` comments
  with a stated reason, matching the suppression pattern already
  established elsewhere in this file (e.g.
  `DEVILS_MINIOS_OFFICIAL_REPOSITORY_URL`). No value, behavior, or
  security control changed.
- ShellCheck SC2154 on the two `DEVILS_MINIOS_STATE[last_successful_workflow]=...`
  writes in `modules/termux_apps.sh`: these already carried a suppression
  comment, but it disabled the wrong code (`SC2034` instead of the actually
  reported `SC2154`), so it never silenced the real warning. Corrected the
  directive to `SC2154` with an updated justification (the global
  associative array is declared in `modules/core.sh`, sourced by the
  loader before this module runs, which ShellCheck's per-file/no-dynamic-
  source-following analysis cannot see). No behavior change.
- `modules/core_security.sh::_dangerous_arguments_rejected()` contained a
  `case` statement reimplementing the shell-metacharacter denylist using
  quoted-glob patterns (`'$('*`, `')'*`, etc.). The unescaped parentheses
  inside quoted case-pattern arms produced real ShellCheck parser errors
  (SC1072/SC1073/SC1085/SC1124), and several arms were prefix-anchored
  rather than "contains anywhere" (e.g. `'&&'*` matched `&&foo` but not
  `foo&&bar`), making this secondary check strictly *weaker* than the
  primary one. `execute_structured()` already runs the PRD §23.1-authoritative
  `DEVILS_MINIOS_SHELL_DENYLIST_PATTERN` regex (`_validate_no_metacharacters()`,
  defined once in `core.sh`) against every argument and action before this
  function is reached, and that check matches the same characters anywhere
  in the string. The redundant, buggy case block was removed; the rm/dd/mkfs
  dangerous-target checks in the same function are unchanged. Net effect:
  the parser errors are fixed at the source (no suppression added) and
  validation coverage is unchanged or improved, never weakened.
- `install.sh::_check_install_storage()` no longer aborts the entire
  installer under `set -e` when `df` cannot be queried (e.g. before the
  target directory exists); it now falls back to its intended
  "cannot determine storage; proceeding with caution" warning path.
- `install.sh` now copies itself (`install.sh`) into the activated
  installation directory, so `install.sh --verify` no longer reports a
  spurious failure for the `./install.sh` manifest entry, and a later
  reinstall-in-place / self-update has an `install.sh` to re-run from the
  active installation.
- Four test files (`test_android_tools.sh`, `test_file_mgr.sh`,
  `test_linux_env.sh`, `test_log_viewer.sh`) referenced their target
  module via the relative path `modules/<name>.sh`, which only resolved
  when invoked from the repository root; fixed to resolve against
  `${DMOS_PROJECT_ROOT}` so each file passes regardless of the caller's
  working directory.

### Added
- `test/test_install.sh` — installation lifecycle coverage (Git/ZIP-shaped
  sources, existing-installation policy, installer-owned deletion boundary,
  self-source-overwrite guard, `--verify`, and the uninstall lifecycle),
  completing the mandatory 19-file test suite.
- `test/test_report_generator.sh` — runs the other 18 mandatory test files
  and writes `data/reports/report.md`.
- `docs/INSTALL.md`, `docs/MODULES.md`, `docs/TROUBLESHOOTING.md`,
  `docs/COMPATIBILITY.md`, `docs/SECURITY.md`, `docs/DATA.md`.

### Removed
- Stray empty `tests/`, `db/`, and `core/` directories left over from
  earlier scaffolding; not part of the repository structure and
  unreferenced by any code path.

## [1.0.0] — Baseline

- Initial production baseline: 14 modules, installer, 17 of 19 mandatory
  test files, four data catalogs (`proot_distros.db`, `proot_apps.db`,
  `desktops.db`, `termux_apps.db`), Safe Mode, crash-flag lifecycle,
  structured command execution, and the full PRD-specified state machine.

<!--
Release notes for tagged releases should additionally state: compatible
Termux versions, any breaking changes, migration steps, and SHA-256
checksums for the release artifacts (see docs/SECURITY.md).
-->
