"""Input validation."""


def validate_task_input(title, description=""):
    if not title or not title.strip():
        raise ValueError("Title must not be empty")
    if len(title) > 200:
        raise ValueError("Title must be 200 characters or less")
    if len(description) > 2000:
        raise ValueError("Description must be 2000 characters or less")
    return True
