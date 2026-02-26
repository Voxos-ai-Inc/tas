# {{PROJECT_NAME}}

> Replace `{{PLACEHOLDERS}}` with your values. Delete this line when done.

## Ethos

1. When you write something intended to be read by an important person, go through it and cut every unnecessary word.
2. The reader of anything you publish is an important person.
3. Every non-trivial change must be proven with numbers, not vibes. Measure before, measure after, show the delta.

## Knowledge Map

- **Operational workarounds**: `GOTCHAS.md`
- **Project milestones**: `MILESTONES.md`
- **Agent memory**: `.claude-memory/MEMORY.md`
- **Pending follow-ups**: `REMINDERS.md`
- **Recurring maintenance**: `MAINTENANCE.md`
- **Skills & agents**: `.claude/AGENTS.md`
- **Token budgeting**: "Token Budgeting" section below; analytics via `scripts/cc-budget.sh`
- **Input telemetry**: "Input Telemetry" section below; analytics via `bash ~/.claude/hooks/input-analytics.sh`

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
- Follow the **Hypothesis Protocol** below for any non-trivial change
- When fixing a bug or data issue, fix the system that produced the bad state, not just the bad data. Ad-hoc patches are acceptable as immediate stopgaps but must be followed by a tracked TODO in MILESTONES.md.
- When a user is actively engaged (mid-flow, viewing results), never gate the next step behind a data capture (email, signup, survey). Data capture belongs at natural pauses, not when the user has attention and intent.

## Security Posture

Treat these as non-negotiable build constraints.

### Secrets

- **Never** hardcode secrets, API keys, tokens, or passwords in source code, Terraform locals, or environment variable defaults.
- All secrets go in a secrets manager (e.g., AWS Secrets Manager, SSM Parameter Store SecureString, Vault). Reference them by ARN or path in config; fetch at runtime.
- Never log secrets. If a value *might* be a secret, treat it as one.
- Never commit `.env` files, credential JSON, or private keys. `.gitignore` must block them.

### Auth & Access

- Every API endpoint must authenticate callers. No anonymous write endpoints. Public read endpoints require explicit justification.
- Use least-privilege IAM/RBAC policies. No wildcard resource on write/admin actions. Scope to specific resources.
- Lambda/function execution roles get only the permissions they need — no shared "god role."
- CORS: allow only the specific origins that need access, never `*` in production.

### Data Protection

- All data in transit: TLS only. No HTTP endpoints.
- All data at rest: encrypted. Database tables use managed encryption. Storage buckets use server-side encryption.
- PII fields (email, name, phone) must be identified in schema comments. Never log PII.
- Storage buckets: block public access by default. If a bucket must be public (e.g., static site assets), document why.

### Input Validation

- Validate and sanitize all external input at the API boundary. Never trust client-supplied data.
- Parameterize all database queries — never string-interpolate user input into expressions.
- Frontend: escape rendered content. Never use `dangerouslySetInnerHTML` or equivalent without explicit approval.

### Dependency Hygiene

- Pin dependency versions. No floating `latest` tags in production Dockerfiles or requirements files.
- Review new dependencies before adding them. Prefer well-maintained packages with active security response.
- Audit findings with severity >= high must be resolved before deploy.

### Logging & Audit Trail

- All state-changing API calls must produce a log entry with: timestamp, caller identity, action, and affected resource.
- Cloud audit logging must be enabled on all accounts. Do not disable or filter it.
- Retain logs for >= 90 days.

### Agent-Specific Rules

- When writing Terraform/IaC, never create IAM policies with `"Effect": "Allow", "Action": "*"` or `"Resource": "*"` on mutating actions.
- When adding a new API route, default to requiring auth. Ask before making it public.
- When creating storage buckets, always include public access blocks unless the user explicitly says otherwise.
- If you spot a security violation in existing code while working on something else, flag it.

## Hypothesis Protocol

Every non-trivial change (>3 files or any behavioral change) is hypothesis-driven. Work begins with a falsifiable statement and ends with a verdict.

### Sequence

1. **Hypothesis** — state what you expect: "Changing X will [improve/fix/enable] Y by [amount/direction] because [reasoning]." The hypothesis constrains which dimensions to measure and sets the acceptance criterion.
2. **Set A (Baseline)** — generate artifacts from the current code using the appropriate artifact profile. Save results.
3. **Change** — implement the change.
4. **Set B (Variant)** — generate the same artifacts from the new code, same profile, same inputs.
5. **Verdict** — compare Set A vs Set B per dimension. Accept or reject the hypothesis. Record in commit message.

