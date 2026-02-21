"""Benchmark runner — orchestrates task execution across conditions.

Usage:
    python runner.py run --label baseline-v1 [--condition vanilla|harness|both] [--task fix-average] [--trials 3]
    python runner.py list [--category single-file]
    python runner.py verify <template>
"""

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from config import (
    CONDITIONS,
    DEFAULT_MODEL,
    DEFAULT_TRIALS,
    HARNESS,
    HARNESS_CLAUDE_MD,
    MAX_TURNS,
    RESULTS_DIR,
    TEMPLATES_DIR,
    TIMEOUT_SECONDS,
    VANILLA,
    WORKSPACES_DIR,
)
from scorer import score_trial
from tasks import TASKS, get_task, list_tasks


def setup_workspace(task, condition: str, trial: int) -> Path:
    """Create a fresh workspace for a single trial."""
    workspace = WORKSPACES_DIR / f"{task.id}_{condition}_t{trial}"

    if workspace.exists():
        shutil.rmtree(workspace)

    template = TEMPLATES_DIR / task.template
    shutil.copytree(template, workspace)

    # Inject harness files for the harness condition
    if condition == HARNESS:
        _install_harness(workspace, task)

    # Run task-specific setup (e.g., inject test files)
    if task.setup:
        task.setup(workspace)

    return workspace


def _install_harness(workspace: Path, task):
    """Install harness scaffolding into the workspace."""
    # CLAUDE.md with project-specific guidance
    claude_md = workspace / "CLAUDE.md"
    claude_md.write_text(HARNESS_CLAUDE_MD.format(project_name=task.template))

    # Living docs
    for doc_name, content in [
        ("GOTCHAS.md", "# Gotchas\n\nNo known issues yet.\n"),
        ("REMINDERS.md", "# Reminders\n\nNo pending items.\n"),
    ]:
        (workspace / doc_name).write_text(content)

    # Persistent memory
    memory_dir = workspace / ".claude-memory"
    memory_dir.mkdir(exist_ok=True)
    (memory_dir / "MEMORY.md").write_text("# Memory\n\nNo notes yet.\n")


def run_claude(prompt: str, workspace: Path, model: str) -> dict:
    """Run Claude Code CLI and return parsed JSON result."""
    cmd = [
        "claude",
        "-p", prompt,
        "--model", model,
        "--max-turns", str(MAX_TURNS),
        "--output-format", "json",
    ]

    try:
        proc = subprocess.run(
            cmd,
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
            shell=True,  # needed for .cmd wrapper on Windows
        )

        if proc.stdout.strip():
            # Claude may output multiple JSON objects; take the last one
            lines = proc.stdout.strip().splitlines()
            for line in reversed(lines):
                line = line.strip()
                if line.startswith("{"):
                    try:
                        return json.loads(line)
                    except json.JSONDecodeError:
                        continue
            # Fallback: try parsing entire stdout
            return json.loads(proc.stdout)
        else:
            return {
                "is_error": True,
                "error": proc.stderr[:500] if proc.stderr else "empty output",
            }

    except subprocess.TimeoutExpired:
        return {"is_error": True, "error": f"timeout after {TIMEOUT_SECONDS}s"}
    except json.JSONDecodeError as e:
        return {"is_error": True, "error": f"JSON parse error: {e}"}
    except Exception as e:
        return {"is_error": True, "error": str(e)}


