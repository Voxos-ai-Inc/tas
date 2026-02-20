# Claude Code Harness

An operational harness for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that adds session tracking, token budgeting, slash-command skills, maintenance cadence, and persistent memory to any project.

Claude Code is powerful out of the box. The harness makes it *disciplined* — every session is tracked, every task is budgeted, every loose end is caught.

## What You Get

| Layer | What it does | Files |
|-------|-------------|-------|
| **Session tracking** | Auto-registers every session. Detects orphaned sessions (crashed tabs). Offers `--resume`. | `hooks/session-register.sh`, `hooks/session-end.sh`, `hooks/cc-sessions.sh` |
| **Token budgeting** | Estimate effort in tokens, not time. Track estimate vs. actual. Calibrate over sessions. | `hooks/task-log.sh`, `hooks/task-check.sh`, `scripts/cc-budget.sh` |
| **Skills** | Slash commands (`/commit`, `/done`, `/queue`, `/preview`). Create your own with `/nu`. | `.claude/skills/<slug>/SKILL.md` |
| **Maintenance cadence** | Recurring tasks checked at session start. Overdue tasks surfaced automatically. | `MAINTENANCE.md` |
| **Persistent memory** | Key facts survive across sessions. Version-controlled in your repo. | `.claude-memory/MEMORY.md` |
| **Document discipline** | Living docs vs. snapshots vs. scrap — clear rules for what gets updated and when. | `CLAUDE.md` template |
| **Prove It loop** | Baseline → Change → Measure → Compare → Record. No vibes-based development. | `CLAUDE.md` template |

## Quick Start

```bash
# Clone and install into your project
git clone https://github.com/voxos-ai/harness.git /tmp/harness
cd /path/to/your/project
bash /tmp/harness/setup.sh
```

Or run directly:

```bash
curl -fsSL https://raw.githubusercontent.com/voxos-ai/harness/main/setup.sh | bash
```

The setup script:
1. Copies hooks to `.claude/hooks/` and links them to `~/.claude/hooks/`
2. Installs starter skills to `.claude/skills/`
3. Registers `SessionStart`, `SessionEnd`, and `Stop` hooks in `~/.claude/settings.json`
4. Creates template files (`CLAUDE.md`, `MAINTENANCE.md`, `REMINDERS.md`, `GOTCHAS.md`, `MILESTONES.md`)
5. Sets up `.claude-memory/` for persistent agent memory

**Prerequisites:** `jq`, `git`, `bash`. Works on macOS, Linux, and Windows (Git Bash / MSYS2).

## How It Works

### Session Lifecycle

```
Session start
  │
  ├─ SessionStart hook fires
  │    └─ session-register.sh writes ~/.claude/session-tracking/<id>.json
  │
  ├─ You work, optionally logging tasks:
  │    ├─ task-log.sh estimate → returns task_id
  │    ├─ task-log.sh start
  │    └─ task-log.sh complete
  │
  ├─ Session ends (or tab crashes)
  │    ├─ SessionEnd hook → session-end.sh
  │    │    ├─ Marks session ended
  │    │    ├─ Parses transcript (turns, bytes, compacts)
  │    │    └─ Appends summary to sessions.jsonl
  │    │
  │    └─ Stop hook → task-check.sh
  │         └─ Nudges once if no tasks were logged
  │
  └─ Later: cc-sessions.sh check
       └─ Finds orphaned sessions, offers resume
```

### Token Budgeting