**Exempt:** typos, comments, single-line bug fixes, pure infra/config with no behavioral impact, changes where the only artifact is "does the test pass" (just run the test).

### Artifact Profiles

Each profile defines what Set A and Set B contain. Use the profile matching your change type.

| Profile | When | Dimensions | How to generate |
|---------|------|------------|-----------------|
| `bench` | LLM pipeline changes | Quality composite, per-dimension scores, cost ($), tokens, time per stage | A/B scorer or bench test runner |
| `api` | API endpoint changes | Response time (p50/p95), cold start, status codes, error rate | `curl -w` timing, monitoring |
| `bundle` | Frontend changes | Bundle size (KB), chunk count, build warnings | `du -sh dist/`, build output |
| `test` | Logic/refactor changes | Pass count, fail count, coverage % | `pytest`/`jest` output |
| `infra` | Terraform/IaC changes | Resource count delta, estimated monthly cost delta | `terraform plan` output |
| `query` | Database/data changes | Read units consumed, query latency | Database metrics snapshot |

When a change spans multiple profiles (e.g., API + frontend), capture artifacts for each.

### Verdict Format

Verdicts are one of:

- **CONFIRMED** — primary dimension moved in the hypothesized direction, no axis strictly worse without compensation
- **PARTIAL** — primary dimension improved but less than hypothesized, or a secondary dimension regressed
- **REJECTED** — primary dimension did not improve, or the change made things strictly worse
- **INCONCLUSIVE** — delta is within noise floor (e.g., <0.5 for LLM judge scores, <5% for timing)

### Commit Format

```
<type>(<project>): <short description>

Hypothesis: <the falsifiable statement>
Verdict: <CONFIRMED|PARTIAL|REJECTED|INCONCLUSIVE>
  <dimension>: <before> -> <after> (<delta>)
  <dimension>: <before> -> <after> (<delta>)
```

Example:
```
feat(myproject): tighten reducer instructions

Hypothesis: Constraining reducer output structure improves coherence by >1.0
Verdict: CONFIRMED
  coherence: 6.1 -> 7.8 (+1.7)
  composite: 7.2 -> 7.6 (+0.4)
  cost: $1.19 -> $1.31 (+10%)
  time: 258s -> 262s (+2%)
```

For exempt changes, a standard before/after one-liner is sufficient:
`Before: <state>. After: <state>.`

## Cost Tracking

Every change that touches LLM calls, database operations, scheduled tasks, or third-party APIs must include an estimated cost impact:

- **LLM changes**: tokens in/out x model pricing.
- **Database changes**: new indexes = new read/write units. Query pattern changes = read amplification risk.
- **Scheduled task changes**: compute x expected runtime. Task definition changes = new baseline cost.
- **Third-party APIs**: per-call pricing x expected volume.

Format: include a one-line cost note in the commit message, e.g. `Cost: ~$0.02/run increase (extra map shard)` or `Cost: neutral (refactor only)`.

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

## Input Telemetry

Every user prompt is captured automatically by the `UserPromptSubmit` hook. This enables analysis of how you interact with Claude Code over time.

### What's Captured

Each message records: timestamp, session ID, project (inferred from cwd), text, word count, character count.

### Analytics

```bash
bash ~/.claude/hooks/input-analytics.sh summary           # Totals: messages, sessions, projects
bash ~/.claude/hooks/input-analytics.sh project <slug>     # Per-project breakdown
bash ~/.claude/hooks/input-analytics.sh recent 20          # Last 20 messages
bash ~/.claude/hooks/input-analytics.sh trends             # Daily message volume
bash ~/.claude/hooks/input-analytics.sh tabs               # Tab concurrency stats
```

### Session Sign-off Analysis

At the end of each session, classify your messages across 4 dimensions and append to `~/.claude/input-telemetry/analyzed.jsonl`:

- **intent**: feature | bugfix | deploy | research | refactor | admin | question | review | planning
- **specificity**: 1-5 (1=vague wish, 5=exact spec with file paths)
- **complexity**: 1-5 (1=single file, 5=multi-service orchestration)
- **tone**: directive | collaborative | exploratory | frustrated | urgent | casual

Then run `bash ~/.claude/hooks/input-analytics.sh dimensions` for distribution analysis.

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

## Worktree Workflow

When working on an isolated change:
1. `git worktree add .worktrees/<short-name>`
2. Work and commit there. Merge back to your main branch when done.
3. Skip worktree for: small fixes, single-file changes, quick tasks.

## Maintenance Cadence

At the start of every session, read `MAINTENANCE.md`. Compare each task's `last_run` against its cadence. If any tasks are overdue, notify the user. Run overdue tasks in priority order. Update `last_run` timestamps after completion.
