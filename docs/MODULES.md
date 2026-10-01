# Modules

Devil's Mini OS Launcher is a single entry point (`devils-minios.sh`) plus
`modules/core.sh` (always loaded) and 13 feature modules, loaded on demand
when their menu is opened. Every module exposes exactly one public
`<name>_menu()` entry point that the launcher dispatches to; everything
else in a module is a private helper.

No new modules, plugins, or architectural changes are made beyond what is
listed here — the module set is fixed at 14 files.

## `core.sh` (always loaded)

The shared runtime: path/config/state management, logging (rotation and
age-based purge), the state machine, Safe Mode, the structured command
executor (`execute_structured()` — the only sanctioned way modules run
external commands; no `eval`, `sh -c`, or `bash -c` anywhere else in the
codebase), path/input validation and sanitizers, storage/battery checks,
and crash-loop detection.

## Feature modules

| Module | Menu entry point | What it does |
|---|---|---|
| `linux_env.sh` | `linux_env_menu()` | Proot Linux distro install/manage, desktop environment selection, `xstartup` generation |
| `termux_apps.sh` | `termux_apps_menu()` | Install/manage native Termux packages (`pkg` and pinned-ref GitHub sources) |
| `file_mgr.sh` | `file_mgr_menu()` | Browse, search, read, copy, and transfer files (internal + external storage, with execution blocked on external storage) |
| `proot_apps.sh` | `proot_apps_menu()` | Install/manage apps inside a Proot distro via the structured executor |
| `workspace.sh` | `workspace_menu()` | Named, sandboxed working directories confined to `$HOME/devils-minios/workspaces/` |
| `android_tools.sh` | `android_tools_menu()` | ADB/fastboot helpers, device info, Termux:API status |
| `health_check.sh` | `health_check_menu()` | Diagnostics: battery, storage, proot-distro availability, cached with a configurable interval |
| `system_tools.sh` | `system_tools_menu()` | Process listing/kill (with confirmation), other system-level actions |
| `system_info.sh` | `system_info_menu()` | Read-only system information display |
| `update_all.sh` | `update_all_menu()` | Self-update (checksum-verified against a fixed trust anchor) and package updates |
| `settings.sh` | `settings_menu()` | Configuration editing/validation, export/import, configuration/state/nuclear reset |
| `customize.sh` | `customize_menu()` | Themes and banners, including the animated-banner draw counter |
| `log_viewer.sh` | `log_viewer_menu()` | Read-only log viewing; clear/export delegate back to `core.sh`, which is the sole log writer |

## Dispatch

The launcher resolves a menu choice or `--run-module <name>` argument to a
module via a fixed alias table, sources `core.sh` plus the target module,
and calls its `<name>_menu()` function. A module returning non-zero is
logged as a warning and the launcher returns to `IDLE`/the main menu — a
single module failure never crashes the whole launcher.

## Data files a module may read

Feature modules read (never write outside of `core.sh`'s state/config
helpers) the catalogs under `data/` — see `docs/DATA.md` for their exact
schemas.
