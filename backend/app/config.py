"""
app/config.py — Application configuration via pydantic-settings.
Reads variables from the .env file at project root.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── Supabase ──────────────────────────────────────────────────────────────
    supabase_url: str = ""
    supabase_service_key: str = ""

    # ── HuggingFace ───────────────────────────────────────────────────────────
    hf_api_key: str = ""

    # ── Firebase ──────────────────────────────────────────────────────────────
    firebase_credentials_path: str = ""

    # ── Brevo ─────────────────────────────────────────────────────────────────
    brevo_api_key: str = ""
    brevo_from_email: str = "no-reply@paw-aid.app"

    # ── Routing ───────────────────────────────────────────────────────────────
    openrouteservice_api_key: str = ""

    # ── Application ───────────────────────────────────────────────────────────
    app_secret_key: str = "changeme_dev_secret"
    backend_url: str = "http://localhost:8000"
    upload_dir: str = "uploads"

    # ── Demo / Dev ────────────────────────────────────────────────────────────
    demo_mode: bool = False


@lru_cache()
def get_settings() -> Settings:
    """Return a cached Settings singleton."""
    return Settings()
