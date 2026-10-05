"""Health and metadata endpoints."""

from fastapi import APIRouter

from app import db
from app.config import get_settings
from app.lineage import LINEAGE

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/db")
def health_db() -> dict[str, str]:
    return {"database": "ok" if db.ping() else "unavailable"}


@router.get("/meta")
def meta() -> dict[str, object]:
    settings = get_settings()
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_env,
        "lineage": [stage.value for stage in LINEAGE],
    }
