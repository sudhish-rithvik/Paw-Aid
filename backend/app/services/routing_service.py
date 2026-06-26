"""
app/services/routing_service.py — ETA & routing via OSRM and OpenRouteService.

Primary (free, no key): OSRM public demo server.
Secondary (requires API key): OpenRouteService matrix API.
"""

from __future__ import annotations

import logging
import math
from typing import Any, Dict, List, Optional

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

OSRM_BASE = "http://router.project-osrm.org/route/v1/driving"
ORS_MATRIX_URL = "https://api.openrouteservice.org/v2/matrix/driving-car"
TIMEOUT_SECONDS = 15.0


# ─────────────────────────────────────────────────────────────────────────────
# OSRM single-pair ETA
# ─────────────────────────────────────────────────────────────────────────────

async def get_eta(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> Dict[str, Any]:
    """
    Return routing info between two GPS points using OSRM.

    Returns:
        {
            "distance_km": float,
            "duration_minutes": float,
            "eta_text": str,       # human-readable, e.g. "~12 min"
            "source": str,         # "osrm" or "estimate"
        }
    """
    url = f"{OSRM_BASE}/{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
    params = {"overview": "false", "geometries": "geojson"}

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

        if data.get("code") == "Ok" and data.get("routes"):
            route = data["routes"][0]
            dist_m: float = route["distance"]
            dur_s: float = route["duration"]

            dist_km = round(dist_m / 1000, 2)
            dur_min = round(dur_s / 60, 1)

            return {
                "distance_km": dist_km,
                "duration_minutes": dur_min,
                "eta_text": f"~{int(dur_min)} min",
                "source": "osrm",
            }

    except httpx.HTTPStatusError as exc:
        logger.warning("OSRM HTTP error %s", exc.response.status_code)
    except httpx.RequestError as exc:
        logger.warning("OSRM request error: %s", exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("get_eta unexpected error: %s", exc)

    # ── Fallback: straight-line distance × 1.3 road factor at 30 km/h ────────
    dist_km = _haversine_km(origin_lat, origin_lng, dest_lat, dest_lng) * 1.3
    dur_min = (dist_km / 30.0) * 60.0
    logger.info("OSRM unavailable — using straight-line ETA estimate.")

    return {
        "distance_km": round(dist_km, 2),
        "duration_minutes": round(dur_min, 1),
        "eta_text": f"~{int(dur_min)} min (est.)",
        "source": "estimate",
    }


# ─────────────────────────────────────────────────────────────────────────────
# OpenRouteService distance matrix
# ─────────────────────────────────────────────────────────────────────────────

async def get_distance_matrix(
    origins: List[Dict[str, float]],      # [{"lat": ..., "lng": ...}, ...]
    destinations: List[Dict[str, float]], # same format
) -> List[List[Optional[float]]]:
    """
    Return a distance matrix (durations in seconds) using OpenRouteService.
    Falls back to Haversine estimates if the API key is absent or the call fails.

    origins / destinations are lists of {"lat": float, "lng": float} dicts.
    Returns a 2-D list: result[i][j] = duration in seconds from origins[i] to destinations[j].
    """
    settings = get_settings()

    if settings.openrouteservice_api_key:
        # ORS expects [lng, lat] pairs
        all_coords = [[p["lng"], p["lat"]] for p in origins + destinations]
        source_indices = list(range(len(origins)))
        dest_indices = list(range(len(origins), len(origins) + len(destinations)))

        payload = {
            "locations": all_coords,
            "sources": source_indices,
            "destinations": dest_indices,
            "metrics": ["duration"],
        }

        headers = {
            "Authorization": settings.openrouteservice_api_key,
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(ORS_MATRIX_URL, json=payload, headers=headers)
                resp.raise_for_status()
                data = resp.json()

            durations = data.get("durations", [])
            if durations:
                return durations
        except Exception as exc:  # noqa: BLE001
            logger.warning("ORS matrix API error: %s — using Haversine fallback", exc)

    # ── Haversine fallback ────────────────────────────────────────────────────
    SPEED_MPS = 30_000 / 3600.0  # 30 km/h in m/s
    matrix: List[List[float]] = []
    for orig in origins:
        row: List[float] = []
        for dest in destinations:
            dist_km = _haversine_km(orig["lat"], orig["lng"], dest["lat"], dest["lng"]) * 1.3
            row.append((dist_km * 1000) / SPEED_MPS)
        matrix.append(row)
    return matrix


# ─────────────────────────────────────────────────────────────────────────────
# Internal helper
# ─────────────────────────────────────────────────────────────────────────────

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