def run_trial(task, condition: str, trial: int, model: str) -> dict:
    """Execute a single trial and return structured results."""
    print(f"  [{condition}] trial {trial + 1} ... ", end="", flush=True)

    workspace = setup_workspace(task, condition, trial)

    # Build the prompt
    prompt = task.prompt
    if condition == HARNESS:
        prompt = f"Read CLAUDE.md first, then: {prompt}"

    # Run Claude
    start_time = time.time()
    claude_result = run_claude(prompt, workspace, model)
    wall_time = time.time() - start_time

    # Score the outcome
    scores = score_trial(task, workspace)

    status = "PASS" if scores["success"] else "FAIL"
    print(f"{status} ({wall_time:.0f}s, {scores['tests_passed']}/{scores['tests_total']} tests)")

    return {
        "task_id": task.id,
        "category": task.category,
        "condition": condition,
        "trial": trial,
        "model": model,
        "wall_time_s": round(wall_time, 2),
        "cost_usd": claude_result.get("total_cost_usd", 0),
        "num_turns": claude_result.get("num_turns", 0),
        "duration_api_ms": claude_result.get("duration_api_ms", 0),
        "is_error": claude_result.get("is_error", False),
        "success": scores["success"],
        "tests_passed": scores["tests_passed"],
        "tests_failed": scores["tests_failed"],
        "tests_total": scores["tests_total"],
        "files_changed": scores["files_changed"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def cmd_run(args):
    """Run the benchmark."""
    label = args.label
    conditions = [args.condition] if args.condition != "both" else CONDITIONS
    model = args.model
    trials = args.trials

    # Select tasks
    if args.task:
        tasks = [get_task(args.task)]
    elif args.category:
        tasks = list_tasks(category=args.category)
    else:
        tasks = list(TASKS)

    print(f"Benchmark: {label}")
    print(f"  Conditions: {conditions}")
    print(f"  Tasks: {len(tasks)}")
    print(f"  Trials: {trials}")
    print(f"  Model: {model}")
    print()

    all_results = []

    for task in tasks:
        print(f"Task: {task.id} ({task.category})")
        for condition in conditions:
            for trial in range(trials):
                result = run_trial(task, condition, trial, model)
                all_results.append(result)
        print()

    # Save results
    result_dir = RESULTS_DIR / label
    result_dir.mkdir(parents=True, exist_ok=True)

    results_file = result_dir / "results.json"
    results_file.write_text(json.dumps(all_results, indent=2))

    config_file = result_dir / "config.json"
    config_file.write_text(json.dumps({
        "label": label,
        "conditions": conditions,
        "model": model,
        "trials": trials,
        "task_count": len(tasks),
        "task_ids": [t.id for t in tasks],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }, indent=2))

    # Print summary
    _print_summary(all_results, conditions)

    print(f"\nResults saved to {result_dir}")


def _print_summary(results: list, conditions: list):
    """Print an aggregate summary table."""
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)

    for condition in conditions:
        cond_results = [r for r in results if r["condition"] == condition]
        if not cond_results:
            continue

        successes = sum(1 for r in cond_results if r["success"])
        total = len(cond_results)
        avg_time = sum(r["wall_time_s"] for r in cond_results) / total
        avg_cost = sum(r["cost_usd"] for r in cond_results) / total
        avg_turns = sum(r["num_turns"] for r in cond_results) / total

        print(f"\n  {condition.upper()}")
        print(f"    Success rate:  {successes}/{total} ({100*successes/total:.0f}%)")
        print(f"    Avg wall time: {avg_time:.1f}s")
        print(f"    Avg cost:      ${avg_cost:.4f}")
        print(f"    Avg turns:     {avg_turns:.1f}")


def cmd_list(args):
    """List available benchmark tasks."""
    tasks = list_tasks(category=args.category)

    print(f"{'ID':<25} {'Category':<15} {'Template':<15} {'Est (min)'}")
    print("-" * 65)
    for t in tasks:
        print(f"{t.id:<25} {t.category:<15} {t.template:<15} {t.estimated_duration_min}")
    print(f"\nTotal: {len(tasks)} tasks")


def cmd_verify(args):
    """Verify a template's test suite runs correctly."""
    template_dir = TEMPLATES_DIR / args.template
    if not template_dir.exists():
        print(f"Template not found: {args.template}")
        sys.exit(1)

    print(f"Verifying template: {args.template}")
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", "tests/", "-v"],
        cwd=str(template_dir),
        capture_output=True,
        text=True,
    )
    print(proc.stdout)
    if proc.stderr:
        print(proc.stderr)

    # Report expected failures for pylib (has deliberate bugs)
    if args.template == "pylib":
        print("\nNote: pylib has deliberate bugs — some test failures are expected.")
    elif proc.returncode != 0:
        print("\nWARNING: Template has unexpected test failures.")


def main():
    parser = argparse.ArgumentParser(description="Harness benchmark runner")
    sub = parser.add_subparsers(dest="command", required=True)

    # run
    p_run = sub.add_parser("run", help="Run benchmark trials")
    p_run.add_argument("--label", required=True, help="Label for this run (e.g., baseline-v1)")
    p_run.add_argument("--condition", default="both", choices=["vanilla", "harness", "both"])
    p_run.add_argument("--task", help="Run a single task by ID")
    p_run.add_argument("--category", choices=["single-file", "multi-file", "refactor"])
    p_run.add_argument("--trials", type=int, default=DEFAULT_TRIALS)
    p_run.add_argument("--model", default=DEFAULT_MODEL)

    # list
    p_list = sub.add_parser("list", help="List available tasks")
    p_list.add_argument("--category", choices=["single-file", "multi-file", "refactor"])

    # verify
    p_verify = sub.add_parser("verify", help="Verify a template's test suite")
    p_verify.add_argument("template", help="Template name (e.g., pylib, taskmanager)")

    args = parser.parse_args()

    if args.command == "run":
        cmd_run(args)
    elif args.command == "list":
        cmd_list(args)
    elif args.command == "verify":
        cmd_verify(args)


if __name__ == "__main__":
    main()
