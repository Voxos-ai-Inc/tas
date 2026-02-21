"""In-memory task storage."""


class Storage:
    def __init__(self):
        self._tasks = {}

    def add(self, task):
        self._tasks[task.id] = task
        return task

    def get(self, task_id):
        return self._tasks.get(task_id)

    def list_all(self):
        return list(self._tasks.values())

    def update(self, task_id, **kwargs):
        task = self._tasks.get(task_id)
        if not task:
            raise KeyError(f"Task {task_id} not found")
        for key, value in kwargs.items():
            if hasattr(task, key):
                setattr(task, key, value)
        return task

    def delete(self, task_id):
        if task_id not in self._tasks:
            raise KeyError(f"Task {task_id} not found")
        del self._tasks[task_id]

    def count(self):
        return len(self._tasks)
