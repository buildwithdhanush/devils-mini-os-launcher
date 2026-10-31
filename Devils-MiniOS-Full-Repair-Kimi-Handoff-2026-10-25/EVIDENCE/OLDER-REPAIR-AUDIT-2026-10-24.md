# Devil's Mini OS Launcher — PRD-6.2 Repair & Verification Report

**Date:** 2026-10-24  
**Authority:** PRD-6.2  
**Scope:** Uploaded source ZIP + uploaded Termux master-test report + test harness, traceability and CI repairs. The installed launcher was not touched.

## Executive result

The repaired source ZIP has been rebuilt, checksum-pinned and tested from a fresh extraction in a Linux container. The post-repair suite reports **19/19 mandatory test files and 918/918 assertions passed**. This includes a regression test for a defect that could previously produce a false-green aggregate result. The ShellCheck gate is **not verified in this container** because the `shellcheck` binary is unavailable. The new device master script asks explicit permission before attempting to install it through Termux `pkg`; declining leaves the ShellCheck gate marked BLOCKED and the overall run FAIL.

**Release status remains NOT VERIFIED.** This does not satisfy PRD §47.3: ShellCheck/hosted CI, supported-device acceptance, the second-architecture evidence, physical performance measurements, and requirement-level traceability review are still outstanding.

## 1. Source findings and minimal repairs

| Finding | Evidence in supplied source / report | Repair made | Status after verification |
|---|---|---|---|
| False-green test runner | `test/run_all.sh` discarded each child process's exit status (`|| true`). A controlled fixture printed a valid-looking `0 failed` summary and exited 23; the old runner still reported success/exit 0. | The runner now records the child exit code and only counts the test as passed when both exit status is 0 and the parsed failure count is 0. | **Fixed and regression-tested**; fixture now makes the aggregate exit non-zero and prints `[FAIL]`. |
| Traceability schema did not match PRD | Original matrix had 240 rows and 13 fields while PRD-6.2 §43.5.2 specifies 14 fields including `Module`. 91 original row IDs failed the `PRD-<SECTION>-<NNN>` format. The summary reported 197 Verified / 42 Partial / 1 Not Verified, while counted row statuses were 198 / 41 / 1. One row combined six §23.3 requirements into a range ID. | Added `Module`, reordered all fields to the §43.5.2 order, normalized malformed legacy IDs, split the combined row into six independently identified requirements, refreshed totals, and documented the normalization. Added `test/validate_traceability.sh`. | **Schema validator passes**: 245 rows, 245 unique IDs; 203 Verified, 41 Partial, 1 Not Verified. This validates format and totals, not full semantic coverage of every normative statement. |
| Existing tests asserted the obsolete traceability format | `test/test_utils.sh` required 13 columns, and its owner-field assertion inspected columns that became `Module`/Implementation Artifact rather than the three owner fields. | Updated the column count to 14 and moved the owner-field checks to the actual Accountable Owner, Verification Owner and Approval Authority cells. | **Fixed**; `test_utils.sh` passes 155/155 assertions. |
| CI documentation overclaimed traceability validation | `.github/workflows/ci.yml` described traceability coverage, but did not execute the new validator. | Added a CI step invoking `bash test/validate_traceability.sh`; all-shell-file `bash -n`, ShellCheck, and strict `<500`-line checks are included in the workflow. | Workflow YAML parses locally. Hosted GitHub Actions was **not run** in this environment. |
| ShellCheck blocked on the uploaded phone run | The uploaded device report showed ShellCheck missing; the other archived checks included 19/19 files and 915/915 assertions, but overall status was FAIL because the ShellCheck check was BLOCKED. | Updated the external master script to ask for explicit consent before `pkg install -y shellcheck`, preserve the installer log, run ShellCheck over every `.sh`, and include the consent/install status in its report. | **Needs device verification**. ShellCheck was unavailable locally; no clean ShellCheck claim is made. |
| Older traceability evidence was stale | The matrix contained stale 891/891 and 338/338 counts in evidence text. | Refreshed those entries to identify the current post-repair Linux-container evidence and clearly separate it from real-device acceptance. | Updated and covered by the manifest; hardware and release evidence remain separate gates. |

