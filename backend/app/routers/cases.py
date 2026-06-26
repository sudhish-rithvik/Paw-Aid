"""
app/routers/cases.py — Rescue case management endpoints.

Covers:
- GET  /cases              — Paginated list with filters
- GET  /cases/nearby       — Geo-proximity search
- GET  /cases/{case_id}    — Full detail with AI analysis
- PATCH /cases/{case_id}/status  — Stage transition (NGO/admin auth)
- POST  /cases/{case_id}/accept  — NGO accepts a case
"""

from __future__ import annotations

import logging
import uuid
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)

from app.supabase_client import get_supabase
from app.routers.auth import get_current_user_profile
from app.schemas.common import CaseStatus, PriorityLevel, STATUS_TRANSITIONS
from app.services.fcm_service import send_case_update
from app.services.duplicate_detector import haversine_distance
from app.services.image_proc import compress_image

logger = logging.getLogger(__name__)
router = APIRouter(tags=["cases"])


# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────

def _fetch_ai_analysis(supabase, case_id: str) -> Optional[dict]:
    try:
        ai_resp = (
            supabase.table("ai_analyses")
            .select("*")
            .eq("case_id", case_id)
            .single()
            .execute()
        )
        return ai_resp.data
    except Exception:
        return None


def _get_reporter_fcm(supabase, reporter_id: Optional[str]) -> Optional[str]:
    if not reporter_id:
        return None
    try:
        resp = (
            supabase.table("profiles")
            .select("fcm_token")
            .eq("id", reporter_id)
            .single()
            .execute()
        )
        return (resp.data or {}).get("fcm_token")
    except Exception:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/ngo/queue")
async def get_ngo_queue(
    ngo_id: Optional[str] = None,
    profile: dict = Depends(get_current_user_profile),
):
    """
    Get the rescue queue for an NGO:
    1. Active cases currently assigned to this NGO (not completed/closed).
    2. Pending/unassigned cases, sorted by AI Recommendation Score.
    """
    supabase = get_supabase()

    # Resolve NGO ID if not provided and user is NGO staff
    if not ngo_id and profile.get("role") == "ngo_staff":
        try:
            vol_resp = (
                supabase.table("volunteers")
                .select("ngo_id")
                .eq("profile_id", profile["id"])
                .single()
                .execute()
            )
            ngo_id = (vol_resp.data or {}).get("ngo_id")
        except Exception:
            pass

    try:
        # Query active cases
        # Format query to get cases where: status is 'pending' OR assigned_ngo_id = ngo_id
        # and status is not completed/closed
        query = supabase.table("rescue_cases").select("*")
        if ngo_id:
            query = query.or_(f"assigned_ngo_id.eq.{ngo_id},status.eq.pending")
        else:
            query = query.eq("status", "pending")

        resp = query.not_.in_("status", ["completed", "closed"]).execute()
        cases = resp.data or []

        hydrated = []
        for case in cases:
            ai_analysis = _fetch_ai_analysis(supabase, case["id"])
            score = 0.0

            # Calculate AI Recommendation Score if NGO is known
            if ngo_id:
                try:
                    ngo_resp = supabase.table("ngos").select("*").eq("id", ngo_id).single().execute()
                    ngo_data = ngo_resp.data
                    if ngo_data and ngo_data.get("lat") is not None and ngo_data.get("lng") is not None:
                        from app.services.ngo_matcher import (
                            haversine_distance,
                            _eta_score,
                            _workload_score,
                            _availability_score,
                            _species_score,
                            _response_score,
                            _success_score,
                        )

                        dist_km = haversine_distance(
                            float(case["lat"]),
                            float(case["lng"]),
                            float(ngo_data["lat"]),
                            float(ngo_data["lng"]),
                        )
                        service_radius = float(ngo_data.get("service_radius_km") or 50.0)
                        
                        # Only score if within range
                        if dist_km <= service_radius:
                            e = _eta_score(dist_km)
                            
                            active_resp = (
                                supabase.table("rescue_cases")
                                .select("id", count="exact")
                                .eq("assigned_ngo_id", ngo_id)
                                .not_.in_("status", ["completed", "closed"])
                                .execute()
                            )
                            active_count = active_resp.count or 0
                            w = _workload_score(active_count)
                            
                            a = _availability_score(
                                int(ngo_data.get("num_volunteers") or 0),
                                int(ngo_data.get("num_vehicles") or 0),
                            )
                            
                            species = (ai_analysis or {}).get("animal", "Unknown")
                            s = _species_score(list(ngo_data.get("specializations") or []), species)
                            r = _response_score(ngo_data.get("avg_response_sec"))
                            u = _success_score(ngo_data.get("rescue_success_rate"))
                            
                            score = (
                                e * 0.35 +
                                w * 0.25 +
                                a * 0.20 +
                                s * 0.10 +
                                r * 0.05 +
                                u * 0.05
                            ) * 100.0
                except Exception as exc:
                    logger.warning("Score calc failed: %s", exc)

            hydrated.append({
                **case,
                "ai_analysis": ai_analysis,
                "ai_score": round(score, 1),
            })

        # Sort: Assigned first, then by score desc, then by date desc
        def sort_key(c):
            is_assigned = 1 if c.get("assigned_ngo_id") == ngo_id else 0
            score = c.get("ai_score") or 0.0
            return (is_assigned, score, c.get("created_at", ""))

        hydrated.sort(key=sort_key, reverse=True)
        return hydrated

    except Exception as exc:
        logger.error("get_ngo_queue error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch NGO queue.")

