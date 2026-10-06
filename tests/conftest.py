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


# Order in which a fresh database is built; mirrors scripts/init_db.py.
BUILD_ORDER = ("roles", "migrations", "seeds")


def build_sql_files(root: Path = ROOT) -> list[Path]:
    return [p for sub in BUILD_ORDER for p in sorted((root / "db" / sub).glob("*.sql"))]
