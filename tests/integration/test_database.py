"""Integration tests against a real PostgreSQL. Set AL_MFI_TEST_DATABASE_URL to enable.

The target database must be empty and disposable: migrations and seeds are applied to it.
"""

from datetime import date
from pathlib import Path

import pytest

psycopg = pytest.importorskip("psycopg")


def test_districts_seeded(conn) -> None:
    (n,) = conn.execute(
        "SELECT count(*) FROM institution.administrative_area WHERE area_level = 'district'"
    ).fetchone()
    assert n == 28


def test_point_in_time_position_holder(conn) -> None:
    with conn.transaction(force_rollback=True):
        gov = conn.execute("SELECT entity_id FROM core.entity WHERE short_name = 'GoM'").fetchone()[
            0
        ]
        zomba = conn.execute(
            "SELECT administrative_area_id FROM institution.administrative_area "
            "WHERE code = 'MW-ZO'"
        ).fetchone()[0]
        unit = conn.execute(
            "INSERT INTO institution.organizational_unit (entity_id, unit_kind, name, "
            "administrative_area_id) VALUES (%s, 'office', 'Zomba District Office', %s) "
            "RETURNING organizational_unit_id",
            (gov, zomba),
        ).fetchone()[0]
        pos = conn.execute(
            "INSERT INTO institution.position (title, organizational_unit_id) "
            "VALUES ('District Commissioner', %s) RETURNING position_id",
            (unit,),
        ).fetchone()[0]
        for name, start, end in [
            ("A. Person", date(2022, 1, 1), date(2024, 12, 31)),
            ("B. Person", date(2025, 1, 1), None),
        ]:
            person = conn.execute(
                "INSERT INTO institution.person (full_name) VALUES (%s) RETURNING person_id",
                (name,),
            ).fetchone()[0]
            conn.execute(
                "INSERT INTO institution.appointment (person_id, position_id, start_date, "
                "end_date) VALUES (%s, %s, %s, %s)",
                (person, pos, start, end),
            )
        rows = conn.execute(
            "SELECT full_name FROM institution.position_holders_on(%s) "
            "WHERE title = 'District Commissioner' AND administrative_area_id = %s",
            (date(2025, 3, 15), zomba),
        ).fetchall()
        assert rows == [("B. Person",)]


def test_observation_requires_subject(conn) -> None:
    with conn.transaction(force_rollback=True):
        concept = conn.execute(
            "SELECT concept_id FROM ref.concept WHERE code = 'revenue'"
        ).fetchone()[0]
        period = conn.execute(
            "INSERT INTO core.period (period_type, start_date, end_date) "
            "VALUES ('duration', '2024-01-01', '2024-12-31') RETURNING period_id"
        ).fetchone()[0]
        with pytest.raises(psycopg.errors.CheckViolation):
            conn.execute(
                "INSERT INTO core.observation (concept_id, period_id, value_numeric) "
                "VALUES (%s, %s, 1)",
                (concept, period),
            )


def test_schema_checks_pass(conn, repo_root: Path) -> None:
    from scripts.init_db import run_checks

    assert run_checks(conn) == 0
