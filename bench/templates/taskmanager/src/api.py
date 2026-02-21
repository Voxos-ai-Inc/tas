"""High-level task management API."""

from src.models import Task
from src.storage import Storage
from src.validators import validate_task_input


class TaskAPI:
    def __init__(self):
        self.storage = Storage()

    def create_task(self, title, description=""):
        validate_task_input(title, description)
        task = Task(title=title, description=description)
        return self.storage.add(task)

    def get_task(self, task_id):
        task = self.storage.get(task_id)
        if not task:
            raise KeyError(f"Task {task_id} not found")
        return task

    def list_tasks(self, status=None):
        tasks = self.storage.list_all()
        if status:
            tasks = [t for t in tasks if t.status == status]
        return tasks

    def update_task(self, task_id, **kwargs):
        return self.storage.update(task_id, **kwargs)

    def delete_task(self, task_id):
        self.storage.delete(task_id)

    def complete_task(self, task_id):
        return self.storage.update(task_id, status="done")

    def count_tasks(self):
        return self.storage.count()
