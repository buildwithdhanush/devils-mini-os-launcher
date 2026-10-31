# Backlog

## TASK-010: Execute production release gates and device acceptance
**Priority:** P0 | **Tags:** release, acceptance, android

Implement PRD-6.2 §53 Phase 8 only after engineering gates pass: execute manual acceptance on supported F-Droid/GitHub Termux and Android 10+ devices, capture performance evidence under §20 conditions, complete second consistency audit, and enforce all §47 gates.

### Plan

- Build a release candidate only after TASK-001 through TASK-009 acceptance dependencies are satisfied.
- Execute critical workflows and manual acceptance tests in PRD §§45.1 and 45.
- Measure cold startup, peak RSS, log-write latency, and fresh health-check timing using prescribed sample counts and conditions.
- Audit security, reliability, compatibility, traceability, documentation, and rollback readiness.
- Release only if every mandatory gate passes; otherwise record exact blockers.

### Acceptance

- All required release-gate evidence is present and independently reviewable.
- No mandatory test failure, critical security/runtime issue, or unverified release blocker remains.

---
