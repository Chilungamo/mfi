import os
from pathlib import Path

import pytest

# Settings require secrets with no defaults; give tests harmless values before app import.
os.environ.setdefault("S3_ACCESS_KEY", "test-access")
os.environ.setdefault("S3_SECRET_KEY", "test-secret")

ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return ROOT