### Files changed in the repaired source

- `test/run_all.sh`
- `test/test_report_generator.sh`
- `test/test_utils.sh`
- `test/validate_traceability.sh` (new)
- `docs/TRACEABILITY.md`
- `docs/CHANGELOG.md`
- `.github/workflows/ci.yml`

The required 14 runtime modules and the set of 19 mandatory test files were preserved. No `future_plans` file or reference was added.

## 2. Final artifact identity

- **ZIP:** `devils-mini-os-launcher-PRD62-repaired-2026-10-24.zip`
- **SHA-256:** `a85e747c024fa2bdbddc3da426f733f790df123442e1afe8cef2f3069c963c73`
- **Internal `SHA256SUMS`:** 135 entries; all 135 listed files verified and the list matches the archive's immutable file set.
- Generated `data/reports/report.md` is deliberately not included in the static checksum manifest; the test suite generates it during a run.

## 3. Fresh validation on the final ZIP extraction

| Check | Result | Evidence |
|---|---|---|
| ZIP integrity | PASS | `unzip -tq` reported no compressed-data errors. |
| ZIP SHA-256 pinned in master script | PASS | Actual hash matched the script's `EXPECTED_ZIP_SHA256`. |
| Source manifest and completeness | PASS | 135 checksums verified; every static file is listed exactly once. |
| Bash syntax | PASS | All 51 `.sh` files passed `bash -n`. |
| File-size constraint | PASS | Largest `.sh` file is 499 lines; all are below 500. |
| Repository architecture | PASS | Exactly 14 active modules and 19 mandatory `test_*.sh` files; no `future_plans` path. |
| Catalog cardinality | PASS | 8 desktop records, 40 Proot apps, 32 Termux app records. Cardinality is not a complete content-quality audit. |
| Traceability schema | PASS | 245 unique IDs, 14 fields, populated cells, allowed statuses and matching totals. |
| Security scan | PASS | The master-script forbidden dynamic-shell scan found no prohibited construct in production source paths. This does not replace a full security review. |
| CLI smoke checks | PASS | `devils-minios.sh --version` reported v1.0.0 and `--help` succeeded. |
| Mandatory suite | PASS | `19/19` files; `918/918` assertions; `0` failures; aggregate exit 0. |
| Post-suite source checksums | PASS | `sha256sum -c SHA256SUMS` passed after the generated report was written. |
| Master script syntax | PASS | `bash -n /mnt/data/prd62-master-test.sh`; 433 lines. |
| ShellCheck | **NOT VERIFIED** | The binary is not available in this container; no results have been fabricated. |

The full final-ZIP suite log is available as `final-zip-suite.log` alongside this report in the supplied artifacts.

## 4. Run the real-device master script

Download both files to the phone's Downloads folder, open Termux, ensure storage access has been granted, and run:

```bash
bash "$HOME/storage/downloads/prd62-master-test.sh"
```

If ShellCheck is missing, the script will present an explicit `[y/N]` installation prompt. Answer **`y`** only if you authorize the Termux package/network change. The script then checks all repository shell files. Its report, console log and individual check logs are written under `$HOME/devils-minios-test-runs/`.

## 5. Remaining release gates — do not call v1.0.0 FINAL

1. Run ShellCheck on all 51 shell files on-device (or through the configured hosted CI); fix any real findings and re-run the suite.
2. Execute hosted GitHub Actions and archive its actual outcome.
3. Complete the applicable Android/Termux manual acceptance checks and fresh-install/upgrade/recovery acceptance on a supported device.
4. Establish the PRD-required second-architecture evidence. A generic Linux x86_64 container run is not proof of an Android x86_64 device acceptance run.
5. Complete physical performance measurements against §20 and the required release checklist.
6. Perform a requirement-by-requirement semantic traceability review. The validator verifies matrix structure, identifiers, ownership-cell population, allowed status values and totals; it does **not** independently prove that all normative PRD statements are covered or that every `Verified` evidence citation is sufficient.

**Disposition:** source repairs and the final-ZIP Linux test suite are verified as stated above. Overall release gate: **NOT VERIFIED / §47.3 NOT MET**.
