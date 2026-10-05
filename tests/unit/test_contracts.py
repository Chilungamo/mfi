from datetime import date
from decimal import Decimal

import pytest

from app.ingestion.contracts import DocumentRef, Location, ObservationRecord

LOC = Location(page_number=12, table_label="Statement of profit or loss")


def test_observation_requires_value() -> None:
    with pytest.raises(ValueError, match="value"):
        ObservationRecord(
            concept_code="revenue", period_end=date(2024, 12, 31), location=LOC, entity_ref="X"
        )


def test_observation_requires_subject() -> None:
    with pytest.raises(ValueError, match="entity"):
        ObservationRecord(
            concept_code="revenue",
            period_end=date(2024, 12, 31),
            location=LOC,
            value_numeric=Decimal("1"),
        )


def test_observation_accepts_area_only_subject() -> None:
    obs = ObservationRecord(
        concept_code="total_expenditure",
        period_end=date(2024, 6, 30),
        period_start=date(2023, 7, 1),
        location=LOC,
        administrative_area_code="MW-ZO",
        value_numeric=Decimal("10"),
    )
    assert obs.administrative_area_code == "MW-ZO"


def test_observation_rejects_inverted_period() -> None:
    with pytest.raises(ValueError, match="period_start"):
        ObservationRecord(
            concept_code="revenue",
            period_end=date(2024, 1, 1),
            period_start=date(2024, 12, 31),
            location=LOC,
            entity_ref="X",
            value_numeric=Decimal("1"),
        )


def test_document_ref_requires_sha256() -> None:
    with pytest.raises(ValueError):
        DocumentRef(
            source_organization="NSO", document_type="report", title="t", content_sha256="abc"
        )
