"""Benchmark configuration."""

from pathlib import Path

BENCH_DIR = Path(__file__).parent
TAS_ROOT = BENCH_DIR.parent
TEMPLATES_DIR = BENCH_DIR / "templates"
WORKSPACES_DIR = BENCH_DIR / "workspaces"
RESULTS_DIR = BENCH_DIR / "results"

# Trial settings
DEFAULT_TRIALS = 3
DEFAULT_MODEL = "claude-sonnet-4-6"
MAX_TURNS = 25
TIMEOUT_SECONDS = 300  # 5 minutes per task

# Conditions
VANILLA = "vanilla"
TAS = "tas"
CONDITIONS = [VANILLA, TAS]

# Categories
SINGLE_FILE = "single-file"
MULTI_FILE = "multi-file"
REFACTOR = "refactor"

# TAS CLAUDE.md template injected into TAS-condition workspaces
TAS_CLAUDE_MD = """# {project_name}

## Knowledge Map
- Source code: `src/`
- Tests: `tests/`
- Run tests: `python -m pytest tests/ -v`

## Rules
- Read the relevant source files before making changes
- Run all tests after every change to verify nothing is broken
- Do not modify test files unless explicitly asked
- Keep changes minimal and focused on the task

## Prove It
Every change must be verified:
1. Run tests before the change (baseline)
2. Make the change
3. Run tests after (measure)
4. Confirm all tests pass

## Gotchas
- Check for cascading dependencies between functions
- Empty list edge cases need explicit handling
- Maintain backward compatibility with existing callers
"""
