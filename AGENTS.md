<!-- TASKPLANNER:START -->
## Task planning workflow

- Use `.tasks/config.json` and the configured state files as the source of truth for task status.
- Before implementation, select the highest-priority task from `NEXT.md`, move it to `IN_PROGRESS.md`, and add/update its `### Plan`.
- Preserve task IDs and unrelated task sections. Do not mark work complete without verification evidence.
- Follow the project's PRD-6.2 as the normative specification; record unresolved evidence gaps rather than inventing evidence.
<!-- TASKPLANNER:END -->
PRD-6.2 Authority

- "docs/PRD-6.2.md" is the sole normative specification for Devil's Mini OS Launcher v1.0.0.
- Read and understand the PRD before modifying project files.
- Follow every applicable requirement exactly.
- Never invent, weaken, or silently reinterpret requirements.
- When evidence is insufficient, report Needs Verification.
- Preserve the existing architecture and security requirements.
- Run relevant tests before and after modifications.
- Never claim completion without verification.
- Do not modify the installed launcher during development.