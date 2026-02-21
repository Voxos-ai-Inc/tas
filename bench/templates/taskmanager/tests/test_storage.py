"""Tests for in-memory storage."""

import pytest

from src.models import Task
from src.storage import Storage


@pytest.fixture
def store():
    return Storage()


class TestStorage:
    def test_add_and_get(self, store):
        task = Task(title="Test", id="t1")
        store.add(task)
        assert store.get("t1").title == "Test"

    def test_get_missing(self, store):
        assert store.get("nope") is None

    def test_list_all(self, store):
        store.add(Task(title="A"))
        store.add(Task(title="B"))
        assert len(store.list_all()) == 2

    def test_update(self, store):
        store.add(Task(title="Old", id="t1"))
        store.update("t1", title="New")
        assert store.get("t1").title == "New"

    def test_update_missing_raises(self, store):
        with pytest.raises(KeyError):
            store.update("nope", title="X")

    def test_delete(self, store):
        store.add(Task(title="Bye", id="t1"))
        store.delete("t1")
        assert store.get("t1") is None

    def test_delete_missing_raises(self, store):
        with pytest.raises(KeyError):
            store.delete("nope")

    def test_count(self, store):
        assert store.count() == 0
        store.add(Task(title="A"))
        assert store.count() == 1
