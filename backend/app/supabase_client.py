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
    """Return a cached Supabase client authenticated with the service role key, or MockSupabaseClient."""
    settings = get_settings()

    if settings.demo_mode or not settings.supabase_url or not settings.supabase_service_key:
        logger.info("Running in demo mode with resilient local sample database.")
        from app.mock_db import MockSupabaseClient
        return MockSupabaseClient()

    try:
        client: Client = create_client(settings.supabase_url, settings.supabase_service_key)
        logger.info("Supabase admin client initialised (service role).")
        return client
    except Exception as exc:
        logger.warning("Failed to initialize Supabase client (%s). Falling back to mock DB.", exc)
        from app.mock_db import MockSupabaseClient
        return MockSupabaseClient()
