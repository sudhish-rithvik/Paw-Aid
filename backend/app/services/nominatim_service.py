"""
app/services/nominatim_service.py — Reverse geocoding via OpenStreetMap Nominatim.

Usage: `await reverse_geocode(lat, lng)` → human-readable address string.
"""

from __future__ import annotations

import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
USER_AGENT = "PAW-AID/1.0 (pawaid@example.com)"
TIMEOUT_SECONDS = 10.0


async def reverse_geocode(lat: float, lng: float) -> str:
    """
    Return a human-readable address for the given GPS coordinates.
    Falls back to "Unknown location" on any failure.
    """
    params = {
        "format": "json",
        "lat": str(lat),
        "lon": str(lng),
        "addressdetails": "1",
    }

    headers = {
        "User-Agent": USER_AGENT,
        "Accept-Language": "en",
    }

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
            response = await client.get(NOMINATIM_URL, params=params, headers=headers)
            response.raise_for_status()
            data = response.json()

        # Prefer the pre-formatted display_name
        display_name: Optional[str] = data.get("display_name")
        if display_name:
            logger.debug("Nominatim geocoded (%.5f, %.5f) → %s", lat, lng, display_name[:80])
            return display_name

        # Fall back to building a string from address components
        address = data.get("address", {})
        parts = [
            address.get("road") or address.get("pedestrian") or address.get("path"),
            address.get("suburb") or address.get("neighbourhood"),
            address.get("city") or address.get("town") or address.get("village"),
            address.get("state"),
            address.get("country"),
        ]
        built = ", ".join(p for p in parts if p)
        if built:
            return built

    except httpx.HTTPStatusError as exc:
        logger.warning(
            "Nominatim HTTP error %s for (%.5f, %.5f)",
            exc.response.status_code,
            lat,
            lng,
        )
    except httpx.RequestError as exc:
        logger.warning("Nominatim request error: %s", exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("reverse_geocode unexpected error: %s", exc)

    return "Unknown location"
