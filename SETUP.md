# Agent Setup Instructions

This file is for Claude Code (or any AI coding agent). When a user asks you to install or set up TAS, follow these steps in order.

## Prerequisites

Verify these exist before proceeding. If any are missing, tell the user what to install and stop.

- `jq` — run `jq --version`
- `git` — run `git --version`
- `bash` — run `bash --version`
- The current working directory must be inside a git repository — run `git rev-parse --show-toplevel`

## Step 1: Run the setup script

```bash
bash <path-to-tas>/setup.sh
```

Replace `<path-to-tas>` with the actual path where this repo was cloned. If you cloned it to a temp directory, use that path.

This script installs hooks, skills, templates, memory directory, analytics, and data directories. It is safe to re-run — it skips files that already exist.

## Step 2: Fill in template variables

The setup script copies template files with placeholder values. Replace these with real values. Ask the user for any value you cannot infer from the repository.

### CLAUDE.md

| Placeholder | What to fill in | How to infer |
|-------------|----------------|--------------|
| `{{PROJECT_NAME}}` | The project name | Use the repo directory name or ask the user |
| `{{service}}` | Each service/component in the project | Scan the repo structure for directories like `api/`, `www/`, `app/`, `infrastructure/`, `worker/`, `lib/`, etc. Create one Architecture Map row per service found. If none are obvious, ask the user. |

Also delete the instruction line: `> Replace {{PLACEHOLDERS}} with your values. Delete this line when done.`

### .claude-memory/MEMORY.md

| Placeholder | What to fill in |
|-------------|----------------|
| `{{YYYY-MM-DD}}` | Today's date in YYYY-MM-DD format |

### MILESTONES.md

| Placeholder | What to fill in |
|-------------|----------------|
| `{{Phase Name}}` | Ask the user what their current milestone or project phase is called. If they don't have one, use "Initial Setup" |

## Step 3: Verify installation

Run these checks and confirm each passes:

1. `.claude/hooks/` exists and contains `.sh` files (expect 8: session-register, session-end, task-check, task-log, cc-sessions, cc-recover, input-capture, input-analytics)
2. `.claude/skills/` exists and contains skill directories (expect 10: done, queue, nu, preview, code-audit, brainstorm, recover, attention, pentest, idea-mining)
3. `.claude-memory/MEMORY.md` exists
4. `CLAUDE.md` exists at repo root with no remaining `{{` placeholders
5. `MAINTENANCE.md` exists at repo root
6. `scripts/cc-budget.sh` exists and is executable
7. `~/.claude/settings.json` contains hooks for `SessionStart`, `SessionEnd`, `Stop`, and `UserPromptSubmit`
8. Data directories exist: `~/.claude/session-tracking/`, `~/.claude/task-tracking/`, `~/.claude/input-telemetry/`

## Step 4: Confirm to the user

Tell the user setup is complete and mention:

- 10 slash commands are available: `/done`, `/queue`, `/nu`, `/preview`, `/code-audit`, `/brainstorm`, `/recover`, `/attention`, `/pentest`, `/idea-mining`
- Session tracking and token budgeting are active automatically
- Input telemetry captures every prompt for later analysis
- They should review `CLAUDE.md` and adjust the Architecture Map and General sections to match their project's specifics

## Notes

- If `CLAUDE.md` or other template files already exist, the setup script skips them. If the user wants to overwrite, they must delete the existing file first.
- The setup script creates symlinks (or Windows directory junctions) from `~/.claude/hooks/` and `~/.claude/skills/` to the repo's `.claude/` directory. If the user works across multiple repos, only the last-installed repo's hooks/skills will be active globally.
- Template variable replacement is a one-time operation. After filling in placeholders, these files become living documents maintained by the agent during normal work.
