---
name: recover
description: Recover orphaned Claude Code sessions after a crash or terminal close. Lists dead sessions, lets user pick which to resume, launches them in new terminal tabs.
---

# /recover — Session Recovery

Recovers orphaned Claude Code sessions by resuming them in new terminal tabs.

## Instructions

### Step 1: Discover orphaned sessions

Run the recovery script to get a JSON list of orphaned sessions:

```bash
bash ~/.claude/hooks/cc-recover.sh list
```

### Step 2: Present sessions to user

Parse the JSON output. For each session, display a numbered table with:

| # | Session ID (first 8 chars) | Model | Started | Last Active | Transcript Size | CWD |
|---|---------------------------|-------|---------|-------------|-----------------|-----|

- **Last Active**: Convert `last_active_epoch` to a human-readable relative time (e.g., "2 hours ago", "yesterday")
- **CWD**: Show only the last 2 path components for readability
- Sort by Last Active descending (most recent first) — the script already does this

If zero orphaned sessions are found, tell the user "No orphaned sessions to recover" and stop.

### Step 3: Ask the user what to recover

Use AskUserQuestion with options:

1. **Resume all recent** — Resume sessions active within the last 6 hours
2. **Resume all** — Resume every orphaned session
3. **Let me pick** — User will specify which session numbers to resume

If the user picks "Let me pick", ask them to specify session numbers (e.g., "1, 3, 5-8").

### Step 4: Launch selected sessions

For each selected session, run:

```bash
bash ~/.claude/hooks/cc-recover.sh launch <full_session_id>
```

This opens a new terminal tab with `claude --resume <id>`.

Add a 0.5s delay between launches to avoid overwhelming the terminal.

### Step 5: Clean up dismissed sessions

For sessions that were NOT selected for recovery, offer to clean them up:

```bash
bash ~/.claude/hooks/cc-recover.sh clean <id1> <id2> ...
```

This marks them as `ended` with reason `recovered-dismissed` so they don't clutter future recovery attempts.

### Step 6: Report

Summarize:
- N sessions resumed (with tab names)
- M sessions dismissed
- Any sessions left untouched

## Notes

- Sessions are identified as orphaned when their tracking status is "active" but the process PID is dead
- After a full terminal restart or crash, ALL previously-active sessions appear orphaned (correct behavior)
- Transcript size helps identify substantial sessions (>1MB = heavy work) vs. quick one-offs (<100KB)
