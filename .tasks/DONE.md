# Done

## TASK-001: Reproduce baseline failures and establish PRD gap register
**Priority:** P0 | **Tags:** audit, tests, prd

Establish a trustworthy implementation baseline before changing behavior. The supplied `data/reports/report.md` reports 13 failed assertions across `test_core.sh` (8), `test_system_info.sh` (4), and `test_integration.sh` (1). Re-run the canonical harness, capture exact failing assertions, inspect the existing `evidence/` and dirty working tree, and map findings to PRD-6.2 requirement IDs without discarding existing work.

### Plan

- Inspect `git status`, current evidence, test harness, and report-generation behavior.
- Run `bash test/run_all.sh` and preserve the complete output/report.
- Reproduce each failure independently; distinguish stale report, test defect, and implementation defect.
- Cross-check findings against `docs/TRACEABILITY.md` and PRD §§43–47.
- Produce a prioritized gap register with evidence, owner role, verification method, and dependency.

### Acceptance

- Exact current test result is recorded; no claim relies solely on the supplied report.
- Every failure is classified and linked to a PRD requirement or test-harness issue.
- Existing user changes/evidence are preserved.

---

## TASK-002: Complete Phase 0 security and architecture alignment
**Priority:** P0 | **Tags:** security, architecture, catalogs

Implement PRD-6.2 §53 Phase 0 only after TASK-001 establishes the baseline: verify absence of removed scope (`future_plans.sh`, plugins, Nix, recent-actions, script install source), validate all four catalog schemas, and close genuine deviations in `proot_distros.db`, `proot_apps.db`, `termux_apps.db`, and `desktops.db`. Preserve the PRD's fixed structured-execution contracts; do not invent catalog records or mark evidence verified without evidence.

### Plan

- Audit repository structure against PRD §§5–13 and §18.
- Validate exact catalog field counts, allowed enums/regexes, architecture filtering, record cardinality, and category coverage.
- Confirm executor boundaries and no dynamic shell interpretation across all execution paths.
- Make minimal targeted changes and add/update regression tests for every fix.
- Regenerate traceability/evidence only from actual verification results.

### Acceptance

- Phase 0 requirements pass static validation and applicable tests.
- Exactly 14 active modules; removed features remain absent.
- Catalogs meet schema and completeness gates or remain explicitly blocked with a documented missing-data dependency.

---

## TASK-003: Harden core runtime, installer, state lifecycle, and CLI
**Priority:** P1 | **Tags:** core, installer, recovery

Implement PRD-6.2 §53 Phase 1: secure separate-install/ZIP install paths and installer deletion ownership; validate entry-point startup ordering and CLI precedence; complete persistent state lifecycle, crash flag, crash-loop protection, safe mode, and rollback behavior.

### Plan

- Map installer/entry-point/state behavior to PRD §§14–16, 26, 30, and 39.
- Implement only verified gaps; preserve idempotence and existing installation/user state.
- Add failure-injection tests for install, update, state corruption, crash recovery, and uninstall.
- Verify `install.sh --verify`, checksums, and installer-owned deletion boundaries.

### Acceptance

- Relevant automated tests pass; critical state transitions match PRD exactly.
- No unsafe remote execution or deletion outside installer ownership.

---

## TASK-004: Align configuration and data-layer contracts
**Priority:** P1 | **Tags:** config, data, migration

Implement PRD-6.2 §53 Phase 2: strict 15-logical-key ownership model, 11 importable persisted configuration keys, refreshed runtime facts, in-memory-only `terminal_width`, atomic writes, schema validation, and migration behavior.

### Plan

- Audit config defaults, grammar, duplicate/unknown/malformed key rejection, and strict import/export.
- Verify runtime facts are refreshed and `terminal_width` is never persisted or imported.
- Validate catalog loading and >5% malformed-record safe degradation.
- Add regression tests for atomicity and migration rollback.

### Acceptance

- Configuration and all catalog readers conform to PRD §§17–18 and §32.
- Corrupt/invalid imports leave active configuration untouched.

---

## TASK-005: Complete Proot, desktop, and onboarding workflows
**Priority:** P1 | **Tags:** proot, desktop, onboarding

Implement PRD-6.2 §53 Phase 3: runtime distro discovery, distro install/launch/backup/restore, eight Tier-1 desktop definitions, validated per-distro xstartup generation, systemd acknowledgement, and beginner-first onboarding.

### Plan

- Trace workflows against PRD §§18.1, 18.4, 23, 27, 35, and 45.
- Verify each desktop startup binary and literal-argument allowlist.
- Exercise installed/missing distro and offline paths.
- Add automated tests and document device-only acceptance still pending.

### Acceptance

- All automatable Proot/desktop/onboarding tests pass; unsupported paths fail clearly.
- No free-form startup command or unsafe shell interpretation exists.

---

## TASK-006: Complete app catalogs, Android tools, and workspace workflows
**Priority:** P1 | **Tags:** apps, android, workspace

Implement PRD-6.2 §53 Phase 4: Termux and Proot app install paths, pinned GitHub artifacts with SHA-256 verification, architecture/compatibility filtering, optional Termux:API behavior, and workspace-root enforcement.

### Plan

- Verify 40 Proot apps, 30–40 Termux apps, all required categories, and exact catalog schemas.
- Verify `pkg`, Proot package-manager, and GitHub artifact flows use structured argument arrays.
- Test network/offline failure and checksum mismatch paths.
- Test ADB/fastboot and Termux:API present/absent handling.
- Verify workspace paths cannot escape `$HOME/devils-minios/workspaces/`.

### Acceptance

- Catalog and installation security tests pass; failed downloads/checksums leave no partial install.
- Optional capabilities degrade gracefully and never imply root support.

---

## TASK-007: Complete diagnostics, logging, customization, and maintenance modules
**Priority:** P2 | **Tags:** modules, logging, ux

Implement PRD-6.2 §53 Phase 5: health checks/cache, single-owner structured logging and rotation, log viewer navigation/export, customization idempotence, system tools, system information, and ordered/dry-run updates.

### Plan

- Audit each module's public contract and error-code behavior.
- Validate log locking, rotation, retention, JSON/text output, and viewer read-only boundaries.
- Verify UI Full/Compact/Minimal modes and Exit navigation.
- Test maintenance operations, confirmations, and update failure reporting.

### Acceptance

- Module tests pass and all mutating logging operations remain centralized in core.
- No background daemon or removed v1.0.0 scope is introduced.

---

## TASK-008: Make the 19-file test suite and CI release-ready
**Priority:** P1 | **Tags:** tests, ci, reliability

Implement PRD-6.2 §53 Phase 6 after prior phases: ensure all 19 mandatory test files run via `bash test/run_all.sh`, edge cases are covered, the report generator is deterministic, and CI gates syntax, security constructs, structure, catalogs, checksums, and tests on `aarch64`/`x86_64` where available.

### Plan

- Reconcile test inventory with PRD §43.1 and the harness.
- Fix product defects before weakening or changing assertions; justify any test corrections with PRD evidence.
- Add missing §43.3 edge cases and test critical workflows from §45.1.
- Run full suite and static checks from a clean checkout.
- Keep device-only acceptance distinct from CI evidence.

### Acceptance

- All mandatory automated tests pass with complete output retained.
- Report counts and generated artifacts match the actual run.

---
