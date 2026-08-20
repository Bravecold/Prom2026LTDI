from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Prom 2026 LCTI API"
    database_url: str = "postgresql+psycopg://prom:prom@localhost:5432/prom2026"
    jwt_secret: str = "change-this-secret-before-production"
    jwt_algorithm: str = "HS256"
    admin_approval_token: str = "change-this-admin-token-before-production"
    access_token_minutes: int = 60
    storage_directory: str = "media"
    azure_storage_connection_string: str | None = None
    azure_storage_container: str = "photos"
    cors_origins: str = "http://localhost:4173"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()