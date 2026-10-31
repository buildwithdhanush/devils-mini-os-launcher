# Start Here — Devil’s Mini OS Full Repair Handoff for Kimi

This bundle is designed for a **full implementation and verification job**, not an audit-only review and not a minimal-diff-only task.

## How to use it

1. Give Kimi the entire `Devils-MiniOS-Full-Repair-Kimi-Handoff-2026-10-25.zip` file as the input attachment.
2. Open `KIMI-MASTER-PROMPT-FULL-REPAIR.md` and submit the entire Markdown prompt as Kimi’s main instruction.
3. Require Kimi to work against the exact source candidate in `INPUTS/`, read `INPUTS/PRD-6.2.md` completely, and use `EVIDENCE/` as historical evidence tied to its recorded run/hash.
4. Kimi must deliver a **new repaired project source ZIP** with the full audit-and-repair report embedded at `docs/FULL-AUDIT-AND-REPAIR-REPORT.md`. This handoff archive is the input kit, not the final repaired product archive.

## Important distinctions

- The source candidate included here has SHA-256 `7153aa696970676b354ffea17a00cb039bd6931bed02d595701e9a66f60d5635`.
- An earlier Termux archive failed manifest completeness due to `data/reports/report.md`.
- A different earlier archive passed 19/19 tests / 918 assertions but failed ShellCheck on two findings.
- An even older ShellCheck log has 21 diagnostics. Do not merge outcomes across archive hashes. The master prompt explicitly requires baseline and final verification against the exact candidate/final ZIP.
- `INPUTS/previous-prd62-master-test.sh` is supplied for review; it must not be trusted blindly. In particular, the old copy contains a hardcoded source ZIP path/hash and an exact manifest-completeness comparison that must be independently validated and corrected as necessary.

## Safety boundary

All code changes and tests must use a disposable extraction. Never modify the user’s installed launcher, live configuration, Proot environments, or user data. Do not report a gate as passed without fresh command output and exit status.
