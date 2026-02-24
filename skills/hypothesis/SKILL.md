---
name: hypothesis
description: Hypothesis-driven A/B testing for code changes. Records hypothesis, generates baseline artifacts (Set A), then after changes generates variant artifacts (Set B) and delivers a verdict.
---

## Usage

```
/hypothesis start "<statement>" --profile <profile> [--project <slug>]
/hypothesis measure [--project <slug>]
/hypothesis show
/hypothesis cancel
```

Examples:
- `/hypothesis start "Refactoring the reducer prompt improves coherence by >1.0" --profile bench --project myapi`
- `/hypothesis start "Adding response caching reduces p95 latency by >100ms" --profile api --project backend`
- `/hypothesis start "Tree-shaking unused components cuts bundle size by >10%" --profile bundle --project frontend`
- `/hypothesis measure`

## Subcommands

### `start`

Records the hypothesis and generates Set A (baseline artifacts).

1. **Parse arguments.** Required: hypothesis string, `--profile` (one of: bench, api, bundle, test, infra, query). Optional: `--project` (inferred from cwd if omitted).

2. **Check for active hypothesis.** Read `.claude/skills/hypothesis/active.json`. If one exists and is in `awaiting_measure` state, warn the user and ask whether to cancel it or continue.

3. **Record the hypothesis.** Write `.claude/skills/hypothesis/active.json`:

```json
{
  "hypothesis": "<the statement>",
  "profile": "<profile>",
  "project": "<slug>",
  "state": "generating_set_a",
  "started_at": "<ISO timestamp>",
  "set_a": null,
  "set_b": null,
  "verdict": null
}
```

4. **Generate Set A.** Run the artifact generation for the given profile (see Artifact Generation below). Save the dimensions object.

5. **Update active.json** with Set A results and transition to `awaiting_measure`:

```json
{
  "state": "awaiting_measure",
  "set_a": {
    "generated_at": "<ISO>",
    "dimensions": { ... }
  }
}
```

6. **Print summary.** Show the hypothesis, profile, and Set A dimensions in a table. Tell the user: "Make your changes, then run `/hypothesis measure` to generate Set B and get the verdict."

### `measure`

Generates Set B (variant artifacts), compares against Set A, delivers verdict.

1. **Load active hypothesis.** Read `.claude/skills/hypothesis/active.json`. If none exists or state is not `awaiting_measure`, error: "No active hypothesis. Run `/hypothesis start` first."

2. **Generate Set B.** Run the same artifact generation as Set A, same profile, same project. Save dimensions.

3. **Compare.** For each dimension present in both Set A and Set B:
   - Compute delta (absolute and percentage)
   - Flag direction (improved, regressed, unchanged)

4. **Determine verdict.** Based on the hypothesis statement and the deltas:
   - **CONFIRMED** — the primary dimension moved in the hypothesized direction by at least the stated amount, no uncompensated regressions
   - **PARTIAL** — primary dimension improved but less than hypothesized, or a secondary dimension regressed meaningfully
   - **REJECTED** — primary dimension did not improve or regressed
   - **INCONCLUSIVE** — delta within noise floor (see Noise Floors below)

5. **Update active.json** with Set B results and verdict:

```json
{
  "state": "complete",
  "set_b": {
    "generated_at": "<ISO>",
    "dimensions": { ... }
  },
  "verdict": {
    "outcome": "CONFIRMED",
    "summary": "Coherence improved by 1.7 (>1.0 target). Cost regressed 10% but within acceptable range.",
    "dimensions": {
      "coherence": { "before": 6.1, "after": 7.8, "delta": 1.7, "pct": "+27.9%", "direction": "improved" },
      "composite": { "before": 7.2, "after": 7.6, "delta": 0.4, "pct": "+5.6%", "direction": "improved" },
      "cost_usd": { "before": 1.19, "after": 1.31, "delta": 0.12, "pct": "+10.1%", "direction": "regressed" }
    }
  },
  "completed_at": "<ISO>"
}
```

6. **Print verdict.** Display a table:

```
Hypothesis: Refactoring the reducer prompt improves coherence by >1.0
Verdict: CONFIRMED

Dimension        Set A     Set B     Delta      Direction
coherence        6.1       7.8       +1.7       improved
composite        7.2       7.6       +0.4       improved
cost ($)         $1.19     $1.31     +$0.12     regressed
time (s)         258       262       +4         regressed
```

7. **Print commit block.** Output the ready-to-paste commit message block:

```
Hypothesis: Refactoring the reducer prompt improves coherence by >1.0
Verdict: CONFIRMED
  coherence: 6.1 -> 7.8 (+1.7)
  composite: 7.2 -> 7.6 (+0.4)
  cost: $1.19 -> $1.31 (+10%)
  time: 258s -> 262s (+2%)
```

