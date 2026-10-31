# Kimi Master Prompt — Devil’s Mini OS Launcher v1.0.0
## Full PRD-6.2 Audit, Complete Repair, Regression Verification, and Repaired ZIP Delivery

> **Execution mode:** `FULL_REPAIR_AND_VERIFICATION`  
> **Not an audit-only task. Not a minimal-fix-only task.**  
> Audit is the evidence-gathering stage; the required outcome is a fully repaired, tested source package that conforms to PRD-6.2 as far as can be established with available tools.

---

## 1. Role and mission

Act as the principal Bash systems engineer, Termux/Android compatibility engineer, application-security engineer, test architect, release engineer, and technical auditor for **Devil’s Mini OS Launcher v1.0.0**.

Your responsibility is to take the supplied source ZIP, inspect it **completely**, map its implementation against the whole normative specification, repair all confirmed defects and missing required behavior, add or correct regression tests, run every feasible verification gate, and deliver a new repaired source ZIP with the **complete final audit-and-repair report embedded inside that ZIP**.

Do not stop after identifying problems. Do not return only recommendations, a checklist, a patch, or a report. Apply the code, test, configuration, catalog, traceability, packaging, and documentation changes needed to deliver the complete PRD-conforming project. The scope of changes is not restricted to minimal diffs: make substantial corrections or restructure implementation where required to achieve the specified behavior. Keep all changes within the approved PRD-6.2 architecture and product scope; do not invent new features or weaken requirements to make tests pass.

Work autonomously. Do not ask the user to approve ordinary code repairs, test changes, report structure, or packaging decisions. Never perform actions against the phone’s installed launcher, live user configuration, or live user data. Work only on a disposable extracted source tree. Ask for permission only before an action that truly requires user consent (for example, installing a system package in a user-owned environment or a destructive action outside the disposable workspace). Prefer the available local tools and existing dependencies; avoid introducing new runtimes.

### Required deliverables

1. **A repaired source ZIP** containing the complete source tree and the additional file `docs/FULL-AUDIT-AND-REPAIR-REPORT.md`.
2. The final ZIP’s `SHA256SUMS` manifest regenerated after every source/report change and verified against the packaged contents. The generated artifact policy must be explicit and must not hide unrelated files.
3. A single updated executable `prd62-master-test.sh` that locates the source ZIP alongside itself by default, validates the exact archive hash, runs the complete gate sequence, performs ShellCheck on every project `.sh` file, preserves check exit codes, and generates a Markdown report plus per-check logs.
4. An external copy of `FULL-AUDIT-AND-REPAIR-REPORT.md` and a concise delivery manifest containing the final source ZIP SHA-256. Do not embed the final archive SHA-256 inside a file included in that same archive, because that would create a self-referential hash problem. Put the archive hash in the **outer delivery package**.
5. Evidence logs showing commands, tool versions, output, exit status, test counts, and blocked/timeout gates. Deliver a ZIP handoff package that includes the repaired source ZIP, master runner, full report, final logs, and a top-level checksum file.

If a gate cannot actually be performed, label it `Needs Verification` or `Blocked` and record the exact evidence still missing. Never manufacture output or claim success without a fresh command result.

---

## 2. Inputs and source-of-truth authority

The provided handoff ZIP contains:

- `INPUTS/PRD-6.2.md` — sole normative specification.
- `INPUTS/devils-mini-os-launcher-PRD62-repaired-2026-10-25.zip` — current source candidate to start from.
- `INPUTS/previous-prd62-master-test.sh` — prior test runner supplied as historical implementation to inspect and correct; **do not assume it is correct**.
- `EVIDENCE/` — the user’s prior Termux output, older ShellCheck diagnostics, older suite logs, and prior reports.

### Authority order

1. Current user instruction.
2. PRD-6.2 normative text.
3. PRD-6.2 implementation and traceability references.
4. Actual source code and tests after independent inspection.
5. Prior logs/reports as historical evidence only.
6. General engineering judgment.

