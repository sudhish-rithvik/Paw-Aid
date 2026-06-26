"""
app/services/ngo_matcher.py — AI Recommendation Score algorithm for matching
an incoming rescue case to the best available NGO.

Scoring formula (weights sum to 1.0):
  score = eta_score*0.35 + workload_score*0.25 + avail_score*0.20
          + species_score*0.10 + resp_score*0.05 + success_score*0.05

All component scores are normalised 0–1 before weighting.
"""

from __future__ import annotations

import logging
import math
from typing import Any, Dict, List, Optional

from supabase import Client

from app.services.duplicate_detector import haversine_distance

logger = logging.getLogger(__name__)

CITY_SPEED_KMH = 30.0       # assumed average city driving speed
MAX_ETA_MINUTES = 120.0     # beyond this ETA → score 0 for eta component
MAX_ACTIVE_CASES = 20       # NGO considered fully loaded at this number


# ─────────────────────────────────────────────────────────────────────────────
# Component scorers (each returns 0.0 – 1.0)
# ─────────────────────────────────────────────────────────────────────────────

def _eta_score(dist_km: float) -> float:
    """Lower distance → higher score. Linear decay to 0 at MAX_ETA_MINUTES."""
    eta_min = (dist_km / CITY_SPEED_KMH) * 60.0
    if eta_min >= MAX_ETA_MINUTES:
        return 0.0
    return 1.0 - (eta_min / MAX_ETA_MINUTES)


def _workload_score(active_cases: int) -> float:
    """Fewer active cases → higher score."""
    if active_cases >= MAX_ACTIVE_CASES:
        return 0.0
    return 1.0 - (active_cases / MAX_ACTIVE_CASES)


def _availability_score(num_volunteers: int, num_vehicles: int) -> float:
    """Proportional to available resources (volunteers weighted 2x, capped at 1)."""
    resource_score = min((num_volunteers + num_vehicles * 2) / 10.0, 1.0)
    return resource_score


def _species_score(specializations: List[str], species: str) -> float:
    """1.0 if NGO handles the specific species, 0.5 if generic, 0.0 if excluded."""
    if not specializations:
        return 0.5
    species_lower = species.lower()
    specs_lower = [s.lower() for s in specializations]
    for spec in specs_lower:
        if species_lower in spec or spec in ("all", "any", "general", "all animals"):
            return 1.0
    for spec in specs_lower:
        if any(kw in spec for kw in ("wildlife", "stray", "animal")):
            return 0.5
    return 0.3


def _response_score(avg_response_sec: Optional[float]) -> float:
    """
    Score based on historical average response time.
    Best = 5 min (300 s), worst = 60 min (3600 s).
    """
    if avg_response_sec is None:
        return 0.5  # no data → neutral
    best, worst = 300.0, 3600.0
    clamped = max(best, min(float(avg_response_sec), worst))
    return 1.0 - (clamped - best) / (worst - best)


def _success_score(success_rate: Optional[float]) -> float:
    """Rescue success rate is already 0–1."""
    if success_rate is None:
        return 0.5
    return max(0.0, min(float(success_rate), 1.0))


# ─────────────────────────────────────────────────────────────────────────────
# Main matcher
# ─────────────────────────────────────────────────────────────────────────────

async def find_best_ngo(
    case_lat: float,
    case_lng: float,
    species: str,
    supabase_client: Client,
) -> Optional[Dict[str, Any]]:
    """
    Fetch all approved NGOs and return the one with the highest recommendation
    score, or None if no NGO could be scored above 0.
    """
    try:
        ngo_resp = (
            supabase_client.table("ngos")
            .select("*")
            .eq("status", "approved")
            .execute()
        )
        ngos: List[Dict[str, Any]] = ngo_resp.data or []

        if not ngos:
            logger.warning("No approved NGOs available for matching.")
            return None

        best_ngo: Optional[Dict[str, Any]] = None
        best_score: float = 0.0

        for ngo in ngos:
            ngo_lat = ngo.get("lat") or ngo.get("latitude")
            ngo_lng = ngo.get("lng") or ngo.get("longitude")

            # Skip if location unknown
            if ngo_lat is None or ngo_lng is None:
                logger.debug("NGO %s has no location; skipping.", ngo.get("id"))
                continue

            dist_km = haversine_distance(case_lat, case_lng, float(ngo_lat), float(ngo_lng))

            # Hard cutoff: NGO must be within its declared service radius
            service_radius = float(ngo.get("service_radius_km") or 50.0)
            if dist_km > service_radius:
                logger.debug(
                    "NGO %s is %.1f km away (radius=%.1f km); outside range.",
                    ngo.get("id"),
                    dist_km,
                    service_radius,
                )
                continue

            # ── Count active cases for workload ───────────────────────────────
            try:
                active_resp = (
                    supabase_client.table("rescue_cases")
                    .select("id", count="exact")
                    .eq("assigned_ngo_id", ngo["id"])
                    .not_.in_("status", ["completed", "closed"])
                    .execute()
                )
                active_count = active_resp.count or 0
            except Exception:
                active_count = 0

            # ── Component scores ──────────────────────────────────────────────
            e = _eta_score(dist_km)
            w = _workload_score(active_count)
            a = _availability_score(
                int(ngo.get("num_volunteers") or 0),
                int(ngo.get("num_vehicles") or 0),
            )
            s = _species_score(list(ngo.get("specializations") or []), species)
            r = _response_score(ngo.get("avg_response_sec"))
            u = _success_score(ngo.get("rescue_success_rate"))

            composite = e * 0.35 + w * 0.25 + a * 0.20 + s * 0.10 + r * 0.05 + u * 0.05

            logger.debug(
                "NGO %s | dist=%.1fkm | eta=%.2f wkld=%.2f avail=%.2f species=%.2f resp=%.2f succ=%.2f → %.3f",
                ngo.get("name", ngo.get("id")),
                dist_km,
                e, w, a, s, r, u,
                composite,
            )

            if composite > best_score:
                best_score = composite
                best_ngo = ngo

        if best_ngo and best_score > 0:
            logger.info(
                "Best NGO match: %s (score=%.3f)",
                best_ngo.get("name", best_ngo.get("id")),
                best_score,
            )
            return best_ngo

        logger.warning("No suitable NGO found (all scored 0).")
        return None

    except Exception as exc:  # noqa: BLE001
        logger.error("find_best_ngo error: %s", exc)
        return None
