"""
app/services/duplicate_detector.py — Perceptual hash–based duplicate rescue case detector.

A report is considered a duplicate if:
  1. A previous open case (created in the last 2 hours) exists within 100 m, AND
  2. The uploaded image has a perceptual hash distance < 10 from that case's image.

Condition 2 is only evaluated if the existing case has a stored image path; if it
does not, only the geo-proximity test is applied.
"""

from __future__ import annotations

import io
import logging
import math
from typing import Optional

import imagehash
from PIL import Image
from supabase import Client

logger = logging.getLogger(__name__)

DUPLICATE_TIME_WINDOW_HOURS = 2
PROXIMITY_THRESHOLD_KM = 0.1   # 100 m
HASH_DISTANCE_THRESHOLD = 10    # pHash bit-distance


# ─────────────────────────────────────────────────────────────────────────────
# Haversine helper
# ─────────────────────────────────────────────────────────────────────────────

def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    Return the great-circle distance in kilometres between two GPS points.
    """
    R = 6371.0  # Earth radius in km
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)

    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ─────────────────────────────────────────────────────────────────────────────
# Perceptual hash helper
# ─────────────────────────────────────────────────────────────────────────────

def _phash_from_bytes(image_bytes: bytes) -> Optional[imagehash.ImageHash]:
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        return imagehash.phash(img)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Could not compute pHash: %s", exc)
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Main duplicate-detection function
# ─────────────────────────────────────────────────────────────────────────────

async def find_duplicate_case(
    lat: float,
    lng: float,
    image_bytes: bytes,
    supabase_client: Client,
) -> Optional[str]:
    """
    Return the ``case_id`` of an existing open case that is a probable duplicate
    of the incoming report, or ``None`` if no duplicate is found.
    """
    try:
        # ── Fetch recent non-closed cases ─────────────────────────────────────
        from datetime import datetime, timedelta, timezone  # local import to avoid circulars

        cutoff = (datetime.now(timezone.utc) - timedelta(hours=DUPLICATE_TIME_WINDOW_HOURS)).isoformat()

        response = (
            supabase_client.table("rescue_cases")
            .select("id, lat, lng, image_path, status")
            .neq("status", "closed")
            .neq("status", "completed")
            .gte("created_at", cutoff)
            .execute()
        )

        recent_cases = response.data or []
        logger.debug("Duplicate check: %d recent cases to evaluate.", len(recent_cases))

        # Compute pHash of incoming image once
        incoming_hash = _phash_from_bytes(image_bytes)

        for case in recent_cases:
            case_lat = float(case.get("lat", 0))
            case_lng = float(case.get("lng", 0))

            dist_km = haversine_distance(lat, lng, case_lat, case_lng)
            if dist_km > PROXIMITY_THRESHOLD_KM:
                continue  # Not nearby

            # Within 100 m — check image similarity
            existing_image_path: Optional[str] = case.get("image_path")

            if not existing_image_path or incoming_hash is None:
                # No image to compare — proximity alone is sufficient evidence
                logger.info(
                    "Duplicate candidate found (proximity only): case %s (%.1f m away)",
                    case["id"],
                    dist_km * 1000,
                )
                return case["id"]

            # Download existing case image from Supabase Storage for pHash comparison
            try:
                storage_response = supabase_client.storage.from_("animal-images").download(
                    existing_image_path
                )
                existing_hash = _phash_from_bytes(storage_response)
                if existing_hash is not None:
                    distance = incoming_hash - existing_hash
                    logger.debug(
                        "pHash distance for case %s: %d (threshold=%d)",
                        case["id"],
                        distance,
                        HASH_DISTANCE_THRESHOLD,
                    )
                    if distance < HASH_DISTANCE_THRESHOLD:
                        logger.info("Duplicate detected: case %s (pHash dist=%d)", case["id"], distance)
                        return case["id"]
            except Exception as img_exc:  # noqa: BLE001
                logger.warning(
                    "Could not download image for case %s: %s — using proximity only",
                    case["id"],
                    img_exc,
                )
                # Fall back to proximity-only match for this case
                return case["id"]

    except Exception as exc:  # noqa: BLE001
        logger.error("find_duplicate_case error: %s", exc)

    return None