Read the **entire** `PRD-6.2.md`, not just excerpts or this prompt. Search and trace every normative “must”, “must not”, required contract, invariant, status, error code, gate, and referenced section. This prompt is an execution aid; it does not override the PRD. If the PRD does not specify behavior, explicitly say `Not specified by PRD-6.2`. If evidence is insufficient, use `Needs Verification`. Do not silently invent a requirement or reinterpret a contradictory one.

### Starting source identity

The supplied candidate `devils-mini-os-launcher-PRD62-repaired-2026-10-25.zip` was recorded with SHA-256:

`7153aa696970676b354ffea17a00cb039bd6931bed02d595701e9a66f60d5635`

Recompute the hash yourself. If it differs, stop processing that file, report the mismatch, and identify which exact supplied file you are using. Do not silently substitute another source ZIP from older evidence.

---

## 3. Product invariants that must not be violated

Apply the PRD’s full detail. At minimum, preserve and verify all of these invariants:

- Platform: Termux on Android only, Android API 29+; architectures `aarch64` and `x86_64`; Bash >= 4.3, 5.x preferred.
- Pure Bash launcher. Rootless. No Python, Node.js, Go, Rust, or compiled launcher runtime components.
- No `curl | bash`, `wget | bash`, `eval`, `sh -c`, `bash -c`, or equivalent dynamic shell interpretation.
- Every `.sh` file must be **strictly below 500 lines**.
- Main entry is `devils-minios.sh`.
- Exactly these 14 active modules: `core.sh`, `linux_env.sh`, `file_mgr.sh`, `termux_apps.sh`, `proot_apps.sh`, `android_tools.sh`, `workspace.sh`, `health_check.sh`, `log_viewer.sh`, `customize.sh`, `system_tools.sh`, `system_info.sh`, `update_all.sh`, `settings.sh`.
- Never create, reference, load, or describe `future_plans.sh` as an active implementation file.
- Core is the owner of shared platform/config/state/logging/security/recovery/UI/validation/structured execution. Use the central `validate_path()` and `execute_structured()` contracts; do not bypass them with ad hoc command construction.
- Prevent command injection, path traversal, unsafe shell evaluation, arbitrary repository/host redirection, unsafe installer deletion, unvalidated catalog execution, and unsafe external-storage execution.
- Strict schema-controlled configuration; reject duplicate, unknown, malformed, or invalid keys. Writes are atomic. Runtime context is not persisted.
- Catalog/data values are data, never shell code. Validate schemas before using catalogs. A corrupt feature catalog should only degrade the affected feature when PRD-6.2 permits that behavior.
- One existing structured logging system. Core owns log mutation. `log_viewer.sh` is read-only. Respect retention/rotation requirements.
- Recovery lifecycle includes `FIRST_BOOT`, `ONBOARDING`, `IDLE`, operational states, `RECOVERY`, `SAFE_MODE`, and `UNINSTALLED`. Three crashes within ten minutes lead to `SAFE_MODE`; stale crash flags older than 24 hours are cleared without forcing Safe Mode; malformed crash flags lead to Safe Mode; flags must not bypass crash-loop/recovery protections.
- Configuration reset, state reset, nuclear reset, and uninstall remain distinct operations.
- `--offline` must never silently perform network operations. `--no-checks` only bypasses diagnostics explicitly permitted by the PRD; it never bypasses security, compatibility, config validation, destructive confirmation, crash handling, or Safe Mode.
- Installation is inspectable, validated, staged, and safely activated. Installer deletion is restricted to paths created and recorded by that installer run.
- Updates require the PRD trust anchor, HTTPS, stable SemVer, verification, atomic activation, migration when required, and rollback on activation failure. Network/update failure must leave the active install untouched.
- Uninstall respects the PRD state restriction and preserves required user data/config/state/Proot environments.
- No plugins, Nix, background health daemon, recent-actions, i18n implementation, compiled components, unsupported runtimes, root automation, native Linux support, GNOME/KDE Plasma, or script-based application installation unless PRD-6.2 explicitly permits it.

These are the baseline, not a complete replacement for reading the PRD.

---

## 4. Read the evidence correctly; do not merge different builds

