# Devil's Mini OS Launcher v1.0.0
# Real Android / Termux Manual Acceptance Evidence

Complete these manual acceptance groups on the same device.

## MA-01
Installation variants, ZIP/Git checkout, onboarding, auto-start opt-in.

Record:
- installation command/output
- version output
- onboarding screenshots or terminal transcript
- auto-start opt-in result
- reinstall/idempotency result

## MA-02
Supported Android/Termux source and unsupported-platform behavior.

Record:
- Android API level
- architecture
- Termux source
- Play Store warning behavior when applicable
- unsupported-platform behavior when applicable

## MA-03
Proot distro, desktop, systemd acknowledgement, xstartup/startup.

Record:
- selected distro
- installation result
- desktop startup result
- systemd acknowledgement
- xstartup/startup result

## MA-04
Application installation and security.

Record:
- Termux app installation result
- Proot app installation result
- GitHub artifact path when applicable
- architecture mismatch confirmation behavior
- security rejection behavior

## MA-05
Android tools and Termux:API degradation.

Record:
- ADB detection
- fastboot detection
- Termux:API available/unavailable behavior
- graceful degradation when optional capability is missing

## MA-06
Terminal widths and Ctrl+C.

Test:
- Full mode
- Compact mode
- Minimal mode
- Ctrl+C confirmation

Record terminal width and observed behavior.

## MA-07
Log viewer.

Record:
- log listing
- log viewing
- read-only behavior
- malformed/missing log handling where applicable

## MA-08
Configuration, state and crash recovery.

Record:
- configuration reset
- state reset
- valid crash recovery
- stale crash flag
- malformed crash flag
- recovery evidence

## MA-09
Safe Mode.

Record:
- explicit Safe Mode
- Safe Mode caused by recovery conditions
- menu availability restrictions
- exit/recovery path

## MA-10
Reset, update/rollback and uninstall.

Record separately:
- configuration reset
- state reset
- nuclear reset
- update
- rollback/failure behavior
- uninstall

Do not run destructive operations until all required user data is backed up.

## MA-11
Real-device full suite and performance.

Record:
- real aarch64/x86_64 architecture
- full 19-test suite result
- launcher cold-start timing
- memory observation
- final device/environment evidence

## Evidence rule

Do not mark a manual item as PASS only from source inspection or automated tests.

Store the actual terminal output, screenshots, timing results, and relevant command results under its MA-* directory.
