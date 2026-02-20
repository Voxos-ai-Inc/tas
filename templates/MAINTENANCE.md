# Maintenance Manifest

Recurring TPM tasks. At session start, check each task's `last_run` against its cadence. If overdue, notify the user and offer to run it. Update `last_run` after completion.

## How to Check

Compare `last_run` (ISO 8601 datetime) against `cadence`. If `now - last_run > cadence`, the task is overdue. Present overdue tasks as a batch: "N maintenance tasks are overdue. Run them?"

If multiple tasks are overdue, run them in priority order (session-start first, then hourly, then daily).

---

## Tasks

### 1. Reminders Triage
- **Cadence:** session-start
- **Last run:** {{YYYY-MM-DDTHH:MM:SSZ}}
- **What:** Read `REMINDERS.md`. For each item whose check date has passed, verify the condition. Remove resolved items. Flag unresolved items to the user.
- **Output:** Updated `REMINDERS.md` with resolved items removed.

### 2. Memory & Doc Hygiene
- **Cadence:** 1 hour
- **Last run:** {{YYYY-MM-DDTHH:MM:SSZ}}
- **What:**
  1. Verify file paths referenced in `.claude-memory/MEMORY.md` still exist.
  2. Check project's `CLAUDE.md` — do instructions match the current codebase?
  3. Collapse fully-completed MILESTONES.md phases into summary lines.
  4. Flag stale entries for fast resolution.
- **Output:** Updated MEMORY.md, CLAUDE.md, MILESTONES.md files.

### 3. Cost Tracking Review
- **Cadence:** 1 day
- **Last run:** {{YYYY-MM-DDTHH:MM:SSZ}}
- **What:**
  1. Check billing / usage for per-service spend (LLM calls, database, compute, third-party APIs).
  2. Flag any service exceeding your threshold.
  3. Compare current spend against last recorded spend in MILESTONES.md.
  4. Update MILESTONES.md cost notes if delta is significant.
- **Output:** Cost summary table. Updated MILESTONES.md if spend changed.
