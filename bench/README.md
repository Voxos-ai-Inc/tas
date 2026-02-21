# Harness Benchmark

Does operational scaffolding make AI coding agents better? This benchmark measures it.

## The Hypothesis

Giving Claude Code structured context (CLAUDE.md, prove-it discipline, gotchas, memory) produces better outcomes than running it cold. Prior research supports this:

- **AGENTS.md study** (Jan 2026): repos with agent instructions show 28.6% less runtime, 16.6% fewer tokens ([paper](https://arxiv.org/abs/2601.20404))
- **Confucius Code Agent** (Meta/Harvard): weaker model + strong scaffold outperforms stronger model + weak scaffold ([paper](https://arxiv.org/abs/2512.10398))
- **METR time-horizon data**: agents degrade sharply on longer tasks — scaffolding should close this gap ([blog](https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/))

## Design

Two conditions tested against the same tasks:

| | Vanilla | Harness |
|---|---|---|
| CLAUDE.md | None | Full template with knowledge map, prove-it loop, gotchas |
| Memory | None | `.claude-memory/MEMORY.md` |
| Living docs | None | `GOTCHAS.md`, `REMINDERS.md` |

### Task Categories

| Category | Tasks | What it tests |
|---|---|---|
| Single-file | 4 | Bug fixes in a Python stats library (off-by-one, empty list handling, cascading bugs) |
| Multi-file | 5 | Feature additions across a task manager (search, priority, export, tags, due dates) |
| Refactor | 2 | Structural changes (service extraction, type hints) |

### Metrics

| Metric | How |
|---|---|
| Task success | All tests pass (binary) |
| Wall time | Clock time for the full trial |
| Cost | `total_cost_usd` from Claude CLI |
| Turns | Agent turns (API round-trips) |
| Files changed | Diff against template |

### Statistics

Paired comparison: each task is run under both conditions. Wilcoxon signed-rank test for significance. Reports median + IQR, not mean.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Verify templates work
python runner.py verify pylib
python runner.py verify taskmanager

# List available tasks
python runner.py list

# Run a single task (both conditions, 3 trials each)
python runner.py run --label test-v1 --task fix-average --trials 3

# Run the full benchmark
python runner.py run --label baseline-v1 --trials 3

# Run only one condition
python runner.py run --label vanilla-only --condition vanilla --trials 3

# Compare results
python compare.py baseline-v1
python compare.py baseline-v1 --by-category
```

## Results Format

Each labeled run saves to `results/<label>/`:

```
results/<label>/
├── config.json      # Run configuration (model, trials, tasks)
└── results.json     # Per-trial results with all metrics
```

### Example Output

```
=== baseline-v1: Vanilla vs Harness ===

Metric                           vanilla          harness            Delta
------------------------------------------------------------------------
  Success rate                       64%              82%    +18.0 (+28%)
  Wall time (median, s)             87.3             65.1   -22.2 (-25%)
  Cost (median, $)               $0.0412          $0.0298  -$0.0114 (-28%)
  Turns (median)                    12.0              8.0    -4.0 (-33%)
  Files changed (median)            3.0              2.0    -1.0 (-33%)

  Wilcoxon (wall_time): W=12.0, p=0.0234 (sig: YES)
  Wilcoxon (cost): W=15.0, p=0.0312 (sig: YES)
```

## Adding Tasks

Define new tasks in `tasks.py`:

```python
Task(
    id="my-new-task",
    category="single-file",
    template="pylib",
    prompt="Description of what the agent should do...",
    estimated_duration_min=10,
    setup=optional_setup_function,  # inject test files, etc.
)
```

For multi-file tasks, write a setup function that injects test files defining the expected behavior. The agent must implement the feature to pass them.

## Adding Templates

Create a new directory under `templates/` with:
- Source code in `src/`
- Tests in `tests/`
- A `pyproject.toml` with `pythonpath = ["."]`

Run `python runner.py verify <template>` to confirm the test suite works.

## Requirements

- Python 3.10+
- `pytest` (for running workspace tests)
- `scipy` (for Wilcoxon signed-rank test)
- Claude Code CLI (`claude` command available in PATH)
