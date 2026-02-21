"""Score a trial by running tests and checking workspace state."""

import json
import subprocess
import sys
from pathlib import Path


def score_trial(task, workspace: Path) -> dict:
    """Run success criteria against a workspace and return scores.

    Returns:
        {
            "success": bool,       # all tests passed
            "tests_passed": int,
            "tests_failed": int,
            "tests_total": int,
            "files_changed": int,  # files modified vs template
            "errors": [str],       # error messages if any
        }
    """
    errors = []

    # Run pytest
    test_result = _run_pytest(workspace)

    # Count modified files
    files_changed = _count_changed_files(workspace, task.template)

    success = test_result["passed"] == test_result["total"] and test_result["total"] > 0

    return {
        "success": success,
        "tests_passed": test_result["passed"],
        "tests_failed": test_result["failed"],
        "tests_total": test_result["total"],
        "files_changed": files_changed,
        "errors": test_result.get("errors", []),
        "test_output": test_result.get("output", ""),
    }


def _run_pytest(workspace: Path) -> dict:
    """Run pytest in the workspace and parse results."""
    try:
        proc = subprocess.run(
            [sys.executable, "-m", "pytest", "tests/", "-v", "--tb=short", "-q"],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=60,
        )

        output = proc.stdout + proc.stderr
        passed, failed, total = _parse_pytest_output(output)

        return {
            "passed": passed,
            "failed": failed,
            "total": total,
            "output": output[:2000],
            "errors": [] if proc.returncode == 0 else [f"pytest exit code {proc.returncode}"],
        }
    except subprocess.TimeoutExpired:
        return {"passed": 0, "failed": 0, "total": 0, "errors": ["pytest timeout"]}
    except Exception as e:
        return {"passed": 0, "failed": 0, "total": 0, "errors": [str(e)]}


def _parse_pytest_output(output: str) -> tuple:
    """Extract pass/fail counts from pytest output.

    Parses the summary line like: "8 passed, 2 failed" or "10 passed"
    """
    passed = 0
    failed = 0

    for line in output.splitlines():
        line = line.strip()
        # Look for the summary line (e.g., "8 passed, 2 failed in 0.12s")
        if "passed" in line or "failed" in line:
            parts = line.split()
            for i, part in enumerate(parts):
                if part == "passed" or part == "passed,":
                    try:
                        passed = int(parts[i - 1])
                    except (ValueError, IndexError):
                        pass
                if part == "failed" or part == "failed,":
                    try:
                        failed = int(parts[i - 1])
                    except (ValueError, IndexError):
                        pass

    return passed, failed, passed + failed


def _count_changed_files(workspace: Path, template_name: str) -> int:
    """Count files that differ between workspace and original template."""
    from config import TEMPLATES_DIR

    template_dir = TEMPLATES_DIR / template_name
    changed = 0

    # Check files in workspace src/ against template
    for ws_file in workspace.rglob("*"):
        if ws_file.is_dir():
            continue
        if ".git" in ws_file.parts:
            continue

        rel = ws_file.relative_to(workspace)
        template_file = template_dir / rel

        if not template_file.exists():
            changed += 1  # new file
        elif ws_file.read_bytes() != template_file.read_bytes():
            changed += 1  # modified file

    return changed