The handoff includes failures from **different hashes and different runs**. Treat each result as attached to its exact archive hash; do not combine older success numbers with a different current source candidate.

### Evidence A — Android manifest failure

A user run of hash `cccfbc701540f6351c39e2fbcde02e0abd17b141143ad440aa44fcc5b802456e` failed manifest completeness because `data/reports/report.md` was present as a generated output even though it was not a static manifest entry. The user’s log showed all listed checksum entries passing, then an exact static-file-list mismatch. That run halted at check 6; it provides **no** ShellCheck or full-suite result for that archive.

### Evidence B — Android ShellCheck failure on another archive

A different user run of hash `3684d00b9d6d791bb7ee9bddc583c8e60784cfaacf94a1b07b3fa459470ef930` passed manifest completeness, syntax, structure, traceability, catalog cardinality, security smoke checks, CLI smoke checks, and the mandatory suite (`19/19` files; `918/918` assertions). However, ShellCheck 0.11.0 failed with:

- `SC2016` in `test/test_report_generator.sh` line 100 for a literal Markdown string with backticks.
- `SC2034` in `core/core_config.sh` line 427 for the associative array `candidate` passed by name to helper functions.

Overall outcome was `AUTOMATED RESULT: FAIL`. The successful suite does not turn that run into a pass.

### Evidence C — older 21-diagnostic ShellCheck log

`EVIDENCE/SHELLCHECK-OLDER-BUILD-21-DIAGNOSTICS.log` contains a longer findings list from an older build. It includes possible real defects such as the `candidate` array/string type confusion (`SC2178`/`SC2128`), cross-file global variables, unused locals, `SC2016`, and `grep | wc -l` patterns (`SC2126`). Treat this as a **historical lead list**, not proof that every listed finding remains in the current source. Re-run ShellCheck on the exact starting candidate and inspect current source before deciding each fix.

### Required response to evidence

Reproduce each relevant failure against the current candidate, diagnose the actual cause, fix it fully, and add regression coverage. The report must identify the archive hash for every test run. Do not write “fixed” merely because source text looks different. Fresh output and exit status are mandatory.

---

## 5. Full audit scope — inspect every file and every normative requirement

Perform a repository-wide, line-by-line audit. Do not sample only the files mentioned in logs. Inventory and inspect:

- Entry points, installer/uninstaller/update logic, every active module, all files under `core/`, and all shell helpers.
- Every mandatory and supplemental test file, test fixture, harness function, test runner, report generator, and traceability validator.
- All configuration defaults/schemas, state/recovery definitions, catalogs, catalog schemas, data files, checksum manifests, generated outputs, and packaging exclusions.
- All workflows/CI scripts, developer instructions, PRD gap register, traceability document, README, install documentation, compatibility/security/module docs, changelog, and release instructions.
- File permissions, symlinks, path traversal opportunities, executable bits, line limits, dynamic-shell patterns, privilege escalation, hidden dependencies, stale files, accidental generated artifacts, archive layout, and installer-owned path tracking.
- Reachability and actual invocation paths. File presence, comments, documentation, a traceability row, or an earlier report are not implementation proof.

Build a requirement matrix covering **every applicable normative requirement** in PRD-6.2. Use this finding classification in the audit report:

- `Implemented`
- `Partial`
- `Missing`
- `Incorrect`
- `Needs Verification`

For each requirement/finding record:

1. Exact PRD section/requirement wording or a precise faithful summary and identifier.
2. Actual code evidence, including file paths, functions, and relevant lines.
3. Verification command/test and the real result.
4. Classification.
5. Defect impact/risk.
6. Implemented repair and regression test, or the exact evidence still needed.

The separate `docs/TRACEABILITY.md` must use only its valid statuses: `Verified`, `Partial`, and `Not Verified`. `Verified` requires qualifying implementation **and** verification evidence. Do not let the audit classification silently replace the PRD’s traceability vocabulary. Recompute status totals from the final document; never hand-edit only the summary totals.

---

## 6. Full repair approach — implementation is mandatory

