"""Integration fixtures. Set AL_MFI_TEST_DATABASE_URL to an empty, disposable database."""

import os
from pathlib import Path

import pytest

from tests.conftest import build_sql_files

DSN = os.environ.get("AL_MFI_TEST_DATABASE_URL")


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    if DSN:
        return
    skip = pytest.mark.skip(reason="AL_MFI_TEST_DATABASE_URL not set")
    for item in items:
        if "integration" in item.path.parts:
            item.add_marker(skip)


@pytest.fixture(scope="session")
def conn(repo_root: Path):
    psycopg = pytest.importorskip("psycopg")
    assert DSN is not None
    with psycopg.connect(DSN, autocommit=True) as c:
        for path in build_sql_files(repo_root):
            c.execute(path.read_text())
        # roles and seeds must be re-runnable
        for path in build_sql_files(repo_root):
            if path.parent.name in ("roles", "seeds"):
                c.execute(path.read_text())
        yield c
