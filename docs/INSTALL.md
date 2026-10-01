# Installation

Devil's Mini OS Launcher targets **Termux on Android** (API 29+, `aarch64`
or `x86_64`). It runs on any Bash 4.3+ host in diagnostics-only mode for
development/testing, but is only fully supported on Termux.

## Requirements

- Termux (F-Droid or GitHub build recommended; Play Store builds are
  detected and warned about, but not blocked)
- Android 10+ / API 29+
- `aarch64` or `x86_64` device architecture
- Bash 4.3 or newer (Termux ships a current Bash by default)

## Installing

The launcher is never installed via `curl | bash` or `wget | bash`. You
always obtain an inspectable source first, then run the installer from it:

```bash
git clone <repository-url>
cd Devils-Mini-OS-Launcher
bash install.sh
```

A release ZIP works the same way: extract it, then run `bash install.sh`
from inside the extracted directory.

`install.sh`:

1. Validates the source tree (required modules, no removed/forbidden
   modules present).
2. Verifies `SHA256SUMS` against the source files, if a manifest is
   present (integrity only — see `docs/SECURITY.md`).
3. Checks available storage.
4. Stages the installation in a temporary directory, then atomically
   activates it at `$PREFIX/opt/devils-minios`.
5. Creates a `devils-minios` symlink on `$PATH` (`$PREFIX/bin`).
6. Deletes the installer-owned temporary source copy it made for the
   install (never the user's own Git checkout — see `docs/SECURITY.md`
   §30.1 for the exact boundary).

Re-running `install.sh` from inside the already-active installation
directory (a self-reinstall) is detected and handled safely: the new copy
is staged elsewhere first and only then atomically swapped in.

## First run

```bash
devils-minios
```

On first run you'll go through a short onboarding flow. After that,
`devils-minios` launches straight to the main menu (or auto-launches your
last workflow, if enabled in Settings).

## Verifying an installation

```bash
devils-minios --uninstall --help   # see all CLI flags
bash /path/to/install.sh --verify  # or: devils-minios's own install.sh --verify
```

`install.sh --verify` runs `sha256sum -c SHA256SUMS` against the active
installation and reports per-file PASS/FAIL. This is an **integrity**
check only, not an authenticity guarantee — see `docs/SECURITY.md`.

## Uninstalling

```bash
devils-minios --uninstall
```

Only valid while the launcher is idle (not mid-workflow, not in Safe
Mode); otherwise it exits with `E401`. Uninstalling removes the launcher
installation directory only — your configuration, state, and any Proot
Linux environments you installed are preserved.

To remove the Termux `boot/` auto-start entry (if you added one) without a
full uninstall:

```bash
devils-minios --uninstall-auto-start
```

## Updating

```bash
devils-minios --update
```

Downloads and verifies the latest tagged release from the fixed,
compiled-in trust anchor repository (there is no configuration key for
this — see `docs/SECURITY.md`), checks its checksum, and only replaces the
active installation if every check passes. A failed update never leaves
the launcher in a partially-updated state; on failure it falls back to the
previous installation, or to Safe Mode if that fallback itself fails.

## Troubleshooting an install

See `docs/TROUBLESHOOTING.md` for common install-time failures and their
error codes.
