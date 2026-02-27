# TAS: Tracking, Automation, and Skills

<p align="center">
  <img src=".github/tas-logo.png" width="180" />
</p>

<p align="center">
  <em>A whirlwind of discipline for Claude Code.</em>
</p>

Ever watched a Tasmanian devil work? It's chaos from the outside: teeth, claws, fur flying in every direction. But look closer. Every movement has a purpose. Nothing is wasted. The tornado *is* the efficiency.

TAS brings that energy to Claude Code. Session tracking, token budgeting, 10 slash commands, maintenance cadence, persistent memory, all spinning at once, all under control.

You don't manage TAS. You install it and let it do its thing.

## What You Get

| Layer | What it does | Files |
|-------|-------------|-------|
| **Session tracking** | Auto-registers every session. Detects orphaned sessions (crashed tabs). Offers `--resume`. Tracks tab concurrency. | `hooks/session-register.sh`, `hooks/session-end.sh`, `hooks/cc-sessions.sh`, `hooks/cc-recover.sh` |
| **Token budgeting** | Estimate effort in tokens, not time. Track estimate vs. actual. Calibrate over sessions. Real token counts from transcripts. Cost calculation. | `hooks/task-log.sh`, `hooks/task-check.sh`, `scripts/cc-budget.sh` |
| **Input telemetry** | Capture every prompt. Analyze message volume, complexity, intent. Track tab concurrency over time. | `hooks/input-capture.sh`, `hooks/input-analytics.sh` |
| **Skills** | 10 slash commands (`/done`, `/queue`, `/preview`, `/code-audit`, `/brainstorm`, `/recover`, `/attention`, `/pentest`, `/idea-mining`). Create your own with `/nu`. | `.claude/skills/<slug>/SKILL.md` |
| **Maintenance cadence** | Recurring tasks checked at session start. Overdue tasks surfaced automatically. | `MAINTENANCE.md` |
| **Persistent memory** | Key facts survive across sessions. Version-controlled in your repo. | `.claude-memory/MEMORY.md` |
| **Document discipline** | Living docs vs. snapshots vs. scrap , clear rules for what gets updated and when. | `CLAUDE.md` template |
| **Hypothesis Protocol** | Hypothesis → Set A → Change → Set B → Verdict. No vibes-based development. | `CLAUDE.md` template |
| **Security Posture** | Non-negotiable security constraints: secrets management, auth, input validation, least-privilege, audit logging. | `CLAUDE.md` template |

## Setup

### Option A: Let Claude Code do it

Open Claude Code in your project and say:

```
Set up TAS from github.com/Voxos-ai-Inc/tas
```

Claude Code will clone the repo, run the setup script, fill in your project-specific template variables, and verify the installation. It follows [`SETUP.md`](SETUP.md) to handle everything, including the configuration that manual setup leaves for you to do by hand.

### Option B: Manual

```bash
git clone https://github.com/Voxos-ai-Inc/tas.git /tmp/tas
cd /path/to/your/project
bash /tmp/tas/setup.sh
```

Or run directly:

```bash
curl -fsSL https://raw.githubusercontent.com/Voxos-ai-Inc/tas/main/setup.sh | bash
```

The setup script:
1. Copies hooks to `.claude/hooks/` and links them to `~/.claude/hooks/`
2. Installs starter skills to `.claude/skills/`
3. Registers `SessionStart`, `SessionEnd`, `Stop`, and `UserPromptSubmit` hooks in `~/.claude/settings.json`
4. Creates template files (`CLAUDE.md`, `MAINTENANCE.md`, `REMINDERS.md`, `GOTCHAS.md`, `MILESTONES.md`)
5. Sets up `.claude-memory/` for persistent agent memory
6. Creates data directories for session tracking, task tracking, and input telemetry

After running, edit `CLAUDE.md` to replace `{{PLACEHOLDER}}` values with your project details.

**Prerequisites:** `jq`, `git`, `bash`. Works on macOS, Linux, and Windows (Git Bash / MSYS2).

## How It Works

### Session Lifecycle

```
Session start
  │
  ├─ SessionStart hook fires
  │    ├─ session-register.sh → ~/.claude/session-tracking/<id>.json
  │    └─ Tab concurrency event → input-telemetry/concurrency.jsonl
  │
  ├─ Each user message:
  │    └─ input-capture.sh → input-telemetry/raw.jsonl
  │
  ├─ You work, optionally logging tasks:
  │    ├─ task-log.sh estimate → returns task_id
  │    ├─ task-log.sh start
  │    └─ task-log.sh complete
  │
  ├─ Session ends (or tab crashes)
  │    ├─ SessionEnd hook → session-end.sh
  │    │    ├─ Marks session ended
  │    │    ├─ Parses transcript (real token counts, tool usage, projects)
  │    │    ├─ Calculates estimated API cost
  │    │    └─ Appends summary to sessions.jsonl
  │    │
  │    └─ Stop hook → task-check.sh
  │         └─ Nudges once if no tasks were logged
  │
  └─ Later: cc-sessions.sh check
       └─ Finds orphaned sessions, offers resume
```