Use this complete engineering loop. More extensive changes are allowed when required; do not stop at the smallest diff if it leaves PRD behavior missing or incorrect.

1. **Inventory and fingerprint** the source ZIP. Validate path safety, ZIP integrity, expected single root, manifest coverage, symlinks, file types, and initial SHA-256. Extract to a new private working directory; never edit the input ZIP or active installation.
2. **Read all of PRD-6.2** and extract a comprehensive requirement checklist. Reconcile each requirement to its expected implementation and verification evidence.
3. **Run a baseline** on the exact extracted candidate: all existing tests that are safe to run, syntax checks, ShellCheck on every `.sh`, static/security checks, traceability validation, CLI smoke checks, and packaging/manifest checks. Capture stdout/stderr and exit code per command. Do not stop auditing after the first failure; record the whole baseline where safe.
4. **Trace root causes across the codebase.** Follow call chains, globals, shell scoping, namerefs, config/state paths, runner logic, and test subprocess return codes. Do not infer behavior from names/comments alone.
5. **Implement complete repairs.** Fix missing or incorrect PRD behavior, real ShellCheck findings, test harness false greens, config/state/security/recovery/update issues, docs/traceability mismatch, and packaging defects. Update or add regression tests for every repaired defect. Broader refactoring is allowed when needed to produce correct, understandable, testable code inside the mandated architecture.
6. **Do not weaken tests to pass.** Do not lower ShellCheck severity, omit difficult files, skip failed test files, hardcode historic assertion counts, mock away the behavior being tested, or add blanket suppressions. Keep narrow documented suppressions only when code inspection proves a true analysis false positive.
7. **Preserve security and lifecycle invariants.** Never bypass `validate_path()`/`execute_structured()`, disable recovery guards, alter PRD thresholds, broaden package/network operations, or weaken destructive confirmation for test convenience.
8. **Update all dependent artefacts.** Keep catalogs, docs, CI, traceability, checksums, installer logic, and tests consistent with the actual repaired implementation. Regenerate `SHA256SUMS` after all final static-file changes, including the embedded full audit report.
9. **Run targeted tests after each functional repair**, then the full suite and all applicable regression gates. Fix all failures and repeat the complete relevant test loop. Keep individual logs and exit status.
10. **Package and validate the exact final bits.** Create the repaired source ZIP, validate archive paths and `unzip -t`, re-extract to a fresh directory, verify `SHA256SUMS`, static-file completeness, script line limits, ShellCheck, traceability and full tests against that extracted ZIP. Compute the final archive hash after packaging; write it to a separate external delivery checksum file.
11. **Write the final report after the implementation/test evidence is known**, include it in `docs/FULL-AUDIT-AND-REPAIR-REPORT.md`, update `SHA256SUMS`, then re-run every check affected by that final report/manifest modification and repackage the final archive. Do not claim the archive passed if only the pre-report tree was tested.
12. **Final clean-room repeat.** Extract the final ZIP one last time into a new directory and re-run the final release gate suite against that exact extracted tree. Report the actual final archive SHA-256 and final gate table.

If a test exceeds its runtime, terminate its process tree, record `TIMEOUT`, investigate and retry with a bounded adjusted timeout. Do not leave background test processes running. A timeout is never a pass.

---

## 7. Mandatory verification gates

Every gate must be run or be explicitly marked blocked/Needs Verification with reason and exact next evidence. Capture full output and actual exit code.

### Archive, manifest, and integrity

- Input and output ZIP SHA-256; `unzip -t`; reject absolute paths, `..` traversal, backslashes/drive-prefixed paths, unexpected roots, duplicate paths, symlinks or special files where unsafe.
- `sha256sum -c SHA256SUMS` for all entries.
- Exact static-file completeness comparison: every static source/document/config/catalog file is represented exactly once, no missing or extra unaccounted static files.
- Handle only generated artifacts expressly specified by PRD-6.2. For the known generated `data/reports/report.md`, inspect PRD §43.1 and actual report-generator behavior, then use a precise policy: preferably exclude/remove it from the clean source package and regenerate it during tests; if completeness excludes it, exclude only this exact path and fail on every other unexpected path. Never ignore the whole `data/` or `reports/` directory. If final `docs/FULL-AUDIT-AND-REPAIR-REPORT.md` is static documentation, include it in `SHA256SUMS`.
- Verify report generation does not leave the source tree/manifest in an inconsistent state. State clearly if the generated report is included in output or generated only in the test workspace.

