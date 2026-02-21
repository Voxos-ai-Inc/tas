"""Tests for data models."""

from src.models import Task


class TestTask:
    def test_create_minimal(self):
        task = Task(title="Buy milk")
        assert task.title == "Buy milk"
        assert task.description == ""
        assert task.status == "pending"
        assert task.id is not None

    def test_create_full(self):
        task = Task(title="Deploy", description="Ship to prod", status="in_progress")
        assert task.title == "Deploy"
        assert task.description == "Ship to prod"
        assert task.status == "in_progress"

    def test_to_dict(self):
        task = Task(title="Test", id="abc123")
        d = task.to_dict()
        assert d["id"] == "abc123"
        assert d["title"] == "Test"
        assert d["status"] == "pending"
        assert "created_at" in d

    def test_unique_ids(self):
        t1 = Task(title="A")
        t2 = Task(title="B")
        assert t1.id != t2.id