### Token Budgeting

LLMs can reason about output volume (tokens) but not wall-clock time. TAS tracks effort in tokens.

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
bash scripts/cc-budget.sh sessions 5  # Last 5 sessions (with cost + model)
bash scripts/cc-budget.sh projects    # Effort by project/service
bash scripts/cc-budget.sh accuracy    # Estimate vs. actual calibration
bash scripts/cc-budget.sh daily       # Today's breakdown (with top tools)
```

Example output:

```
=== Token Budget Summary ===
Sessions:        47
Total duration:  23.5h
Output tokens:   234.5k
Input tokens:    1205.3k
Cache create:    890.2k
Cache read:      15420.1k
Total cost:      $127.45
Avg output/sess: 5.0k
Avg turns/sess:  8.2
Total compacts:  3
Total tasks:     12
```

### Input Telemetry

Every user prompt is automatically captured and can be analyzed across multiple dimensions.

```bash
bash ~/.claude/hooks/input-analytics.sh summary          # Totals + tab stats
bash ~/.claude/hooks/input-analytics.sh project myapp    # Per-project breakdown
bash ~/.claude/hooks/input-analytics.sh recent 20        # Last 20 messages
bash ~/.claude/hooks/input-analytics.sh trends           # Daily volume
bash ~/.claude/hooks/input-analytics.sh dimensions       # Intent/complexity/tone analysis
bash ~/.claude/hooks/input-analytics.sh tabs             # Tab concurrency timeline
```

### Skills

Skills are slash commands defined in `.claude/skills/<slug>/SKILL.md`. TAS ships with:

| Skill | What it does |
|-------|-------------|
| `/done` | Check if all session work is complete |
| `/queue` | Capture a task to QUEUE.md for a future session |
| `/nu` | Create a new skill from a description |
| `/preview` | Serve a markdown file as live HTML on localhost |
| `/code-audit` | Recursive code-path audit across all user journeys |
| `/brainstorm` | 5-lens parallel web research for strategic decisions |
| `/recover` | Find and resume orphaned sessions after crashes |
| `/attention` | Audit frontend golden-path clarity scores |
| `/pentest` | External penetration test reconnaissance |
| `/idea-mining` | Bulk ideation with web-search novelty filtering |

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

### Hypothesis Protocol

Every non-trivial change follows: **Hypothesis → Set A (Baseline) → Change → Set B (Variant) → Verdict**.

No vibes. State what you expect, capture artifacts before, capture them after, compare dimensions, accept or reject. The verdict goes in the commit message.

## File Structure

After setup, your project gains:

```
your-project/
├── .claude/
│   ├── hooks/
│   │   ├── session-register.sh   # SessionStart → track + tab concurrency
│   │   ├── session-end.sh        # SessionEnd → parse transcript, cost, summary
│   │   ├── task-check.sh         # Stop → nudge if no tasks logged
│   │   ├── task-log.sh           # estimate/start/complete lifecycle
│   │   ├── cc-sessions.sh        # Orphan detection utility
│   │   ├── cc-recover.sh         # Session recovery (launch in new tabs)
│   │   ├── input-capture.sh      # UserPromptSubmit → capture prompts
│   │   └── input-analytics.sh    # Input telemetry analytics CLI
│   ├── skills/
│   │   ├── done/SKILL.md
│   │   ├── queue/SKILL.md
│   │   ├── nu/SKILL.md
│   │   ├── preview/SKILL.md
│   │   ├── code-audit/SKILL.md
│   │   ├── brainstorm/SKILL.md
│   │   ├── recover/SKILL.md
│   │   ├── attention/SKILL.md
│   │   ├── pentest/SKILL.md
│   │   ├── idea-mining/SKILL.md
│   └── AGENTS.md                 # Skill registry
├── .claude-memory/
│   └── MEMORY.md                 # Persistent agent memory
├── scripts/
│   └── cc-budget.sh              # Token budget analytics CLI
├── CLAUDE.md                     # Project instructions (fill in your details)
├── MAINTENANCE.md                # Recurring maintenance cadence
├── REMINDERS.md                  # Follow-up tracker
├── GOTCHAS.md                    # Operational workarounds log
└── MILESTONES.md                 # Progress tracker
```

Global files created/modified:

```
~/.claude/
├── settings.json                 # Hooks registered here
├── hooks/ → your-project/.claude/hooks/
├── skills/ → your-project/.claude/skills/
├── session-tracking/             # Per-session JSON files
├── task-tracking/
│   ├── tasks.jsonl               # Task events (estimate/start/complete)
│   └── sessions.jsonl            # Session summaries (with real token counts)
└── input-telemetry/
    ├── raw.jsonl                 # Every user prompt captured
    ├── analyzed.jsonl            # Dimensional classifications (after analysis)
    └── concurrency.jsonl         # Tab open/close events
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
{"event":"complete","session_id":"...","task_id":"myproject-api-1708300000","reported_tokens":12000,"files_changed":4,"commit_hash":"abc1234","timestamp":"2026-02-20T10:30:00Z"}
```

### Session Summaries (`~/.claude/task-tracking/sessions.jsonl`)

```json
{
  "session_id": "abc123-...",
  "model": "claude-sonnet-4-6",
  "started_at": "2026-02-20T10:00:00Z",
  "ended_at": "2026-02-20T10:45:00Z",
  "duration_minutes": 45,
  "output_tokens": 8500,
  "input_tokens": 42000,
  "cache_creation_tokens": 35000,
  "cache_read_tokens": 180000,
  "estimated_cost_usd": 1.23,
  "turn_count": 12,
  "compact_count": 0,
  "tool_counts": {"Write": 5, "Read": 12, "Bash": 3},
  "task_count": 2,
  "projects_touched": ["myproject"]
}
```

### Input Telemetry (`~/.claude/input-telemetry/raw.jsonl`)

```json
{"ts":"2026-02-20T10:05:00Z","session_id":"abc123","project":"myproject","text":"Add auth middleware to the API","word_count":6,"char_count":30}
```

## Customization

### Adding your own skills

1. Run `/nu <slug> <description>` , or manually create `.claude/skills/<slug>/SKILL.md`
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

### Disabling input telemetry

Remove the `UserPromptSubmit` hook from `~/.claude/settings.json` if you don't want prompt capture.

### Adjusting cost calculation

Edit the pricing rates in `hooks/session-end.sh` (around line 115). Default rates are for Claude Sonnet. Adjust for your model:

| Model | Input ($/1M) | Output ($/1M) |
|-------|-------------|---------------|
| Opus | $15 | $75 |
| Sonnet | $3 | $15 |
| Haiku | $0.80 | $4 |

### Multi-project setup

The hooks and skills directories are symlinked from `~/.claude/` to your repo. If you work across multiple repos, you can either:
- **Share hooks** , keep `~/.claude/hooks/` as a standalone directory (not linked to any repo)
- **Per-repo hooks** , re-run setup in each repo; the last one wins for the symlink

Task tracking data (`tasks.jsonl`, `sessions.jsonl`) and input telemetry are global by design , they track all sessions regardless of which repo they're in.

## Benchmark

Does TAS actually help? The `bench/` directory includes a benchmark suite to measure it. 11 tasks across three categories (bug fixes, multi-file features, refactoring) run under both conditions , vanilla Claude Code vs. TAS-equipped , and compare success rate, wall time, cost, and turns with paired statistical tests.

```bash
cd bench
pip install -r requirements.txt
python runner.py run --label my-test --trials 3
python compare.py my-test --by-category
```

See `bench/README.md` for full methodology.

## Requirements

- **Claude Code** (any version with hooks support)
- **jq** , JSON processor ([install](https://jqlang.github.io/jq/download/))
- **bash** , works with bash 4+ on macOS/Linux, Git Bash on Windows
- **git** , for the setup script and version control of memory/hooks


## Limitations

- **Single-repo symlinks**: `~/.claude/hooks` and `~/.claude/skills` are symlinked to one repo at a time. If you work across multiple repos, the last `setup.sh` run wins. See "Multi-project setup" above for workarounds.
- **Raw prompt storage**: Input telemetry stores your prompts as plaintext in `~/.claude/input-telemetry/raw.jsonl`. These files are local-only (never uploaded), but be aware they exist if you share your machine or home directory.
- **jq dependency**: All hooks and analytics scripts require `jq`. If `jq` is unavailable, hooks will silently fail rather than block your Claude Code session.
- **Bash 4+ required**: Some features (associative arrays in analytics) need bash 4+. macOS ships bash 3 by default; install bash 5 via Homebrew.

## FAQ

**What does TAS stand for?**

It's named after the Tasmanian devil. But if you need a backronym for a slide deck: **T**racking, **A**utomation & **S**kills.

## License

MIT

---

Built by [Voxos.ai](https://voxos.ai). We use TAS daily across a multi-project monorepo with Claude Code.
