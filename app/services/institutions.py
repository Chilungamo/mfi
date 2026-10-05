"""Institutional queries."""

from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

_HOLDERS_SQL = text(
    """
    SELECT full_name, title, appointment_kind, start_date, end_date, organizational_unit_name
    FROM institution.position_holders_on(:as_of)
    WHERE title ILIKE :title
      AND (CAST(:area_id AS uuid) IS NULL OR administrative_area_id = CAST(:area_id AS uuid))
    ORDER BY start_date NULLS FIRST
    """
)


def position_holders_on(
    session: Session, title: str, as_of: date, area_id: str | None = None
) -> list[dict[str, object]]:
    """E.g. who was District Commissioner for a given district on a given date."""
    rows = session.execute(_HOLDERS_SQL, {"as_of": as_of, "title": title, "area_id": area_id})
    return [dict(row._mapping) for row in rows]
