# Devil's Mini OS Launcher

**The easiest way to turn Termux into a managed Linux workstation on Android.**

Devil's Mini OS Launcher is a pure-Bash menu-driven launcher that takes a
fresh Termux install and turns it into a usable proot-based Linux
development environment — distros, desktops, apps, workspaces, and
recovery — without you having to hand-manage dozens of commands and
config files yourself.

## What is Termux?

[Termux](https://termux.dev) is a terminal emulator and Linux environment
app for Android that runs without root. This launcher runs **on top of**
Termux; it is not a replacement for it and does not itself provide
kernel-level virtualization — Linux distributions run inside `proot`, a
userspace compatibility layer (see [Proot limitations](#proot-limitations)
below).

## Supported Termux sources

Only these are supported:

- **F-Droid** build
- **GitHub** build

**Play Store Termux builds are not supported.** The Play Store version of
Termux is outdated and unmaintained upstream, and is known to be
incompatible with much of the proot/package ecosystem this launcher
depends on. If the launcher detects a Play Store install (or an
ambiguous environment that looks like one), it shows a prominent warning
on every invocation and during onboarding. This is non-blocking — the
launcher will still run — but you should expect breakage and are
strongly encouraged to reinstall from F-Droid or GitHub.

## Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Android | 10.0 / API 29 | Newer |
| Bash | 4.3 | 5.x |
| Storage | 500 MB | 2 GB+ |
| RAM | 2 GB | 4 GB+ |
| Architecture | `aarch64`, `x86_64` | `aarch64` |
| Terminal width | 40 columns (Minimal mode supported below this) | 60+ |

## Installation

Two supported installation methods. **`curl | bash` is intentionally not
supported** — always fetch the source yourself so you can inspect it
before running anything with shell access to your device.

### Git (recommended)

```bash
git clone https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher.git
cd Devils-Mini-OS-Launcher
# optional but recommended: read install.sh before running it
bash install.sh
```

### ZIP

Download and extract a release ZIP, then:

```bash
cd Devils-Mini-OS-Launcher
bash install.sh
```

### Verifying integrity

Every release ships a `SHA256SUMS` manifest. After installing, you can
re-verify the installed files at any time:

```bash
bash install.sh --verify
```

See [`docs/SECURITY.md`](docs/SECURITY.md) for exactly what this
checksum does and does not guarantee.

## First launch

```bash
devils-minios
```

The first run walks you through a short onboarding flow: a Termux-source
check, a proot-limitations summary, and a few optional preferences
(update checks, theme, auto-launch, auto-start). None of these steps are
mandatory — sensible defaults are applied if you skip them.

## Basic workflows

- **Install a Linux distro:** main menu → Linux Environments → pick a
  distro from the detected `proot-distro` catalog.
- **Install a desktop:** main menu → Linux Environments → Desktops (one
  of the 8 supported Tier-1 desktops: `xfce4`, `lxqt`, `lxde`, `mate`,
  `i3wm`, `openbox`, `fluxbox`, `jwm`).
- **Install apps:** Termux Apps and Proot Apps menus install curated,
  catalog-defined packages — never arbitrary shell commands.
- **Workspaces:** a dedicated, sandboxed project directory under
  `$HOME/devils-minios/workspaces/`.
- **Everything else** (Android tools, system tools/info, health check,
  log viewer, customization, update-all, settings) is reachable from the
  main menu; see [`docs/MODULES.md`](docs/MODULES.md) for what each
  module owns.

## Proot limitations

Proot is a **userspace compatibility layer**, not kernel-level
virtualization. Before any proot operation, the launcher explains what
that means in practice: no real kernel/systemd, limited device access,
no true root, and desktop-specific caveats (a desktop that needs
`systemd` is called out with a blocking warning before install). These
limitations are inherent to proot and are not launcher bugs.

## Security model

- **No root, ever.** The launcher never requests, invokes, or attempts
  privilege escalation. Root-requiring operations are detected and
  rejected with an explanation.
- **No dynamic shell interpretation.** No catalog record, config value,
  or user input ever reaches `eval`, `sh -c`, `bash -c`, or an
  equivalent — all execution goes through a single centralized,
  structured executor.
- **Integrity vs. authenticity are different guarantees.** `SHA256SUMS`
  proves the files you have match the checksum — it does **not** prove
  who produced that checksum. The actual trust boundary for v1.0.0 is
  the official repository URL (hardcoded, no override) plus HTTPS
  transport. Release signing is not implemented yet. Full detail:
  [`docs/SECURITY.md`](docs/SECURITY.md).

## Recovery

Four distinct, non-overlapping operations — see
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for when to use
which:

| Operation | Touches | How |
|---|---|---|
| **Configuration reset** | Your settings only | Settings menu or Safe Mode |
| **State reset** | Internal launcher state only (not your settings) | Settings menu or Safe Mode |
| **Nuclear reset** | Both config and state, full disaster recovery | Safe Mode only, explicit confirmation |
| **Uninstall** | The launcher install itself — your `~/.config/devils-minios/` is preserved | `devils-minios --uninstall` |

Crash-loop protection and Safe Mode routing are automatic; see
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Supported architectures

`aarch64` and `x86_64` only, using canonical names throughout (no
aliases). See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).

## Supported desktops

Exactly 8 Tier-1 desktops: `xfce4`, `lxqt`, `lxde`, `mate`, `i3wm`,
`openbox`, `fluxbox`, `jwm`. No experimental desktops in v1.0.0. See
[`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).

## Supported applications

40 curated proot applications and 30–40 curated Termux applications,
defined entirely by data catalogs (never free-form commands). See
[`docs/DATA.md`](docs/DATA.md).

## Documentation

- [`docs/INSTALL.md`](docs/INSTALL.md) — detailed installation and update steps
- [`docs/MODULES.md`](docs/MODULES.md) — module architecture and responsibilities
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — Safe Mode, crash recovery, reset operations
- [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) — architecture/desktop/Android support matrix
- [`docs/SECURITY.md`](docs/SECURITY.md) — security model, vulnerability reporting, integrity vs. authenticity
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — release history (Keep a Changelog format)
- [`docs/DATA.md`](docs/DATA.md) — data catalog schemas (`data/*.db`)

## Contributing

Governance is BDFL with lazy consensus for non-breaking changes;
breaking changes go through a PR with a 7-day comment window. Please
read [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) before opening issues or
PRs. Use the Bug Report / Feature Request / Compatibility Report /
Security issue templates where applicable, and run
`bash test/run_all.sh` (all 19 mandatory test files) before submitting a
PR.

## Reporting a security issue

Please **do not** open a public issue for security vulnerabilities. Use
GitHub's private vulnerability reporting for this repository. Full
policy, response SLAs, and scope: [`docs/SECURITY.md`](docs/SECURITY.md).

## License

MIT — see [`LICENSE`](LICENSE).

<!-- TASKPLANNER:ATTRIBUTION:START -->
This project uses [TaskPlanner](https://github.com/smekai/taskplanner) for task planning.
<!-- TASKPLANNER:ATTRIBUTION:END -->
