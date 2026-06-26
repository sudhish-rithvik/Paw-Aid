"""
app/routers/analytics.py — Analytics and reporting endpoints.

Provides:
- Heatmap data for map visualisation
- Platform-wide aggregate stats
- NGO-specific stats
- Weekly/monthly trends for charts
- Top hotspot zones
"""

from __future__ import annotations

import logging
import math
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.supabase_client import get_supabase
from app.routers.auth import get_current_user_profile

logger = logging.getLogger(__name__)
router = APIRouter(tags=["analytics"])


# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────

def _grid_key(lat: float, lng: float, cell_deg: float = 0.01) -> str:
    """Snap a GPS point to a grid cell (≈ 1 km at the equator)."""
    return f"{math.floor(lat / cell_deg)},{math.floor(lng / cell_deg)}"


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/analytics/heatmap")
async def get_heatmap(
    start_date: Optional[str] = Query(None, description="ISO date, e.g. 2025-01-01"),
    end_date: Optional[str] = Query(None, description="ISO date, e.g. 2025-12-31"),
    profile: dict = Depends(get_current_user_profile),
):
    """
    Return list of {lat, lng, intensity} points for all rescue cases,
    suitable for rendering a heatmap on the frontend map.
    """
    supabase = get_supabase()

    query = supabase.table("rescue_cases").select("lat, lng, priority_level, status, created_at")

    if start_date:
        query = query.gte("created_at", start_date)
    if end_date:
        query = query.lte("created_at", end_date + "T23:59:59")

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("heatmap query failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch heatmap data.")

    priority_intensity = {
        "critical": 1.0,
        "high": 0.75,
        "medium": 0.5,
        "low": 0.25,
        None: 0.3,
    }

    points = []
    for case in resp.data or []:
        try:
            lat = float(case["lat"])
            lng = float(case["lng"])
        except (TypeError, ValueError):
            continue

        intensity = priority_intensity.get(case.get("priority_level"), 0.3)
        points.append({"lat": lat, "lng": lng, "intensity": intensity})

    return {"points": points, "total": len(points)}


@router.get("/analytics/stats")
async def get_platform_stats(
    profile: dict = Depends(get_current_user_profile),
):
    """
    Platform-wide statistics:
    - Total rescued / active / pending cases
    - Breakdown by severity and species
    - Average response time
    """
    supabase = get_supabase()
    stats = {}

    # Total cases
    try:
        r = supabase.table("rescue_cases").select("id", count="exact").execute()
        stats["total_cases"] = r.count or 0
    except Exception:
        stats["total_cases"] = 0

    # Completed / active / pending
    for s in ("completed", "pending", "accepted", "dispatched"):
        try:
            r = supabase.table("rescue_cases").select("id", count="exact").eq("status", s).execute()
            stats[f"{s}_cases"] = r.count or 0
        except Exception:
            stats[f"{s}_cases"] = 0

    # By priority
    stats["by_priority"] = {}
    for p in ("critical", "high", "medium", "low"):
        try:
            r = supabase.table("rescue_cases").select("id", count="exact").eq("priority_level", p).execute()
            stats["by_priority"][p] = r.count or 0
        except Exception:
            stats["by_priority"][p] = 0

    # Species breakdown from AI analyses
    try:
        ai_resp = supabase.table("ai_analyses").select("animal").execute()
        species_count: dict = defaultdict(int)
        for row in ai_resp.data or []:
            animal = (row.get("animal") or "Unknown").strip().title()
            species_count[animal] += 1
        stats["by_species"] = dict(species_count)
    except Exception:
        stats["by_species"] = {}

    # Average response time (accepted_at - created_at) — proxy from ngo_analytics
    try:
        ngo_resp = supabase.table("ngos").select("avg_response_sec").eq("status", "approved").execute()
        times = [float(n["avg_response_sec"]) for n in (ngo_resp.data or []) if n.get("avg_response_sec")]
        stats["avg_response_sec"] = round(sum(times) / len(times), 1) if times else None
    except Exception:
        stats["avg_response_sec"] = None

    return stats


