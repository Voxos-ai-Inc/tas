import pytest

from src.api import TaskAPI


@pytest.fixture
def api():
    """Fresh TaskAPI instance for each test."""
    return TaskAPI()
