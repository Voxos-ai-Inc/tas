"""Benchmark task definitions.

Each task specifies:
- A workspace template (the starting codebase)
- A prompt (what the agent is told to do)
- Success criteria (tests that must pass)
- Optional setup (files injected before the agent runs)
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional


@dataclass
class Task:
    id: str
    category: str  # single-file, multi-file, refactor
    template: str  # directory name under templates/
    prompt: str
    estimated_duration_min: int = 10
    setup: Optional[Callable] = None  # fn(workspace_path) called before agent runs


# ---------------------------------------------------------------------------
# Setup helpers — inject additional test files into workspace before the run
# ---------------------------------------------------------------------------


def _inject_search_tests(workspace: Path):
    """Inject test_search.py for the add-search task."""
    test_file = workspace / "tests" / "test_search.py"
    test_file.write_text('''\
"""Tests for task search functionality."""

import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    return TaskAPI()


class TestSearch:
    def test_search_by_title(self, api):
        api.create_task("Buy groceries", "Get milk and bread")
        api.create_task("Review PR", "Check auth changes")
        results = api.search_tasks("groceries")
        assert len(results) == 1
        assert results[0].title == "Buy groceries"

    def test_search_by_description(self, api):
        api.create_task("Task A", "important deadline")
        api.create_task("Task B", "casual reminder")
        results = api.search_tasks("deadline")
        assert len(results) == 1

    def test_search_case_insensitive(self, api):
        api.create_task("URGENT: Fix bug")
        results = api.search_tasks("urgent")
        assert len(results) == 1

    def test_search_no_results(self, api):
        api.create_task("Buy groceries")
        results = api.search_tasks("nonexistent")
        assert len(results) == 0

    def test_search_multiple_matches(self, api):
        api.create_task("Fix bug A")
        api.create_task("Fix bug B")
        api.create_task("Deploy app")
        results = api.search_tasks("fix bug")
        assert len(results) == 2
''')


def _inject_priority_tests(workspace: Path):
    """Inject test_priority.py for the add-priority task."""
    test_file = workspace / "tests" / "test_priority.py"
    test_file.write_text('''\
"""Tests for task priority functionality."""

import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    return TaskAPI()


class TestPriority:
    def test_create_with_priority(self, api):
        task = api.create_task("Urgent fix", priority="high")
        assert task.priority == "high"

    def test_default_priority(self, api):
        task = api.create_task("Normal task")
        assert task.priority == "medium"

    def test_filter_by_priority(self, api):
        api.create_task("Low thing", priority="low")
        api.create_task("High thing", priority="high")
        api.create_task("Another high", priority="high")
        results = api.list_tasks(priority="high")
        assert len(results) == 2

    def test_invalid_priority_raises(self, api):
        with pytest.raises(ValueError):
            api.create_task("Bad", priority="critical")

    def test_update_priority(self, api):
        task = api.create_task("Task", priority="low")
        api.update_task(task.id, priority="high")
        assert api.get_task(task.id).priority == "high"
''')


def _inject_export_tests(workspace: Path):
    """Inject test_export.py for the add-export task."""
    test_file = workspace / "tests" / "test_export.py"
    test_file.write_text('''\
"""Tests for task export functionality."""

import csv
import io
import json

import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    return TaskAPI()


class TestExportJSON:
    def test_export_json(self, api):
        api.create_task("Task A", "Desc A")
        api.create_task("Task B", "Desc B")
        result = api.export_tasks("json")
        data = json.loads(result)
        assert len(data) == 2
        assert data[0]["title"] in ("Task A", "Task B")

    def test_export_json_empty(self, api):
        result = api.export_tasks("json")
        assert json.loads(result) == []


class TestExportCSV:
    def test_export_csv(self, api):
        api.create_task("Task A", "Desc A")
        api.create_task("Task B", "Desc B")
        result = api.export_tasks("csv")
        reader = csv.DictReader(io.StringIO(result))
        rows = list(reader)
        assert len(rows) == 2
        assert "title" in rows[0]
        assert "status" in rows[0]

    def test_export_csv_empty(self, api):
        result = api.export_tasks("csv")
        reader = csv.DictReader(io.StringIO(result))
        assert list(reader) == []


class TestExportInvalidFormat:
    def test_invalid_format_raises(self, api):
        with pytest.raises(ValueError):
            api.export_tasks("xml")
''')


def _inject_tags_tests(workspace: Path):
    """Inject test_tags.py for the add-tags task."""
    test_file = workspace / "tests" / "test_tags.py"
    test_file.write_text('''\
"""Tests for task tagging functionality."""

import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    return TaskAPI()


class TestTags:
    def test_create_with_tags(self, api):
        task = api.create_task("Fix bug", tags=["bug", "urgent"])
        assert set(task.tags) == {"bug", "urgent"}

    def test_default_no_tags(self, api):
        task = api.create_task("Plain task")
        assert task.tags == []

    def test_add_tag(self, api):
        task = api.create_task("Task")
        api.add_tag(task.id, "important")
        updated = api.get_task(task.id)
        assert "important" in updated.tags

    def test_remove_tag(self, api):
        task = api.create_task("Task", tags=["a", "b"])
        api.remove_tag(task.id, "a")
        updated = api.get_task(task.id)
        assert "a" not in updated.tags
        assert "b" in updated.tags

    def test_filter_by_tag(self, api):
        api.create_task("Bug 1", tags=["bug"])
        api.create_task("Feature 1", tags=["feature"])
        api.create_task("Bug 2", tags=["bug", "urgent"])
        results = api.list_tasks(tag="bug")
        assert len(results) == 2

    def test_remove_nonexistent_tag_raises(self, api):
        task = api.create_task("Task")
        with pytest.raises(ValueError):
            api.remove_tag(task.id, "nope")
''')


def _inject_due_date_tests(workspace: Path):
    """Inject test_due_dates.py for the add-due-dates task."""
    test_file = workspace / "tests" / "test_due_dates.py"
    test_file.write_text('''\
"""Tests for due date functionality."""

from datetime import datetime, timedelta

import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    return TaskAPI()


class TestDueDates:
    def test_create_with_due_date(self, api):
        due = datetime.now() + timedelta(days=7)
        task = api.create_task("Ship feature", due_date=due)
        assert task.due_date == due

    def test_default_no_due_date(self, api):
        task = api.create_task("Whenever")
        assert task.due_date is None

    def test_overdue_detection(self, api):
        past = datetime.now() - timedelta(days=1)
        api.create_task("Late task", due_date=past)
        future = datetime.now() + timedelta(days=7)
        api.create_task("On time", due_date=future)
        api.create_task("No deadline")
        overdue = api.get_overdue_tasks()
        assert len(overdue) == 1
        assert overdue[0].title == "Late task"

    def test_completed_not_overdue(self, api):
        past = datetime.now() - timedelta(days=1)
        task = api.create_task("Done task", due_date=past)
        api.complete_task(task.id)
        overdue = api.get_overdue_tasks()
        assert len(overdue) == 0

    def test_sort_by_due_date(self, api):
        d1 = datetime.now() + timedelta(days=3)
        d2 = datetime.now() + timedelta(days=1)
        d3 = datetime.now() + timedelta(days=7)
        api.create_task("Later", due_date=d1)
        api.create_task("Soon", due_date=d2)
        api.create_task("Much later", due_date=d3)
        sorted_tasks = api.list_tasks(sort_by="due_date")
        assert sorted_tasks[0].title == "Soon"
        assert sorted_tasks[2].title == "Much later"
''')


def _inject_service_layer(workspace: Path):
    """Inject test_service.py for the extract-service refactor task."""
    test_file = workspace / "tests" / "test_service.py"
    test_file.write_text('''\
"""Tests verifying the service layer extraction.

