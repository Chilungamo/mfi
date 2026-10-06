import pytest
from pydantic import ValidationError

from app.config import DatabaseSettings, Settings


def test_missing_secret_fails_fast(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("S3_SECRET_KEY", raising=False)
    with pytest.raises(ValidationError, match="s3_secret_key"):
        Settings(_env_file=None)  # pyright: ignore[reportCallIssue]


def test_secrets_are_not_printed() -> None:
    settings = Settings(_env_file=None)  # pyright: ignore[reportCallIssue]
    assert "test-secret" not in repr(settings)


def test_api_url_falls_back_to_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("API_DATABASE_URL", raising=False)
    settings = Settings(_env_file=None)  # pyright: ignore[reportCallIssue]
    assert settings.effective_api_database_url == settings.database_url


def test_database_tools_need_no_storage_secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("S3_ACCESS_KEY", raising=False)
    monkeypatch.delenv("S3_SECRET_KEY", raising=False)
    assert DatabaseSettings(_env_file=None).database_url  # pyright: ignore[reportCallIssue]
