"""Output formatting utilities."""


def format_task_row(task):
    status_icon = {"pending": "[ ]", "in_progress": "[~]", "done": "[x]"}
    icon = status_icon.get(task.status, "[?]")
    return f"{icon} {task.id} | {task.title}"


def format_task_list(tasks):
    if not tasks:
        return "No tasks found."
    return "\n".join(format_task_row(t) for t in tasks)


def format_summary(tasks):
    total = len(tasks)
    done = sum(1 for t in tasks if t.status == "done")
    pending = sum(1 for t in tasks if t.status == "pending")
    in_progress = sum(1 for t in tasks if t.status == "in_progress")
    return f"Total: {total} | Done: {done} | In Progress: {in_progress} | Pending: {pending}"