@router.get("/analytics/ngo/{ngo_id}")
async def get_ngo_stats(
    ngo_id: str,
    profile: dict = Depends(get_current_user_profile),
):
    """NGO-specific analytics: case counts, success rate, response time."""
    supabase = get_supabase()

    try:
        ngo_resp = supabase.table("ngos").select(
            "id, name, avg_response_sec, rescue_success_rate"
        ).eq("id", ngo_id).single().execute()
    except Exception:
        raise HTTPException(status_code=404, detail="NGO not found.")

    ngo = ngo_resp.data or {}

    # Count cases by status
    case_stats = {}
    for s in ("pending", "accepted", "dispatched", "animal_picked", "vet_treatment",
              "recovery", "completed", "closed"):
        try:
            r = (
                supabase.table("rescue_cases")
                .select("id", count="exact")
                .eq("assigned_ngo_id", ngo_id)
                .eq("status", s)
                .execute()
            )
            case_stats[s] = r.count or 0
        except Exception:
            case_stats[s] = 0

    # Historical analytics
    try:
        hist = (
            supabase.table("ngo_analytics")
            .select("period_date, completed_count, avg_response_sec, active_count")
            .eq("ngo_id", ngo_id)
            .order("period_date", desc=True)
            .limit(90)
            .execute()
        )
        historical = hist.data or []
    except Exception:
        historical = []

    return {
        "ngo": ngo,
        "cases_by_status": case_stats,
        "historical": historical,
    }


@router.get("/analytics/trends")
async def get_trends(
    period: str = Query("weekly", regex="^(weekly|monthly)$"),
    weeks: int = Query(12, ge=1, le=52),
    profile: dict = Depends(get_current_user_profile),
):
    """
    Return weekly or monthly case counts for charting.
    Covers the past `weeks` weeks or equivalent months.
    """
    supabase = get_supabase()

    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(weeks=weeks)

    try:
        resp = (
            supabase.table("rescue_cases")
            .select("created_at, status, priority_level")
            .gte("created_at", cutoff.isoformat())
            .execute()
        )
    except Exception as exc:
        logger.error("trends query failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch trend data.")

    # Group by ISO week or year-month
    bucket_counts: dict = defaultdict(int)
    resolved_counts: dict = defaultdict(int)

    for case in resp.data or []:
        try:
            dt = datetime.fromisoformat(case["created_at"].replace("Z", "+00:00"))
        except Exception:
            continue

        if period == "weekly":
            bucket = dt.strftime("%Y-W%W")
        else:
            bucket = dt.strftime("%Y-%m")

        bucket_counts[bucket] += 1
        if case.get("status") in ("completed", "closed"):
            resolved_counts[bucket] += 1

    sorted_buckets = sorted(bucket_counts.keys())
    series = [
        {
            "period": b,
            "total": bucket_counts[b],
            "resolved": resolved_counts.get(b, 0),
        }
        for b in sorted_buckets
    ]

    return {"period": period, "series": series}


@router.get("/analytics/hotspots")
async def get_hotspots(
    top_n: int = Query(10, ge=1, le=50),
    days: int = Query(90, ge=1, le=365),
    profile: dict = Depends(get_current_user_profile),
):
    """
    Return the top N most active rescue hotspot grid cells.
    Each cell covers ≈ 0.01° × 0.01° (≈ 1 km²).
    """
    supabase = get_supabase()

    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    try:
        resp = (
            supabase.table("rescue_cases")
            .select("lat, lng, priority_level")
            .gte("created_at", cutoff)
            .execute()
        )
    except Exception as exc:
        logger.error("hotspots query failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch hotspot data.")

    priority_weight = {"critical": 4, "high": 3, "medium": 2, "low": 1}

    grid: dict = defaultdict(lambda: {"count": 0, "score": 0, "lat_sum": 0.0, "lng_sum": 0.0})

    for case in resp.data or []:
        try:
            lat = float(case["lat"])
            lng = float(case["lng"])
        except (TypeError, ValueError):
            continue

        key = _grid_key(lat, lng)
        w = priority_weight.get(case.get("priority_level"), 1)
        grid[key]["count"] += 1
        grid[key]["score"] += w
        grid[key]["lat_sum"] += lat
        grid[key]["lng_sum"] += lng

    # Build sorted hotspot list
    hotspots = []
    for key, data in grid.items():
        n = data["count"]
        hotspots.append(
            {
                "grid_key": key,
                "lat": round(data["lat_sum"] / n, 5),
                "lng": round(data["lng_sum"] / n, 5),
                "case_count": n,
                "weighted_score": data["score"],
            }
        )

    hotspots.sort(key=lambda h: h["weighted_score"], reverse=True)
    return {"hotspots": hotspots[:top_n], "total_cells": len(hotspots)}
