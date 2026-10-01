# Compatibility

## Platform

- **Primary platform:** Termux on Android.
- **Termux sources:** F-Droid and GitHub builds are fully supported. Play
  Store Termux builds are outdated upstream and are explicitly warned about
  on every launch — they are not blocked, but are not the recommended
  source.
- **Minimum Android version:** 10.0 (API 29). Devices below this are
  rejected at startup.

## Architecture

Exactly two architectures are supported and named consistently throughout
the launcher and its data catalogs:

- `aarch64`
- `x86_64`

Proot applications are filtered per-record against this pair; a record
whose `architectures` field does not include the detected architecture is
hidden rather than offered and then failing.

## Bash

Bash **4.3** is the required floor (5.x recommended, and what current
Termux ships by default). The same floor is checked identically in
`devils-minios.sh` and `install.sh`.

## Terminal width / UI modes

| Width | UI mode |
|---|---|
| ≥60 columns | Full UI |
| 40–59 columns | Compact UI |
| <40 columns | Minimal UI (mandatory fallback; always renders, never crashes) |

`terminal_width` is a runtime fact only — it is detected fresh on every
launch and is never written to the persisted `config` file.

## Desktops (Tier 1, exactly 8)

`xfce4`, `lxqt`, `lxde`, `mate`, `i3wm`, `openbox`, `fluxbox`, `jwm`.

No experimental or additional desktops are offered in v1.0.0. A desktop
whose environment depends on systemd (which is unavailable under proot)
surfaces an explicit warning before the user continues.

## Proot distributions

Discovered dynamically against the official `proot-distro` catalog. The
bundled `data/proot_distros.db` records the minimum expected set (Ubuntu,
Debian, Arch, Fedora, Alpine, Void) together with each distro's package
manager, used by the structured package-install/update paths.

## Optional dependencies (degrade gracefully, never block core function)

| Dependency | Used for | Behavior when absent |
|---|---|---|
| `proot-distro` | Linux/proot environments | Linux-environment features are disabled; Safe Mode Core itself has no dependency on it |
| Termux:API | Battery level, other device signals | Fail-open: a clear "unavailable" warning, the operation proceeds, the capability is marked unavailable in the UI |
| `termux-wake-lock`, Termux:Boot | Auto-start on device boot | Auto-start toggle takes no action rather than erroring |
| `git` | Install/update workflows | Update/self-update report a clear network/tooling error |
| `curl`, `sha256sum` | GitHub-sourced Termux app installs | That install path is disabled with a clear error |