### Shell syntax, style, and structure

- `bash -n` every `.sh` file recursively, including test fixtures, validators, harnesses, scripts and helper files.
- ShellCheck all `.sh` files with default error, warning, and info severities; zero remaining findings. Record version, file count, output, exit code, and diagnostics.
- Strictly fewer than 500 lines per `.sh` file; count final files after the report is added.
- Exactly 14 active modules with the exact names in section 3; exactly 19 mandatory test files plus the established runner as defined by the PRD; no `future_plans.sh` file/reference/load.
- Check that the launcher remains Bash-first/pure Bash and that no prohibited runtime or scope creep was added.

### Functional/security verification

- Run `bash test/run_all.sh` in the project root with the full mandatory suite. The exact PRD-defined suite must run, each subprocess must return status 0, and the final summary must reflect actual result counts.
- Add a regression proving that a test process exiting non-zero cannot be marked passed solely because its output includes `ALL TESTS PASSED` or `918/918`; use actual exit code and per-test status.
- Traceability schema/ID/field/owner/status/total validator; independently verify totals.
- Catalog schema and cardinality per PRD: 8 Tier-1 desktops, 40 Proot application entries, and 30–40 Termux app entries (re-read PRD to verify exact applicable conditions).
- Security scans and code review of injection, path traversal, external storage, central validators, structured executor, no dynamic `eval`/`sh -c`/`bash -c`, installer deletion ownership, config validation/atomic writes, state machine, crash-loop protections, uninstall state restriction, update trust anchor, HTTPS, SemVer, integrity verification, atomic activation, migration, and rollback.
- CLI `--version` and `--help` smoke tests without install/update/network side effects.
- CI/workflow validation: ensure the workflow actually runs the checks it claims to run; parse the workflow and execute locally compatible steps.
- Post-test checksum integrity, generated report correctness, clean extraction and exact archive-content validation.

### Release gates beyond a single device

A single `aarch64` phone run does not prove `x86_64` coverage, manual Android acceptance, cold-start and RSS targets, hosted CI behavior, update network/rollback edge cases or other PRD-defined release gates. Run them when tools/environments support them. Otherwise mark them `Needs Verification`, name the missing environment/action, and give exact evidence needed. **Never call v1.0.0 FINAL while any applicable release gate remains unsatisfied.**

---

## 8. Master test runner requirements

Repair or replace `prd62-master-test.sh` so it is a reliable one-command gate driver for the actual final deliverables.

- By default, locate the expected source ZIP **relative to the runner’s own directory**, not a hardcoded old path under `$HOME/storage/downloads`. Support an explicit `DMOS_TEST_ZIP` override.
- Verify the SHA-256 pinned to the exact matching source ZIP. Avoid stale constants and duplicate archive names. If mismatch, stop before extraction and show expected/actual hashes.
- Never touch an installed launcher or live user data; use a fresh private workspace.
- Run the complete check list in a coherent order. Every check records `PASS`, `FAIL`, `BLOCKED`, or `TIMEOUT`, command/output, log path, exit code, and elapsed time.
- Never use `printf` output as a substitute for executing a check. Never infer success by matching a summary string when the test process exit code is non-zero.
- ShellCheck must examine all `.sh` files, and the runner must record ShellCheck version and findings. A missing ShellCheck binary may only be installed after explicit user consent if the run environment is Termux; no silent network/package operation. If installation is not approved or unavailable, mark ShellCheck `BLOCKED`, not `PASS`.
- Generate one complete Markdown master report and individual per-check logs. Include archive SHA-256, environment, file count, test counts, and honest remaining gates.
- Exit zero only if every required automated gate passes. Any required fail/blocked/timeout must result in non-zero overall status. Do not call a failed run `ALL TESTS PASSED`.
- Keep the runner itself under 500 lines and include it in ShellCheck and Bash syntax checks.
- Do not assume any previously hardcoded test count/assertion total remains constant; use the actual suite output and explain material changes.

