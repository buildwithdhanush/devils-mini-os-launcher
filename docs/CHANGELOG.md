# Changelog

All notable changes to this project are documented in this file. The
format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning 2.0.0](https://semver.org/).

## [Unreleased]

### Fixed
- Fixed `test/run_all.sh` to treat a non-zero test-process exit as a failed test even when the child printed a passing-looking assertion summary. Added a regression fixture to `test/test_report_generator.sh` that returns exit 23 after printing a zero-failure summary and requires the aggregate runner to fail.
- Corrected the §43.5 traceability matrix to use all 14 fields in PRD order, normalize nonconforming requirement IDs, split the combined §23.3 requirement row into six independently traceable rows, and refresh schema/status totals. Added `test/validate_traceability.sh` and wired it into CI. Identifier normalization applies only to malformed legacy IDs; the change is recorded here rather than silently treating old spellings as valid.
- Updated `test_utils.sh` traceability assertions from the stale 13-column layout to PRD §43.5.2’s 14 fields and corrected the owner-field indexes so the assertions inspect the three actual owner columns.
- Hardened CI static checks to run `bash -n`, ShellCheck, and the strict `<500`-line gate across every repository `.sh` file.
- Post-repair Linux-container verification: all 19 mandatory test files passed with 918/918 assertions, including the non-zero child-exit regression. ShellCheck and supported-device release gates remain unverified.


### Changed
- Refined the interactive Termux menu for portrait screens: added a large monochrome DEVILS MINI OS banner, a centered boxed menu heading, screenshot-aligned module labels, and a visible Termux-source warning beneath the banner. The display uses no hardcoded color sequences and leaves the user's Termux color palette untouched. The main-menu input prompt now reads `Choice:` and keeps Enter-to-exit behavior.

### Fixed
- Hardened interactive screen clearing by emitting the ANSI home/erase-display/erase-scrollback sequence directly instead of trusting a `tput clear` command that may succeed without clearing the active Termux screen or scrollback. Added a regression test for a successful-but-silent `tput`.
- Fixed Workspace → List workspaces so an empty workspace root displays a helpful empty-state message instead of returning no visible output. Listing now excludes symlinked directories, with regression tests for both cases.
- Fixed System Tools → Clear Cache feedback: successful cache removal now prints a visible confirmation and waits before the menu redraws, instead of only logging success. Also corrected path validation for custom `XDG_CACHE_HOME` values and preserved the caller's `nullglob`/`dotglob` settings. Added tests for visible feedback, the pause, and leaving sibling application caches untouched.

### Changed
- Aligned `docs/INSTALL.md` with PRD §8: generic Linux is a test environment only, not a supported runtime host. Added the required `.gitignore` and reserved `data/banners/` / `data/themes/` directories from §42. Expanded `docs/TRACEABILITY.md` to cover previously unrepresented normative sections and corrected stale state/installer evidence; the release gate remains explicitly blocked by device and performance evidence.
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
- Fixed clean installation activation and active-manifest generation (PRD §§30.2, 30.5). The installer now copies `install.sh` into the active installation and checks every concrete staged file against the active `SHA256SUMS` instead of searching for literal wildcard strings. Generated `data/reports/` output is excluded from the runtime payload because it is test-generated evidence, not runtime data. Added assertions that a fresh install succeeds, the active manifest covers `install.sh`, and `install.sh --verify` succeeds immediately after installation.
- Fixed `execute_structured()` working-directory handling for `sha256sum -c`: manifest verification now preserves the caller-selected directory containing `SHA256SUMS`, matching PRD §23.0-05. This prevents a false E412/CFG-TAMPER Safe Mode entry when the installed manifest is valid but the generic neutral-cwd policy would otherwise make the relative manifest path unresolvable. Added a regression test covering an actual `sha256sum -c SHA256SUMS --status` dispatch through `execute_structured()`.
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