The business logic currently in api.py should be moved to a new
src/service.py module. The API layer should delegate to the service.
"""

import pytest

from src.service import TaskService
from src.storage import Storage


@pytest.fixture
def service():
    return TaskService(storage=Storage())


class TestServiceLayer:
    def test_create_task(self, service):
        task = service.create_task("Test")
        assert task.title == "Test"

    def test_create_validates_input(self, service):
        with pytest.raises(ValueError):
            service.create_task("")

    def test_complete_task(self, service):
        task = service.create_task("Do thing")
        service.complete_task(task.id)
        assert service.get_task(task.id).status == "done"

    def test_list_with_filter(self, service):
        t1 = service.create_task("A")
        service.create_task("B")
        service.complete_task(t1.id)
        assert len(service.list_tasks(status="done")) == 1

    def test_count(self, service):
        service.create_task("A")
        service.create_task("B")
        assert service.count_tasks() == 2

    def test_api_delegates_to_service(self):
        """Verify TaskAPI uses TaskService internally."""
        from src.api import TaskAPI
        api = TaskAPI()
        assert hasattr(api, "service"), "TaskAPI should delegate to a TaskService instance"
''')


# ---------------------------------------------------------------------------
# Task registry
# ---------------------------------------------------------------------------

TASKS = [
    # ---- Single-file bug fixes (pylib) ----
    Task(
        id="fix-average",
        category="single-file",
        template="pylib",
        prompt=(
            "The calculate_average function in src/stats.py has a bug. "
            "Tests are failing. Fix the bug so all tests in "
            "tests/test_stats.py::TestCalculateAverage pass. "
            "Do not modify the test file."
        ),
        estimated_duration_min=5,
    ),
    Task(
        id="fix-empty-handling",
        category="single-file",
        template="pylib",
        prompt=(
            "Several functions in src/stats.py crash on empty lists instead of "
            "raising ValueError. Fix calculate_average, find_median, and "
            "standard_deviation to raise ValueError('Input list must not be empty') "
            "when given an empty list. Do not modify test files."
        ),
        estimated_duration_min=10,
    ),
    Task(
        id="fix-cascading-bug",
        category="single-file",
        template="pylib",
        prompt=(
            "The standard_deviation function returns wrong results. "
            "Investigate the root cause — the bug may not be in "
            "standard_deviation itself. Fix the underlying issue so all "
            "tests in tests/test_stats.py pass. Do not modify test files."
        ),
        estimated_duration_min=10,
    ),
    Task(
        id="add-weighted-average",
        category="single-file",
        template="pylib",
        prompt=(
            "Add a weighted_average(values, weights) function to src/stats.py. "
            "It should compute the weighted arithmetic mean. Raise ValueError if "
            "the lists are different lengths, if either is empty, or if any weight "
            "is negative. Add tests in a new file tests/test_weighted.py. "
            "All existing tests must still pass."
        ),
        estimated_duration_min=15,
    ),

    # ---- Multi-file features (taskmanager) ----
    Task(
        id="add-search",
        category="multi-file",
        template="taskmanager",
        prompt=(
            "Add a search_tasks(query) method to TaskAPI that searches tasks by "
            "title and description. Search should be case-insensitive and match "
            "partial strings. All existing tests plus the new tests in "
            "tests/test_search.py must pass. Do not modify test files."
        ),
        estimated_duration_min=15,
        setup=_inject_search_tests,
    ),
    Task(
        id="add-priority",
        category="multi-file",
        template="taskmanager",
        prompt=(
            "Add a priority system to the task manager. Tasks should have a "
            "priority field (low, medium, high) defaulting to medium. "
            "Support creating tasks with priority, filtering by priority in "
            "list_tasks, and updating priority. Reject invalid priority values "
            "with ValueError. All existing tests plus tests/test_priority.py "
            "must pass. Do not modify test files."
        ),
        estimated_duration_min=20,
        setup=_inject_priority_tests,
    ),
    Task(
        id="add-export",
        category="multi-file",
        template="taskmanager",
        prompt=(
            "Add an export_tasks(format) method to TaskAPI that exports all tasks "
            "as either JSON or CSV string. JSON format: list of task dicts. "
            "CSV format: header row + data rows with columns id, title, "
            "description, status, created_at. Raise ValueError for unsupported "
            "formats. All existing tests plus tests/test_export.py must pass. "
            "Do not modify test files."
        ),
        estimated_duration_min=20,
        setup=_inject_export_tests,
    ),
    Task(
        id="add-tags",
        category="multi-file",
        template="taskmanager",
        prompt=(
            "Add a tagging system. Tasks should have a tags field (list of "
            "strings, default empty). Support: creating tasks with tags, "
            "add_tag(task_id, tag), remove_tag(task_id, tag) which raises "
            "ValueError if tag not present, and filtering list_tasks(tag=...). "
            "All existing tests plus tests/test_tags.py must pass. "
            "Do not modify test files."
        ),
        estimated_duration_min=25,
        setup=_inject_tags_tests,
    ),
    Task(
        id="add-due-dates",
        category="multi-file",
        template="taskmanager",
        prompt=(
            "Add due date support. Tasks should accept an optional due_date "
            "(datetime, default None). Add get_overdue_tasks() returning "
            "non-completed tasks past their due date, and support "
            "sort_by='due_date' in list_tasks (None due dates sort last). "
            "All existing tests plus tests/test_due_dates.py must pass. "
            "Do not modify test files."
        ),
        estimated_duration_min=25,
        setup=_inject_due_date_tests,
    ),

    # ---- Refactoring tasks (taskmanager) ----
    Task(
        id="extract-service",
        category="refactor",
        template="taskmanager",
        prompt=(
            "Extract business logic from src/api.py into a new src/service.py "
            "module. Create a TaskService class that owns the storage and "
            "business logic. TaskAPI should delegate to TaskService. "
            "All existing tests plus tests/test_service.py must pass. "
            "Do not modify existing test files."
        ),
        estimated_duration_min=20,
        setup=_inject_service_layer,
    ),
    Task(
        id="add-type-hints",
        category="refactor",
        template="taskmanager",
        prompt=(
            "Add comprehensive type hints to all modules in src/. "
            "Every function signature should have parameter and return type "
            "annotations. Use Optional, List, Dict from typing where needed. "
            "Run 'python -m py_compile src/models.py src/storage.py src/api.py "
            "src/validators.py src/formatters.py' — all must compile. "
            "All existing tests must still pass."
        ),
        estimated_duration_min=15,
    ),
]


def get_task(task_id: str) -> Task:
    """Look up a task by ID."""
    for t in TASKS:
        if t.id == task_id:
            return t
    raise KeyError(f"Unknown task: {task_id}")


def list_tasks(category: str = None) -> list:
    """List tasks, optionally filtered by category."""
    if category:
        return [t for t in TASKS if t.category == category]
    return list(TASKS)
