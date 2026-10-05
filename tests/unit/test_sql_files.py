"""Static checks on the SQL source of truth (no database needed)."""

import re
from pathlib import Path

EXPECTED_SCHEMAS = {
    "ref",
    "source",
    "institution",
    "core",
    "reporting",
    "government",
    "market",
    "finance",
    "ownership",
    "economy",
    "analytics",
}


def _sql(repo_root: Path, sub: str) -> list[Path]:
    return sorted((repo_root / "db" / sub).glob("*.sql"))


def test_migrations_are_numbered_and_ordered(repo_root: Path) -> None:
    names = [p.name for p in _sql(repo_root, "migrations")]
    assert names == [
        "001_al_mfi_001_canonical_model.sql",
        "002_al_mfi_001_v02_extensions.sql",
    ]


def test_migrations_are_transactional(repo_root: Path) -> None:
    for path in _sql(repo_root, "migrations") + _sql(repo_root, "seeds"):
        text = path.read_text()
        assert "BEGIN;" in text and "COMMIT;" in text, path.name


def test_all_schemas_created(repo_root: Path) -> None:
    text = "\n".join(p.read_text() for p in _sql(repo_root, "migrations"))
    created = set(re.findall(r"CREATE SCHEMA IF NOT EXISTS (\w+);", text))
    assert created == EXPECTED_SCHEMAS


def test_seeds_are_idempotent(repo_root: Path) -> None:
    for path in _sql(repo_root, "seeds"):
        text = path.read_text()
        inserts = text.count("INSERT INTO")
        guarded = text.count("ON CONFLICT") + text.count("NOT EXISTS")
        assert inserts == guarded, path.name
