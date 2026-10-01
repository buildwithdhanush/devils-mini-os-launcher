# Security Model

## Reporting a vulnerability

Report vulnerabilities through **GitHub private vulnerability reporting**
on the official repository
(`https://github.com/buildwithdhanush/Devils-Mini-OS-Launcher`, Security
tab → "Report a vulnerability") rather than a public issue, so a fix can
ship before details are public.

Response targets:

- **Acknowledgement:** within 7 days of the report.
- **Critical vulnerabilities:** fix targeted within 30 days.
- **Moderate vulnerabilities:** fix targeted within 90 days.

Each release publishes a source-tarball SHA-256 and a `SHA256SUMS` file
(see "Integrity vs. authenticity" below for what those do and do not prove).

## No arbitrary shell execution

Every external command the launcher runs goes through
`execute_structured()` in `modules/core.sh` — the **sole** execution
primitive in the codebase. It:

- allowlists the executor itself (`proot-distro`, `pkg`, `git`, `tar`,
  `sha256sum`, `curl`, and a small fixed set of standard utilities — never
  an arbitrary binary),
- rejects any argument containing shell metacharacters,
- rejects known-dangerous argument patterns (e.g. `rm -rf /`, `rm -rf
  $HOME`) while still allowing the confirmed, path-validated deletes the
  file manager and workspace features rely on.

`eval`, `sh -c`, and `bash -c` do not appear anywhere else in the codebase
(enforced by a forbidden-pattern CI scan) — there is no other way to reach
a shell.

## Path safety

`validate_path()` rejects path traversal and confines file operations to
expected roots. Workspaces are always confined to
`$HOME/devils-minios/workspaces/`. Executing a file from external storage
(`/sdcard`, `/storage/emulated`, ...) is blocked outright, since Android
mounts external storage `noexec`; reading/copying from external storage is
allowed with an explicit confirmation.

## Schema-load-time validation

Untrusted-shaped input from the data catalogs (`data/*.db`) is validated
at load time, not at use time:

- `install_target` / `package_name` fields are rejected if they contain
  shell metacharacters.
- `startup_binary` must match a fixed allowlist.
- `startup_args` tokens must match a strict character-class pattern.
- A Termux app's `github_ref` must be a pinned tag or commit SHA (a
  branch name is rejected) and its `github_sha256` must be a valid
  64-character lowercase hex digest, verified against the downloaded
  artifact before install; a checksum mismatch aborts with no partial
  state.
- `install_source: script` is rejected outright — not a supported
  install path.

See `docs/DATA.md` for the full schema of each catalog.

## Configuration and state grammar

Configuration and persisted state files are parsed with a strict
`key=value` grammar: duplicate keys, unknown keys, and malformed lines are
rejected. `runtime_context`-shaped keys are rejected if present in
`config` — no config key exists for a repository URL, so
`install.sh`/`devils-minios --update` never read one from user
configuration; the update trust anchor is a compiled-in constant, not
configurable, precisely to prevent update-source tampering.

A corrupt `config` triggers a last-known-good restore from its backup; if
that also fails, defaults are reinitialized. The same applies to
persisted `state`/`state.bak` (falling back to `FIRST_BOOT` defaults if
both are invalid). A corrupted or unparseable crash flag is treated as an
active trigger (fails closed into Safe Mode) rather than being ignored.

## Integrity vs. authenticity

`install.sh --verify` and the self-update path both check `SHA256SUMS`
via `sha256sum -c`. **This provides integrity only** (the files match a
manifest shipped alongside them) — it is **not** an independent
authenticity guarantee (it does not prove the manifest itself came from
the real maintainer, the way a GPG-signed release would). Release notes
should state this plainly. Treat checksums as tamper-evidence for a
release you already trust the source of (e.g. a Git tag you cloned over
HTTPS from the official repository), not as a substitute for verifying
where you got the release from.

## Installer deletion boundary

`install.sh` only ever deletes a path it captured as its own controlled,
installer-managed temporary copy or clone. It never deletes via glob
expansion, a user- or environment-supplied path, or by re-deriving "the
directory it was run from". A user's own Git checkout is never a deletion
candidate, even if it happens to be the source being installed from.
Reinstalling in place from the currently-active installation directory is
detected and handled by staging the new copy elsewhere first, never by
deleting/overwriting the running source mid-execution.

## Rootless by design

The launcher never requires or requests root. Proot-based Linux
environments run fully unprivileged under Termux's own sandbox.