LLMs can reason about output volume (tokens) but not wall-clock time. The harness tracks effort in tokens. For the research behind why tokens are replacing hours as the unit of estimation — from METR's agent decay curves to Devin's ACU model — see [Stop Estimating AI Work in Human-Hours](https://voxos.ai/blog/token-based-effort-estimation-for-ai-agents/index.html).

```bash
# Estimate before starting
TASK_ID=$(bash ~/.claude/hooks/task-log.sh estimate "$SESSION_ID" myproject api "Add auth middleware" 15000)

# Mark work started
bash ~/.claude/hooks/task-log.sh start "$SESSION_ID" "$TASK_ID"

# Record actual effort when done
bash ~/.claude/hooks/task-log.sh complete "$SESSION_ID" "$TASK_ID" 12000 4 "abc1234"
```

Query your data:

```bash
bash scripts/cc-budget.sh summary     # Totals across all sessions
bash scripts/cc-budget.sh sessions 5  # Last 5 sessions
bash scripts/cc-budget.sh projects    # Effort by project/service
bash scripts/cc-budget.sh accuracy    # Estimate vs. actual calibration
bash scripts/cc-budget.sh daily       # Today's breakdown
```

Example output:

```
=== Token Budget Summary ===
Sessions:        47
Total duration:  23.5h
Output tokens:   234.5k
Avg output/sess: 5.0k
Avg turns/sess:  8.2
Total compacts:  3
Total tasks:     12
```

### Skills

Skills are slash commands defined in `.claude/skills/<slug>/SKILL.md`. The harness ships with:

| Skill | What it does |
|-------|-------------|
| `/commit` | Stage diffs, generate commit message, commit |
| `/done` | Check if all session work is complete |
| `/queue` | Capture a task to QUEUE.md for a future session |
| `/nu` | Create a new skill from a description |
| `/preview` | Serve a markdown file as live HTML on localhost |

Create your own:

```
/nu deploy "Build the project, deploy to staging, invalidate CDN cache"
```

This creates `.claude/skills/deploy/SKILL.md` with structured instructions that Claude Code follows when you type `/deploy`.

### Maintenance Cadence

`MAINTENANCE.md` defines recurring tasks with cadences (session-start, hourly, daily). At each session start, Claude checks what's overdue and offers to run it:

```
2 maintenance tasks are overdue:
  - Reminders Triage (session-start, last run: 2h ago)
  - Memory & Doc Hygiene (1 hour, last run: 3h ago)
Run them?
```

### Persistent Memory

`.claude-memory/MEMORY.md` stores facts that survive across sessions:
- Key file paths and architecture decisions
- Environment quirks and platform-specific workarounds
- Patterns confirmed across multiple interactions

The setup script creates a directory junction so `~/.claude/projects/.../memory/` points into your repo. Memory files are version-controlled.

### Document Discipline

The `CLAUDE.md` template establishes three document types:

| Type | Examples | Rule |
|------|----------|------|
| **Living** | `CLAUDE.md`, `MILESTONES.md`, `GOTCHAS.md` | Update when behavior changes |
| **Snapshot** | `PRD.md`, `PLAN.md`, `DESIGN.md` | Never update; create new if decision changes |
| **Scrap** | Small TODOs, stubs | Clean up during hygiene |

### Prove It Loop

Every non-trivial change follows: **Baseline → Change → Measure → Compare → Record**.

No vibes. No "I think it's faster." Capture the metric before, capture it after, show the delta in the commit message.

## File Structure

After setup, your project gains:

```
your-project/
├── .claude/
│   ├── hooks/
│   │   ├── session-register.sh   # SessionStart → track session
│   │   ├── session-end.sh        # SessionEnd → parse transcript, write summary
│   │   ├── task-check.sh         # Stop → nudge if no tasks logged
│   │   ├── task-log.sh           # estimate/start/complete lifecycle
│   │   └── cc-sessions.sh        # Orphan detection utility
│   ├── skills/
│   │   ├── commit/SKILL.md
│   │   ├── done/SKILL.md
│   │   ├── queue/SKILL.md
│   │   ├── nu/SKILL.md
│   │   └── preview/SKILL.md
│   └── AGENTS.md                 # Skill registry
├── .claude-memory/
│   └── MEMORY.md                 # Persistent agent memory
├── scripts/
│   └── cc-budget.sh              # Token budget analytics CLI
├── CLAUDE.md                     # Project instructions (fill in your details)
├── MAINTENANCE.md                # Recurring maintenance cadence
├── REMINDERS.md                  # Follow-up tracker
├── GOTCHAS.md                    # Operational workarounds
└── MILESTONES.md                 # Progress tracker
```

Global files created/modified:

```
~/.claude/
├── settings.json                 # Hooks registered here
├── hooks/ → your-project/.claude/hooks/
├── skills/ → your-project/.claude/skills/
├── session-tracking/             # Per-session JSON files
└── task-tracking/
    ├── tasks.jsonl               # Task events (estimate/start/complete)
    └── sessions.jsonl            # Session summaries
```

## Data Format

### Session Tracking (`~/.claude/session-tracking/<id>.json`)

```json
{
  "session_id": "abc123-...",
  "pid": 12345,
  "cwd": "/path/to/project",
  "model": "claude-sonnet-4-6",
  "started_at": "2026-02-20T10:00:00Z",
  "ended_at": null,
  "status": "active"
}
```

### Task Events (`~/.claude/task-tracking/tasks.jsonl`)

```json
{"event":"estimate","session_id":"...","task_id":"myproject-api-1708300000","project":"myproject","service":"api","description":"Add auth middleware","estimated_tokens":15000,"timestamp":"2026-02-20T10:05:00Z"}
{"event":"start","session_id":"...","task_id":"myproject-api-1708300000","timestamp":"2026-02-20T10:05:01Z"}
{"event":"complete","session_id":"...","task_id":"myproject-api-1708300000","actual_tokens":12000,"files_changed":4,"commit_hash":"abc1234","timestamp":"2026-02-20T10:30:00Z"}
```

### Session Summaries (`~/.claude/task-tracking/sessions.jsonl`)

```json
{
  "session_id": "abc123-...",
  "model": "claude-sonnet-4-6",
  "started_at": "2026-02-20T10:00:00Z",
  "ended_at": "2026-02-20T10:45:00Z",
  "duration_minutes": 45,
  "estimated_output_tokens": 8500,
  "turn_count": 12,
  "compact_count": 0,
  "task_count": 2,
  "projects_touched": ["myproject"]
}
```

## Customization

### Adding your own skills

1. Run `/nu <slug> <description>` — or manually create `.claude/skills/<slug>/SKILL.md`
2. Register it in `.claude/AGENTS.md`
3. Use it with `/<slug>` in any session

### Adding maintenance tasks

Edit `MAINTENANCE.md` and add a new section following the format:

```markdown
### N. Task Name
- **Cadence:** session-start | 1 hour | 1 day | 1 week
- **Last run:** {{timestamp}}
- **What:** Description of what to check or do.
- **Output:** What gets updated.
```

### Disabling the task nudge

Remove the `Stop` hook from `~/.claude/settings.json` if you don't want the "no tasks logged" reminder.

### Multi-project setup

The hooks and skills directories are symlinked from `~/.claude/` to your repo. If you work across multiple repos, you can either:
- **Share hooks** — keep `~/.claude/hooks/` as a standalone directory (not linked to any repo)
- **Per-repo hooks** — re-run setup in each repo; the last one wins for the symlink

Task tracking data (`tasks.jsonl`, `sessions.jsonl`) is global by design — it tracks all sessions regardless of which repo they're in.

## Requirements

- **Claude Code** (any version with hooks support)
- **jq** — JSON processor ([install](https://jqlang.github.io/jq/download/))
- **bash** — works with bash 4+ on macOS/Linux, Git Bash on Windows
- **git** — for the setup script and version control of memory/hooks

## License

MIT

---

Built by [Voxos.ai](https://voxos.ai). We use this harness daily to run a 12-project monorepo with Claude Code.