---

## 9. Required output: full report inside the repaired source ZIP

Create `docs/FULL-AUDIT-AND-REPAIR-REPORT.md` within the actual repaired source tree. This must be a completed evidence report, not a blank template or the previous report copied unchanged. It must include:

1. Executive summary and exact starting/final source ZIP hashes (keep final archive hash in external delivery manifest to avoid self-reference).
2. File inventory and observed baseline architecture.
3. Complete PRD-6.2 requirement matrix, including relevant section/ID, implementation file/function/line evidence, test/command evidence, classification, repair, and remaining requirement.
4. Complete finding register with severity/impact and root cause.
5. Every code/test/doc/catalog/CI/manifest/runner repair, including paths changed and rationale.
6. ShellCheck version, files scanned, exact result, and each diagnostic fixed or remaining. A claim of clean requires an actual zero-exit run on the final extracted ZIP.
7. Bash syntax, line-limit, security, traceability, catalog, CLI, full suite, archive, checksum, and post-package test outcomes, with real test counts and exit codes.
8. Test-run identity and source hash for each result so evidence from old ZIPs is not mixed with current evidence.
9. Release gate table with `PASS`, `FAIL`, `BLOCKED`, or `Needs Verification`; for unperformed Android/architecture/hosted-CI/performance checks, explain exactly what is not proven and what evidence is required.
10. A final status that does not overstate readiness. If any applicable gate remains, say `NOT FINAL — RELEASE GATES REMAIN` and enumerate them.

Update `docs/TRACEABILITY.md` to be evidence-based. Use PRD-valid statuses `Verified`, `Partial`, `Not Verified` there. Do not mark a requirement `Verified` based only on a source comment, file existence, or unexecuted test. Keep summary totals synchronized with actual table data.

---

## 10. Few-shot examples (required behavior patterns)

These examples illustrate the expected depth and decision process. They are not substitutes for inspecting actual files.

### Example 1 — generated artifact causes manifest mismatch

**Input evidence:** every `sha256sum -c SHA256SUMS` entry is `OK`, but static-file completeness fails because the only extra path is `data/reports/report.md`.

**Incorrect response:** “Exclude the entire `data/` folder from the manifest check”, “ignore all unmatched files”, or “the run is mostly passing”.

**Correct analysis and action:** inspect PRD §43.1 and the real report generator. Treat only the explicitly generated `data/reports/report.md` as generated output. Prefer a clean source archive without the stale artifact; let the test regenerate it inside the test workspace. Make static completeness compare every other path exactly. If any additional file is unmatched, fail and print the exact path. Add a regression test for both the permitted generated file and an arbitrary extra file. Regenerate checksums, repackage, re-extract, and rerun the completeness test on the exact final ZIP.

### Example 2 — ShellCheck `SC2016` on literal Markdown with backticks

**Input evidence:** a `printf` argument contains literal backticks intended for generated Markdown.

**Incorrect response:** globally disable `SC2016`, disable all ShellCheck rules, or delete the backticks from the produced report.

**Correct analysis and action:** preserve exact output and remove the warning using a clearly literal-safe argument—for example, double-quoted text with the backticks escaped where Bash semantics support it, or a concise one-statement suppression when justified and unavoidable. Add/adjust the report-generator test to assert the exact generated line. Run ShellCheck on all `.sh` files and run the report-generator regression. Zero findings must be verified on the final tree.

### Example 3 — ShellCheck `SC2034` on a Bash associative array passed by name

**Input evidence:** `candidate` is a local associative array passed by its variable name into parser/validator helpers, which use `local -n` namerefs. ShellCheck may not infer that interprocedural use.

**Incorrect response:** delete `candidate`, convert it into a scalar without checking callers, add `# shellcheck disable=SC2034` to the entire file, or declare the warning resolved without a new ShellCheck run.

