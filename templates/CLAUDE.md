# {{PROJECT_NAME}}

> Replace `{{PLACEHOLDERS}}` with your values. Delete this line when done.

## Ethos

1. When you write something intended to be read by an important person, go through it and cut every unnecessary word.
2. The reader of anything you publish is an important person.
3. Every non-trivial change must be proven with numbers, not vibes. Measure before, measure after, show the delta.

## Knowledge Map

- **Build / deploy / test**: `MAKE.md`
- **Operational workarounds**: `GOTCHAS.md`
- **Project milestones**: `MILESTONES.md`
- **Agent memory**: `.claude-memory/MEMORY.md`
- **Pending follow-ups**: `REMINDERS.md`
- **Recurring maintenance**: `MAINTENANCE.md`
- **Skills & agents**: `.claude/AGENTS.md`

## Architecture Map

| Component | What it does | Stack |
|-----------|-------------|-------|
| **{{service}}** | ... | ... |

## General

- Use multiple-choice option interface to ask for clarification
- Employ long-term solutions — not monkey patches
- Verify your work (curl, tests, manual checks) to create production-grade systems
- Track progress in `MILESTONES.md`
- Log deployment/development gotchas in `GOTCHAS.md`
- Follow the **Prove It** discipline below for any non-trivial change

## Prove It

Every non-trivial change (>3 files or any behavioral change) follows this loop:

1. **Baseline** — capture the current metric before touching code
2. **Change** — implement the change
3. **Measure** — capture the same metric after the change
4. **Compare** — show the delta (absolute + percentage)
5. **Record** — include the comparison in the commit message or PR description

**Exempt:** typos, comments, single-line bug fixes, pure config with no behavioral impact.

### What to Measure

| Change type | Metric | How |
|-------------|--------|-----|
| LLM pipeline | Quality score, cost, latency, token count | A/B scorer |
| API endpoint | Response time (p50/p95), error rate | `curl -w` timing |
| Frontend | Bundle size, Lighthouse score | `du -sh dist/`, Lighthouse |
| Data pipeline | Throughput, accuracy, cost per run | Timed test runs |

## Token Budgeting

Estimate effort in **tokens**, never in time. LLMs cannot predict wall-clock time, but can reason about output volume.

### Task Lifecycle

For every non-trivial task:

```bash
# 1. Estimate — returns a task_id
bash ~/.claude/hooks/task-log.sh estimate "$SESSION_ID" <project> <service> "<description>" <estimated_tokens>

# 2. Start — records work-begin timestamp
bash ~/.claude/hooks/task-log.sh start "$SESSION_ID" <task_id>

# 3. Complete — records actuals
bash ~/.claude/hooks/task-log.sh complete "$SESSION_ID" <task_id> <actual_tokens_est> <files_changed> [commit_hash]
```

### Estimation Guide

| Size | Tokens | Examples |
|------|--------|----------|
| Small | 2-5k | Config change, single-file bug fix, add a route |
| Medium | 10-30k | New feature across 3-5 files, refactor a module |
| Large | 50-100k | Multi-service feature, new pipeline stage |
| XL | 100k+ | New project scaffolding, major architectural change |

### Exemptions

Do NOT log tasks for: single-line fixes, reading/exploring code, answering questions, maintenance checks.

### Analytics

Run `bash scripts/cc-budget.sh summary|sessions|projects|accuracy|daily` for aggregated metrics.

## Document Maintenance

### Doc types

| Type | Examples | Rule |
|------|----------|------|
| **Living** | `CLAUDE.md`, `MILESTONES.md`, `GOTCHAS.md`, `REMINDERS.md` | Must reflect current system state. Update when you change the behavior they describe. |
| **Snapshot** | `PRD.md`, `PLAN.md`, `DESIGN.md` | Captured a point-in-time decision. Never update; create a new doc if the decision changes. |
| **Scrap** | `TODOs.md` (<20 lines), stubs | Ignore. Clean up during weekly hygiene if noticed. |

### When to update living docs

Update when you change **how the system works** — new stages, changed infrastructure, new APIs.

Do NOT update for: prompt tuning, model swaps, bug fixes, config changes, or anything that doesn't change the documented behavior.

### Milestone hygiene

When a phase in `MILESTONES.md` is fully complete, collapse it into a single summary line referencing the commit hash. Carry forward any remaining `[ ]` items into an "Open Items" section.

## Session Sign-off

End every session with a one-line summary:

`<commit-hash> <project(s)>: <what was done> | ~Nk tokens, M tasks`

## Maintenance Cadence

At the start of every session, read `MAINTENANCE.md`. Compare each task's `last_run` against its cadence. If any tasks are overdue, notify the user. Run overdue tasks in priority order. Update `last_run` timestamps after completion.
