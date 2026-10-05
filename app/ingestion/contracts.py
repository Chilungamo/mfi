"""Ingestion contracts.

Every ingestion pipeline produces these records. They map onto `source.*` and `core.observation`
/ `source.claim` rows, preserving provenance. A pipeline never writes `core.fact` directly:
facts are produced only by validation.
"""

from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from enum import StrEnum
from typing import Protocol


class ExtractionMethod(StrEnum):
    MANUAL = "manual"
    PARSER = "parser"
    OCR = "ocr"
    XBRL = "xbrl"
    API = "api"
    MODEL = "model"


@dataclass(frozen=True, slots=True)
class DocumentRef:
    source_organization: str
    document_type: str
    title: str
    content_sha256: str
    published_on: date | None = None
    canonical_url: str | None = None

    def __post_init__(self) -> None:
        if len(self.content_sha256) != 64:
            raise ValueError("content_sha256 must be a 64-character hex digest")


@dataclass(frozen=True, slots=True)
class Location:
    page_number: int | None = None
    section_label: str | None = None
    table_label: str | None = None
    excerpt: str | None = None


@dataclass(frozen=True, slots=True)
class ObservationRecord:
    concept_code: str
    period_end: date
    location: Location
    period_start: date | None = None
    entity_ref: str | None = None
    organizational_unit_ref: str | None = None
    administrative_area_code: str | None = None
    unit_code: str | None = None
    value_numeric: Decimal | None = None
    value_text: str | None = None
    reported_label: str | None = None
    method: ExtractionMethod = ExtractionMethod.PARSER
    confidence: float | None = None

    def __post_init__(self) -> None:
        if self.value_numeric is None and self.value_text is None:
            raise ValueError("an observation needs a numeric or text value")
        if not (self.entity_ref or self.organizational_unit_ref or self.administrative_area_code):
            raise ValueError("an observation needs an entity, organizational unit or area")
        if self.period_start is not None and self.period_start > self.period_end:
            raise ValueError("period_start must not be after period_end")
        if self.confidence is not None and not 0 <= self.confidence <= 1:
            raise ValueError("confidence must be between 0 and 1")


@dataclass(frozen=True, slots=True)
class ClaimRecord:
    """A statement extracted from a document. Evidence, not truth: always starts unverified."""

    claim_text: str
    location: Location
    claim_kind: str = "statement"
    attributed_to: str | None = None
    about_entity_ref: str | None = None
    claimed_event_date: date | None = None


@dataclass(slots=True)
class IngestionBatch:
    document: DocumentRef
    observations: list[ObservationRecord] = field(default_factory=list)
    claims: list[ClaimRecord] = field(default_factory=list)


class Extractor(Protocol):
    """A source-specific extractor turning raw bytes into an ingestion batch."""

    def extract(self, content: bytes, document: DocumentRef) -> IngestionBatch: ...
