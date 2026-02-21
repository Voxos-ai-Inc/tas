"""Tests for the task management API."""

import pytest


class TestCreateTask:
    def test_create_basic(self, api):
        task = api.create_task("Buy groceries")
        assert task.title == "Buy groceries"
        assert task.status == "pending"

    def test_create_with_description(self, api):
        task = api.create_task("Deploy", "Ship v2 to prod")
        assert task.description == "Ship v2 to prod"

    def test_create_empty_title_raises(self, api):
        with pytest.raises(ValueError):
            api.create_task("")

    def test_create_whitespace_title_raises(self, api):
        with pytest.raises(ValueError):
            api.create_task("   ")


class TestGetTask:
    def test_get_existing(self, api):
        created = api.create_task("Test")
        fetched = api.get_task(created.id)
        assert fetched.title == "Test"

    def test_get_missing_raises(self, api):
        with pytest.raises(KeyError):
            api.get_task("nonexistent")


class TestListTasks:
    def test_list_empty(self, api):
        assert api.list_tasks() == []

    def test_list_all(self, api):
        api.create_task("A")
        api.create_task("B")
        assert len(api.list_tasks()) == 2

    def test_filter_by_status(self, api):
        t1 = api.create_task("A")
        api.create_task("B")
        api.complete_task(t1.id)
        assert len(api.list_tasks(status="done")) == 1
        assert len(api.list_tasks(status="pending")) == 1


class TestUpdateTask:
    def test_update_title(self, api):
        task = api.create_task("Old")
        api.update_task(task.id, title="New")
        assert api.get_task(task.id).title == "New"

    def test_complete_task(self, api):
        task = api.create_task("Do thing")
        api.complete_task(task.id)
        assert api.get_task(task.id).status == "done"


class TestDeleteTask:
    def test_delete_existing(self, api):
        task = api.create_task("Temp")
        api.delete_task(task.id)
        with pytest.raises(KeyError):
            api.get_task(task.id)

    def test_delete_missing_raises(self, api):
        with pytest.raises(KeyError):
            api.delete_task("nope")
