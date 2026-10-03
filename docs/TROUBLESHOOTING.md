# Troubleshooting

## The launcher enters Safe Mode

Safe Mode is entered automatically after a crash loop (3 crashes within 10
minutes), an active crash flag from a prior session, or explicitly via
`devils-minios --safe-mode`. From the Safe Mode menu you can:

1. View recent log entries.
2. Repair configuration (reset `config` to defaults — `state` is untouched).
3. Repair state (reset `state` to defaults — `config` is untouched).
4. Nuclear reset (wipe configuration + state + cache; the onboarding marker
   is deliberately **not** restored, so onboarding runs again on next
   launch).
5. Attempt to relaunch your primary Proot distro, if one is recorded.

Safe Mode Core itself has **zero** external dependencies — it is fully
usable even with no Proot distro installed and no Termux:API present.

Manual escape hatch if the interactive menu itself is unreachable:

```sh
rm ~/.config/devils-minios/.crash-flag
devils-minios --safe-mode
```

## Configuration reset vs. state reset vs. nuclear reset vs. uninstall

These are four **distinct** operations — pick the narrowest one that fixes
the problem:

| Operation | Touches | Leaves untouched |
|---|---|---|
| Configuration reset | `config` only | `state`, installed distros, workspaces |
| State reset | `state` only | `config`, installed distros, workspaces |
| Nuclear reset | `config` + `state` + cache (Safe Mode only) | Installed Proot distros, workspaces, banners/templates (restored if they individually validate) |
| Uninstall (`--uninstall`) | Launcher installation directory + symlink only | `~/.config/devils-minios/` in full, including all installed Proot environments |

## A database looks empty / a feature is disabled

If a data file (`data/*.db`) is missing or has too many malformed records,
**only the dependent feature** is disabled — the launcher itself stays up
and unrelated modules keep working. Check the log for the specific error
code (see below) naming the affected file.

## Corrupted configuration or state

Both `config` and `state` are written atomically with a `.bak` companion.
On detected corruption, the launcher automatically restores from the
matching backup; if the backup is also invalid, defaults are reinitialized
(for state, this naturally re-triggers onboarding). You normally don't need
to intervene — but the Safe Mode reset actions above are available if
automatic recovery isn't enough.

## `install.sh` refuses to run

- **"Missing required files" / a specific `modules/...` path** — your
  source tree is incomplete; re-clone or re-extract it.
- **"...must not exist"** (`future_plans.sh`) — your source contains a
  removed module; use an up-to-date release.
- **"SHA256SUMS verification failed"** — the source doesn't match its own
  manifest; re-download it rather than proceeding.
- **"exists but is not a Devil's Mini OS installation"** — the target
  directory (`$PREFIX/opt/devils-minios`) already holds unrelated files;
  the installer will not silently overwrite them. Move or remove them
  yourself first if you're sure, then re-run.

## `--uninstall` fails with `E401`

`--uninstall` only runs from the launcher's idle state. If you see `E401`,
finish or exit whatever the launcher is currently doing and invoke
`--uninstall` from a fresh, non-flag invocation.

## Battery / storage gates

- Battery ≤9%: blocked outright.
- Battery 10–20% (inclusive): requires confirmation.
- Battery ≥21%: proceeds normally.
- Storage: an operation is blocked when `available_bytes <
  required_bytes + safety_margin_bytes` for that specific operation; the
  error names both figures.

If Termux:API is not installed, battery-dependent checks **fail open**: a
clear "unavailable" warning is shown, the operation proceeds, and the
capability is marked unavailable in the UI rather than hard-blocking you.

## Running the test suite yourself

```sh
bash test/run_all.sh
```

Runs all 19 mandatory test files and prints an aggregate pass/fail. See
`data/reports/report.md` (regenerate it via `bash test/test_report_generator.sh`)
for a saved summary.

## Narrow terminal / garbled menus

Below 40 columns the launcher always falls back to Minimal UI rather than
rendering a broken Full/Compact layout. If your terminal reports a width
incorrectly, resizing and relaunching re-detects it — `terminal_width` is
never cached to disk.
