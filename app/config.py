"""Application settings, read from the environment (and `.env` when present).

This is the only module that reads environment variables. Secrets have no defaults, so a
missing one fails at start-up rather than halfway through a run.
"""

from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    app_name: str = "AL-MFI-001"
    app_version: str = "0.2.0"

    # Pipelines and migrations connect with this URL (role mmd_pipeline / owner).
    database_url: str = "postgresql+psycopg://al_mfi:al_mfi@localhost:5432/al_mfi"
    # The read-only API connects separately (role mmd_api); falls back to database_url locally.
    api_database_url: str | None = None

    # Raw archive: S3-compatible object storage. Endpoint is None on AWS, MinIO URL locally.
    s3_endpoint: str | None = None
    s3_bucket: str = "al-mfi-raw"
    s3_access_key: SecretStr
    s3_secret_key: SecretStr

    # Sent on every outbound request so source owners can identify and contact us.
    # Set a real contact address in .env before collecting from live sites.
    user_agent: str = "AL-MFI-001-research/0.2 (contact: set USER_AGENT in .env)"
    # Recorded on every extraction so outputs can be traced to the code that produced them.
    extractor_version: str = "0.1.0"

    @property
    def effective_api_database_url(self) -> str:
        return self.api_database_url or self.database_url


@lru_cache
def get_settings() -> Settings:
    return Settings()  # pyright: ignore[reportCallIssue]  # required fields come from the env