@router.get("/cases")
async def list_cases(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    case_status: Optional[CaseStatus] = Query(None, alias="status"),
    priority: Optional[PriorityLevel] = None,
    assigned_ngo_id: Optional[str] = None,
    profile: dict = Depends(get_current_user_profile),
):
    """
    List rescue cases with optional filters.
    NGO staff only see cases assigned to their NGO (unless admin).
    """
    supabase = get_supabase()

    query = supabase.table("rescue_cases").select(
        "id, status, priority_level, lat, lng, address, "
        "created_at, assigned_ngo_id, reporter_id, notes",
        count="exact",
    )

    if case_status:
        query = query.eq("status", case_status.value)
    if priority:
        query = query.eq("priority_level", priority.value)
    if assigned_ngo_id:
        query = query.eq("assigned_ngo_id", assigned_ngo_id)

    # Non-admin NGO staff: restrict to their assigned cases
    if profile.get("role") == "ngo_staff" and not assigned_ngo_id:
        # Fetch their NGO id
        try:
            vol_resp = (
                supabase.table("volunteers")
                .select("ngo_id")
                .eq("profile_id", profile["id"])
                .single()
                .execute()
            )
            ngo_id = (vol_resp.data or {}).get("ngo_id")
            if ngo_id:
                query = query.eq("assigned_ngo_id", ngo_id)
        except Exception:
            pass

    offset = (page - 1) * per_page
    query = query.order("created_at", desc=True).range(offset, offset + per_page - 1)

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("list_cases error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch cases.")

    return {
        "cases": resp.data or [],
        "total": resp.count or 0,
        "page": page,
        "per_page": per_page,
    }


@router.get("/cases/nearby")
async def get_nearby_cases(
    lat: float = Query(..., description="Centre latitude"),
    lng: float = Query(..., description="Centre longitude"),
    radius_km: float = Query(5.0, description="Search radius in kilometres"),
    case_status: Optional[CaseStatus] = Query(None, alias="status"),
):
    """
    Return open rescue cases within *radius_km* km of the given point.
    Filtering is done in Python after fetching recent cases (Supabase has no
    native geo-distance filter without PostGIS extensions).
    """
    supabase = get_supabase()

    query = supabase.table("rescue_cases").select(
        "id, status, priority_level, lat, lng, address, created_at, assigned_ngo_id"
    )
    if case_status:
        query = query.eq("status", case_status.value)
    else:
        query = query.not_.in_("status", ["completed", "closed"])

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("get_nearby_cases error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch nearby cases.")

    nearby = []
    for case in resp.data or []:
        dist = haversine_distance(lat, lng, float(case["lat"]), float(case["lng"]))
        if dist <= radius_km:
            nearby.append({**case, "distance_km": round(dist, 3)})

    nearby.sort(key=lambda c: c["distance_km"])
    return {"cases": nearby, "total": len(nearby), "radius_km": radius_km}


@router.get("/cases/{case_id}")
async def get_case_detail(
    case_id: str,
    profile: dict = Depends(get_current_user_profile),
):
    """Return full case detail including AI analysis and rescue events."""
    supabase = get_supabase()

    try:
        case_resp = (
            supabase.table("rescue_cases").select("*").eq("id", case_id).single().execute()
        )
    except Exception as exc:
        logger.error("get_case_detail error: %s", exc)
        raise HTTPException(status_code=404, detail="Case not found.")

    if not case_resp.data:
        raise HTTPException(status_code=404, detail="Case not found.")

    case = case_resp.data

    # AI analysis
    ai = _fetch_ai_analysis(supabase, case_id)

    # Rescue events
    try:
        events_resp = (
            supabase.table("rescue_events")
            .select("*")
            .eq("case_id", case_id)
            .order("created_at")
            .execute()
        )
        events = events_resp.data or []
    except Exception:
        events = []

    return {**case, "ai_analysis": ai, "events": events}


