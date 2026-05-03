# tests/conftest.py — required boilerplate for .hy test collection
import os
from pathlib import Path
import hy, pytest

NATIVE_TESTS = Path(__file__).parent / "native_tests"
os.environ.pop("HYSTARTUP", None)


def pytest_collect_file(file_path, parent):
    if (
        file_path.suffix == ".hy"
        and NATIVE_TESTS in file_path.parents
        and file_path.name != "__init__.hy"
    ):
        return pytest.Module.from_parent(parent, path=file_path)