**Correct analysis and action:** trace the declaration through every helper call and prove how the array is read/written. Fix any genuine scalar/array name collision or misuse (including possible `SC2178`/`SC2128` defects). For a remaining proven false positive, apply a single-statement suppression directly to the relevant declaration, with a comment naming the by-name/nameref contract. Add or run config load/validation regression tests. Run ShellCheck against the exact final ZIP.

### Example 4 — a test prints success but exits non-zero

**Input evidence:** a fixture prints `ALL TESTS PASSED` and `918/918`, then exits with status `23`; the wrapper currently marks it as passed.

**Incorrect response:** parse the success text and report pass, suppress the fixture failure, or lower the exit code.

**Correct analysis and action:** treat the process exit code as authoritative. The wrapper must fail the test even if its output contains passing-looking text; record the output and `exit 23`. Add a permanent regression fixture and rerun the runner test plus the full 19-file suite. A green textual summary never overrides a non-zero status.

### Example 5 — a PRD gate cannot be proven on the current device

**Input evidence:** the only accessible hardware is an Android `aarch64` phone; the PRD also requires `x86_64` coverage and manual acceptance.

**Incorrect response:** mark both architectures verified because the launcher is Bash, or call the release final because the phone’s tests passed.

**Correct analysis and action:** complete every feasible repair/test, then report `aarch64` evidence separately. Mark `x86_64` and manual acceptance as `Needs Verification`, provide the exact required environment/test/action, and do not claim `v1.0.0 FINAL` until those release gates have evidence.

### Example 6 — an old report says a fix passed but source hash changed

**Input evidence:** an older ZIP passed 918 assertions; a new ZIP has a different SHA-256 and fails ShellCheck.

**Incorrect response:** combine the previous suite result with the current ShellCheck result and declare the new build green.

**Correct analysis and action:** associate every run with an exact source/archive hash. Run the full suite and ShellCheck on the same final extracted ZIP. Only evidence produced for the final hash qualifies for final claims.

---

## 11. Definition of done

The task is complete only when all of the following are true:

- The whole source ZIP and full PRD-6.2 have been inspected, not merely the known failure locations.
- All repairable PRD-conformance defects are actually implemented; all related tests and docs are consistent.
- Every `.sh` file passes `bash -n`; all are below 500 lines; ShellCheck scans all of them with zero findings.
- The full mandatory suite passes with every child test process exiting zero; regression tests cover repaired failures.
- Manifest integrity and exact coverage pass on the final clean extraction; only PRD-authorized generated outputs are handled specially.
- Architecture/module/catalog/security/traceability/CLI and runner checks pass.
- The actual final source ZIP has been re-extracted and the release gates rerun against it after the embedded full report and regenerated manifest are present.
- The repaired source ZIP includes `docs/FULL-AUDIT-AND-REPAIR-REPORT.md` and updated `SHA256SUMS`.
- The external delivery has the exact final archive hash and logs.
- All remaining untestable gates are clearly marked and do not get mislabeled as passing.
- No installed launcher or live user state was modified.

If work is lengthy, continue autonomously through code changes, regression testing, packaging, and validation. Do not stop after a plan or an audit. If a tool or environment limitation blocks one gate, finish all other available tasks, provide the exact evidence and retry path, and do not fabricate a clean release claim.

---

## 12. Final response format

Deliver concise links to:

1. `Devils-MiniOS-Launcher-PRD62-FULL-REPAIRED.zip` — repaired source ZIP with embedded `docs/FULL-AUDIT-AND-REPAIR-REPORT.md`.
2. `prd62-master-test.sh` — single master test harness.
3. `FULL-AUDIT-AND-REPAIR-REPORT.md` — external copy of the embedded report.
4. `DELIVERY-SHA256SUMS.txt` — exact output archive hash.
5. `verification-logs.zip` — logs for the final exact archive hash.

Summarize actual results with counts and statuses. Explicitly say whether the full release is `FINAL` or `NOT FINAL — RELEASE GATES REMAIN`. Do not substitute prose for deliverable files. Do not claim tests passed unless final command output proves they passed.