@router.patch("/cases/{case_id}/status")
async def update_case_status(
    case_id: str,
    new_status: CaseStatus = Form(...),
    stage_image: Optional[UploadFile] = File(None),
    notes: Optional[str] = Form(None),
    profile: dict = Depends(get_current_user_profile),
):
    """
    Advance the rescue case to a new status stage.
    Validates legal forward transitions and optionally attaches a stage photo.
    """
    if profile.get("role") not in ("ngo_staff", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only NGO staff or admins can update case status.",
        )

    supabase = get_supabase()

    # Fetch current case
    try:
        resp = (
            supabase.table("rescue_cases")
            .select("id, status, reporter_id, assigned_ngo_id")
            .eq("id", case_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Case not found.")

    if not resp.data:
        raise HTTPException(status_code=404, detail="Case not found.")

    case = resp.data
    current_status = CaseStatus(case["status"])

    # Validate transition
    allowed_transitions = STATUS_TRANSITIONS.get(current_status, [])
    if new_status not in allowed_transitions:
        raise HTTPException(
            status_code=422,
            detail=(
                f"Cannot transition from '{current_status.value}' to '{new_status.value}'. "
                f"Allowed next statuses: {[s.value for s in allowed_transitions]}"
            ),
        )

    # Handle optional stage image upload
    stage_image_path: Optional[str] = None
    if stage_image:
        raw = await stage_image.read()
        compressed = compress_image(raw, quality=80)
        stage_image_path = f"{case_id}/stage_{new_status.value}_{uuid.uuid4().hex[:8]}.jpg"
        try:
            supabase.storage.from_("animal-images").upload(
                path=stage_image_path,
                file=compressed,
                file_options={"content-type": "image/jpeg", "upsert": "true"},
            )
        except Exception as exc:
            logger.warning("Stage image upload failed: %s", exc)
            stage_image_path = None

    # Update case status
    update_payload = {"status": new_status.value}
    if new_status in (CaseStatus.completed, CaseStatus.closed):
        from datetime import datetime, timezone
        update_payload["resolved_at"] = datetime.now(timezone.utc).isoformat()

    try:
        supabase.table("rescue_cases").update(update_payload).eq("id", case_id).execute()
    except Exception as exc:
        logger.error("Status update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update case status.")

    # Record rescue event
    try:
        supabase.table("rescue_events").insert(
            {
                "id": str(uuid.uuid4()),
                "case_id": case_id,
                "event_type": f"status_changed_to_{new_status.value}",
                "actor_id": profile["id"],
                "metadata": {"from": current_status.value, "to": new_status.value, "notes": notes},
                "image_path": stage_image_path,
            }
        ).execute()
    except Exception as exc:
        logger.warning("rescue_events insert failed: %s", exc)

    # Notify reporter
    reporter_fcm = _get_reporter_fcm(supabase, case.get("reporter_id"))
    if reporter_fcm:
        try:
            send_case_update(reporter_fcm, case_id, new_status.value)
        except Exception as exc:
            logger.warning("Reporter FCM notification failed: %s", exc)

    return {
        "success": True,
        "case_id": case_id,
        "new_status": new_status.value,
        "stage_image_path": stage_image_path,
    }


@router.post("/cases/{case_id}/accept")
async def ngo_accept_case(
    case_id: str,
    profile: dict = Depends(get_current_user_profile),
):
    """
    Allow an NGO to manually accept a pending case (overriding auto-assignment).
    """
    if profile.get("role") not in ("ngo_staff", "admin"):
        raise HTTPException(status_code=403, detail="NGO staff or admin required.")

    supabase = get_supabase()

    # Fetch case
    try:
        resp = (
            supabase.table("rescue_cases")
            .select("id, status, reporter_id, assigned_ngo_id")
            .eq("id", case_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Case not found.")

    case = resp.data
    if not case:
        raise HTTPException(status_code=404, detail="Case not found.")
    if case["status"] not in ("pending", "accepted"):
        raise HTTPException(
            status_code=422,
            detail=f"Cannot accept a case with status '{case['status']}'.",
        )

    # Resolve NGO id from volunteer profile
    ngo_id: Optional[str] = None
    if profile.get("role") == "ngo_staff":
        try:
            vol_resp = (
                supabase.table("volunteers")
                .select("ngo_id")
                .eq("profile_id", profile["id"])
                .single()
                .execute()
            )
            ngo_id = (vol_resp.data or {}).get("ngo_id")
        except Exception:
            pass
    # Admins can accept on behalf of any NGO — ngo_id stays None for now

    update_payload = {"status": "accepted"}
    if ngo_id:
        update_payload["assigned_ngo_id"] = ngo_id

    try:
        supabase.table("rescue_cases").update(update_payload).eq("id", case_id).execute()
    except Exception as exc:
        logger.error("accept_case update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to accept case.")

    # Record event
    try:
        supabase.table("rescue_events").insert(
            {
                "id": str(uuid.uuid4()),
                "case_id": case_id,
                "event_type": "case_accepted",
                "actor_id": profile["id"],
                "metadata": {"ngo_id": ngo_id, "method": "manual"},
            }
        ).execute()
    except Exception as exc:
        logger.warning("rescue_events insert failed: %s", exc)

    # Notify reporter
    reporter_fcm = _get_reporter_fcm(supabase, case.get("reporter_id"))
    if reporter_fcm:
        try:
            send_case_update(reporter_fcm, case_id, "accepted")
        except Exception as exc:
            logger.warning("Reporter FCM notification failed: %s", exc)

    return {"success": True, "case_id": case_id, "status": "accepted", "assigned_ngo_id": ngo_id}
