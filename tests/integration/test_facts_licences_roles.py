"""Migration 003: append-only facts, licence tags, API keys and role grants.

Every test runs inside a transaction that is rolled back, so tests do not see each other's rows.
`SET LOCAL ROLE` likewise ends with the transaction.
"""

import pytest

psycopg = pytest.importorskip("psycopg")
from psycopg import errors  # noqa: E402


def _one(conn, sql: str, params: tuple = ()):
    return conn.execute(sql, params).fetchone()[0]


@pytest.fixture
def tx(conn):
    with conn.transaction(force_rollback=True):
        yield conn


@pytest.fixture
def fact_inputs(tx) -> dict:
    """An entity, concept and period to hang facts on."""
    return {
        "entity": _one(tx, "SELECT entity_id FROM core.entity WHERE short_name = 'GoM'"),
        "concept": _one(tx, "SELECT concept_id FROM ref.concept WHERE code = 'tax_revenue'"),
        "period": _one(
            tx,
            "INSERT INTO core.period (period_type, start_date, end_date) "
            "VALUES ('duration', '2024-07-01', '2025-06-30') RETURNING period_id",
        ),
    }


def _insert_fact(tx, f: dict, value: int) -> str:
    return _one(
        tx,
        "INSERT INTO core.fact (concept_id, entity_id, period_id, unit_code, value_numeric) "
        "VALUES (%s, %s, %s, 'MWK', %s) RETURNING fact_id",
        (f["concept"], f["entity"], f["period"], value),
    )


def _savepoint_raises(tx, exc: type[Exception], sql: str, params: tuple = ()) -> None:
    """Run `sql` in a savepoint and assert it fails, leaving the outer transaction usable."""
    with pytest.raises(exc):
        with tx.transaction():
            tx.execute(sql, params)


# --- append-only facts -----------------------------------------------------------------------


