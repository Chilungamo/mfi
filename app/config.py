"""Application settings, read from the environment (and `.env` when present)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    app_name: str = "AL-MFI-001"
    app_version: str = "0.2.0"
    database_url: str = "postgresql+psycopg://al_mfi:al_mfi@localhost:5432/al_mfi"


@lru_cache
def get_settings() -> Settings:
    return Settings()
