"""
app/supabase_client.py — Singleton Supabase admin client (service key).
Using the service role key bypasses all Row Level Security policies,
which is the intended pattern for a trusted backend process.
"""

import logging
from functools import lru_cache

from supabase import create_client, Client

from app.config import get_settings

logger = logging.getLogger(__name__)


@lru_cache()
def get_supabase() -> Client:
    """Return a cached Supabase client authenticated with the service role key."""
    settings = get_settings()

    if not settings.supabase_url or not settings.supabase_service_key:
        logger.warning(
            "SUPABASE_URL or SUPABASE_SERVICE_KEY is not set. "
            "Running in demo mode — Supabase calls will fail gracefully."
        )
        # Return a client pointed at a dummy URL; callers must handle errors.
        return create_client(
            settings.supabase_url or "https://placeholder.supabase.co",
            settings.supabase_service_key or "placeholder",
        )

    client: Client = create_client(settings.supabase_url, settings.supabase_service_key)
    logger.info("Supabase admin client initialised (service role).")
    return client