8. **Archive.** Copy `active.json` to `.claude/skills/hypothesis/history/<project>-<timestamp>.json`. Clear `active.json` (write `{}`).

### `show`

Read `.claude/skills/hypothesis/active.json`. If empty or `{}`, print "No active hypothesis." Otherwise print the hypothesis, profile, state, and Set A dimensions if available.

### `cancel`

Read `.claude/skills/hypothesis/active.json`. If active, archive it with `"state": "cancelled"` to history, clear active. Print confirmation.

## Artifact Generation

Each profile defines how to capture dimensions. All dimension values must be numeric (for delta computation).

### `bench` profile

Requires: project has a `bench/` directory with `ab.py`.

**Set A:**
```bash
cd <project-root> && python -m bench.ab run-local --label "hyp-set-a"
```
Run in background (3-8 min). When complete, read:
- `bench/ab_results/hyp-set-a/scores.json` for quality dimensions
- `bench/ab_results/hyp-set-a/metrics.json` for cost dimensions
- `bench/ab_results/hyp-set-a/timing.json` for time dimensions

Extract dimensions:
```json
{
  "composite": 7.2,
  "factual_accuracy": 8.1,
  "coherence": 6.1,
  "completeness": 7.5,
  "cost_usd": 1.19,
  "total_tokens": 68000,
  "time_s": 258
}
```

**Set B:**
```bash
cd <project-root> && python -m bench.ab run-local --label "hyp-set-b" --replay-plan "hyp-set-a"
```
Same extraction. Use `--replay-plan` to reuse shard assignments for a fair comparison.

### `api` profile

Requires: the endpoint URL and a representative request payload.

Ask the user for the endpoint URL and payload if not obvious from context.

**Set A and Set B** (same procedure):

Run 5 requests, capture timing:
```bash
for i in {1..5}; do
  curl -s -o /dev/null -w '%{time_total}\n' -X <METHOD> "<URL>" -H "Content-Type: application/json" -d '<payload>'
done
```

Extract dimensions:
```json
{
  "p50_ms": 142,
  "p95_ms": 287,
  "status_2xx": 5,
  "status_4xx": 0,
  "status_5xx": 0
}
```

For cold start measurement, add a 5-minute gap before the first request or invoke the Lambda directly.

### `bundle` profile

Requires: project has a `www/` directory with a build command.

**Set A and Set B** (same procedure):

```bash
cd <project-root>/www && npm run build 2>&1
```

Then measure:
```bash
du -sb <project-root>/www/dist/
ls <project-root>/www/dist/assets/*.js | wc -l
```

Extract dimensions:
```json
{
  "bundle_size_kb": 342,
  "js_chunk_count": 12,
  "build_warnings": 0
}
```

Parse build warnings from the build output (lines containing "warning" or "WARN").

### `test` profile

Requires: project has tests.

**Set A and Set B** (same procedure):

For Python:
```bash
cd <project-root> && python -m pytest --tb=short -q 2>&1
```

For Node:
```bash
cd <project-root>/www && npx jest --ci 2>&1
```

Extract dimensions:
```json
{
  "passed": 45,
  "failed": 0,
  "skipped": 2,
  "coverage_pct": 78.3
}
```

### `infra` profile

Requires: project has an `infrastructure/` directory with Terraform.

**Set A:** Run `terraform plan` before changes, capture resource summary.
**Set B:** Run `terraform plan` after changes, capture resource summary.

```bash
cd <project-root>/infrastructure && terraform plan -no-color 2>&1 | tail -5
```

Extract dimensions:
```json
{
  "resources_add": 0,
  "resources_change": 2,
  "resources_destroy": 0
}
```

### `query` profile

Requires: specific database table and query to benchmark.

Ask the user for the table name, query parameters, and connection details.

**Set A and Set B** (same procedure):

Run the query 5 times, capture consumed capacity or execution time.

Extract dimensions:
```json
{
  "avg_read_units": 5.2,
  "items_returned": 23,
  "query_count": 5
}
```

## Noise Floors

Deltas below these thresholds produce an INCONCLUSIVE verdict on that dimension:

| Profile | Dimension | Noise floor |
|---------|-----------|-------------|
| `bench` | Any LLM-judged score | 0.5 points |
| `api` | Response time | 10% or 20ms (whichever is larger) |
| `bundle` | Bundle size | 5% or 5KB (whichever is larger) |
| `test` | Pass/fail count | 0 (exact) |
| `infra` | Resource count | 0 (exact) |
| `query` | Read units consumed | 10% |

## History

Completed and cancelled hypotheses are archived to `.claude/skills/hypothesis/history/`. Filename format: `<project>-<YYYYMMDD-HHMMSS>.json`.

This history serves as a log of what was tested, what worked, and what didn't. Reference it when deciding what to try next.