def test_fact_value_cannot_be_updated(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    _savepoint_raises(
        tx,
        errors.RaiseException,
        "UPDATE core.fact SET value_numeric = 999 WHERE fact_id = %s",
        (fid,),
    )


def test_fact_cannot_be_deleted_or_truncated(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    _savepoint_raises(tx, errors.RaiseException, "DELETE FROM core.fact WHERE fact_id = %s", (fid,))
    _savepoint_raises(tx, errors.RaiseException, "TRUNCATE core.fact CASCADE")


def test_supersede_once_sets_status(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    tx.execute("UPDATE core.fact SET superseded_at = now() WHERE fact_id = %s", (fid,))
    assert _one(tx, "SELECT status FROM core.fact WHERE fact_id = %s", (fid,)) == "superseded"
    _savepoint_raises(
        tx,
        errors.RaiseException,
        "UPDATE core.fact SET superseded_at = now() + interval '1 day' WHERE fact_id = %s",
        (fid,),
    )


def test_supersede_cannot_smuggle_a_value_change(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    _savepoint_raises(
        tx,
        errors.RaiseException,
        "UPDATE core.fact SET superseded_at = now(), value_numeric = 1 WHERE fact_id = %s",
        (fid,),
    )


def test_retraction_is_a_supersede_with_status(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    tx.execute(
        "UPDATE core.fact SET superseded_at = now(), status = 'retracted' WHERE fact_id = %s",
        (fid,),
    )
    assert _one(tx, "SELECT status FROM core.fact WHERE fact_id = %s", (fid,)) == "retracted"


def test_only_one_current_fact_per_key(tx, fact_inputs) -> None:
    first = _insert_fact(tx, fact_inputs, 100)
    with pytest.raises(errors.UniqueViolation):
        with tx.transaction():
            _insert_fact(tx, fact_inputs, 105)
    # Correct way: supersede, then insert — in one transaction.
    tx.execute("UPDATE core.fact SET superseded_at = now() WHERE fact_id = %s", (first,))
    _insert_fact(tx, fact_inputs, 105)
    current = tx.execute(
        "SELECT value_numeric FROM core.fact WHERE concept_id = %s AND superseded_at IS NULL",
        (fact_inputs["concept"],),
    ).fetchall()
    assert [v for (v,) in current] == [105]


def test_facts_as_of_returns_the_value_published_then(tx, fact_inputs) -> None:
    first = _insert_fact(tx, fact_inputs, 100)
    # now() is constant within a transaction, so supersede the first row an hour in the future.
    tx.execute(
        "UPDATE core.fact SET superseded_at = recorded_at + interval '1 hour' WHERE fact_id = %s",
        (first,),
    )
    _insert_fact(tx, fact_inputs, 105)
    at_insert = _one(
        tx,
        "SELECT value_numeric FROM core.facts_as_of(now()) WHERE fact_id = %s",
        (first,),
    )
    assert at_insert == 100
    later = tx.execute(
        "SELECT value_numeric FROM core.facts_as_of(now() + interval '2 hours') "
        "WHERE concept_id = %s",
        (fact_inputs["concept"],),
    ).fetchall()
    assert [v for (v,) in later] == [105]


def test_fact_dimension_rows_are_immutable(tx, fact_inputs) -> None:
    fid = _insert_fact(tx, fact_inputs, 100)
    dim, member = tx.execute(
        "SELECT d.dimension_id, m.dimension_member_id FROM ref.dimension d "
        "JOIN ref.dimension_member m USING (dimension_id) "
        "WHERE d.code = 'amount_kind' AND m.code = 'actual'"
    ).fetchone()
    tx.execute(
        "INSERT INTO core.fact_dimension (fact_id, dimension_id, dimension_member_id) "
        "VALUES (%s, %s, %s)",
        (fid, dim, member),
    )
    _savepoint_raises(
        tx, errors.RaiseException, "DELETE FROM core.fact_dimension WHERE fact_id = %s", (fid,)
    )


# --- licence tags ----------------------------------------------------------------------------


def test_new_source_defaults_to_permission_pending(tx) -> None:
    tag = _one(
        tx,
        "INSERT INTO source.source_organization (name, source_kind) "
        "VALUES ('Test Daily', 'media') RETURNING license_tag",
    )
    assert tag == "permission_pending"


def test_document_inherits_or_overrides_licence(tx) -> None:
    org = _one(
        tx,
        "INSERT INTO source.source_organization (name, source_kind, license_tag) "
        "VALUES ('Test Registry', 'government', 'public') RETURNING source_organization_id",
    )
    inherit, override = (
        _one(
            tx,
            "INSERT INTO source.document (source_organization_id, document_type, title, "
            "license_tag) VALUES (%s, 'report', %s, %s) RETURNING document_id",
            (org, title, tag),
        )
        for title, tag in (("inherits", None), ("overrides", "research_only"))
    )
    rows = dict(
        tx.execute(
            "SELECT document_id, license_tag FROM source.v_document_license "
            "WHERE document_id IN (%s, %s)",
            (inherit, override),
        ).fetchall()
    )
    assert rows == {inherit: "public", override: "research_only"}


def test_unknown_licence_tag_rejected(tx) -> None:
    _savepoint_raises(
        tx,
        errors.CheckViolation,
        "INSERT INTO source.source_organization (name, source_kind, license_tag) "
        "VALUES ('Bad', 'media', 'free_for_all')",
    )


# --- API keys --------------------------------------------------------------------------------


def test_api_key_must_be_a_sha256_hex_digest(tx) -> None:
    _savepoint_raises(
        tx,
        errors.CheckViolation,
        "INSERT INTO auth.api_key (key_hash, label, tier) VALUES (%s, 'x', 'public')",
        ("not-a-hash".ljust(64, "z"),),
    )
    tx.execute(
        "INSERT INTO auth.api_key (key_hash, label, tier) VALUES (%s, 'pilot', 'research')",
        ("a" * 64,),
    )


# --- roles -----------------------------------------------------------------------------------


def _as(tx, role: str) -> None:
    tx.execute(f"SET LOCAL ROLE {role}")


def test_api_role_reads_keys_but_no_data(tx) -> None:
    _as(tx, "al_mfi_api")
    tx.execute("SELECT count(*) FROM auth.api_key")
    _savepoint_raises(tx, errors.InsufficientPrivilege, "SELECT count(*) FROM core.fact")
    _savepoint_raises(
        tx,
        errors.InsufficientPrivilege,
        "INSERT INTO auth.api_key (key_hash, label, tier) VALUES (%s, 'x', 'public')",
        ("b" * 64,),
    )


def test_reviewer_reads_but_cannot_write_facts(tx) -> None:
    _as(tx, "al_mfi_reviewer")
    tx.execute("SELECT count(*) FROM core.fact")
    _savepoint_raises(
        tx,
        errors.InsufficientPrivilege,
        "INSERT INTO core.entity (entity_kind, legal_name) VALUES ('company', 'X')",
    )


def test_pipeline_writes_but_cannot_delete(tx) -> None:
    _as(tx, "al_mfi_pipeline")
    eid = _one(
        tx,
        "INSERT INTO core.entity (entity_kind, legal_name) VALUES ('company', 'Test Ltd') "
        "RETURNING entity_id",
    )
    _savepoint_raises(
        tx, errors.InsufficientPrivilege, "DELETE FROM core.entity WHERE entity_id = %s", (eid,)
    )
    _savepoint_raises(tx, errors.InsufficientPrivilege, "SELECT count(*) FROM auth.api_key")
