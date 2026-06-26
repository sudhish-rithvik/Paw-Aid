"""
app/routers/reports.py — Animal rescue report submission endpoints.

POST /reports  — Core report submission with AI pipeline running in background.
GET /reports/{case_id}/status — Public case status lookup (no auth required).
"""

from __future__ import annotations

import logging
import mimetypes
import uuid
from typing import Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    UploadFile,
    status,
)

from app.supabase_client import get_supabase
from app.routers.auth import get_current_user
from app.services.image_proc import compress_image, preprocess_image
from app.services.duplicate_detector import find_duplicate_case
from app.services.nominatim_service import reverse_geocode
from app.services.hf_inference import analyze_animal_image
from app.services.priority_engine import compute_priority
from app.services.ngo_matcher import find_best_ngo
from app.services.fcm_service import send_case_update

logger = logging.getLogger(__name__)
router = APIRouter(tags=["reports"])

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}
MAX_FILE_SIZE_MB = 20


# ─────────────────────────────────────────────────────────────────────────────
# Background AI pipeline
# ─────────────────────────────────────────────────────────────────────────────

async def _run_ai_pipeline(
    case_id: str,
    image_bytes: bytes,
    reporter_id: Optional[str],
) -> None:
    """
    Background task that:
    1. Runs the HuggingFace vision analysis.
    2. Saves results to `ai_analyses`.
    3. Computes priority and updates `rescue_cases`.
    4. Finds the best NGO and assigns it.
    5. Sends FCM push to the reporter.
    """
    supabase = get_supabase()
    logger.info("AI pipeline started for case %s", case_id)

    try:
        # ── 1. AI Analysis ────────────────────────────────────────────────────
        raw = await analyze_animal_image(image_bytes)
        raw_copy = dict(raw)
        raw_response = raw_copy.pop("_raw_response", None)

        ai_row = {
            "id": str(uuid.uuid4()),
            "case_id": case_id,
            "animal": raw_copy.get("animal", "Unknown"),
            "visible_injuries": raw_copy.get("visible_injuries", []),
            "mobility": raw_copy.get("mobility", "Unknown"),
            "pain_level": raw_copy.get("pain_level", "Unknown"),
            "severity": raw_copy.get("severity", "medium"),
            "confidence": float(raw_copy.get("confidence", 0.5)),
            "recommended_action": raw_copy.get("recommended_action", ""),
            "reason": raw_copy.get("reason", ""),
            "raw_response": raw_response,
        }

        supabase.table("ai_analyses").upsert(ai_row, on_conflict="case_id").execute()
        logger.info("AI analysis saved for case %s", case_id)

        # ── 2. Priority computation ───────────────────────────────────────────
        priority = compute_priority(raw_copy)
        supabase.table("rescue_cases").update(
            {"priority_level": priority.value}
        ).eq("id", case_id).execute()
        logger.info("Priority set to %s for case %s", priority.value, case_id)

        # ── 3. NGO matching ───────────────────────────────────────────────────
        case_resp = supabase.table("rescue_cases").select("lat, lng").eq("id", case_id).single().execute()
        case_data = case_resp.data or {}
        case_lat = float(case_data.get("lat", 0))
        case_lng = float(case_data.get("lng", 0))
        species = raw_copy.get("animal", "Unknown")

        best_ngo = await find_best_ngo(case_lat, case_lng, species, supabase)

        if best_ngo:
            supabase.table("rescue_cases").update(
                {
                    "assigned_ngo_id": best_ngo["id"],
                    "status": "accepted",
                }
            ).eq("id", case_id).execute()

            # Create rescue event
            supabase.table("rescue_events").insert(
                {
                    "id": str(uuid.uuid4()),
                    "case_id": case_id,
                    "event_type": "ngo_assigned",
                    "actor_id": None,
                    "metadata": {
                        "ngo_id": best_ngo["id"],
                        "ngo_name": best_ngo.get("name"),
                        "method": "ai_auto_assign",
                    },
                }
            ).execute()

            logger.info("NGO %s assigned to case %s", best_ngo.get("name"), case_id)

            # Notify NGO via FCM
            ngo_fcm = best_ngo.get("fcm_token")
            if ngo_fcm:
                from app.services.fcm_service import send_to_token
                send_to_token(
                    ngo_fcm,
                    title=f"🚨 New {priority.value.upper()} Rescue Case",
                    body=f"{species} needs rescue — priority: {priority.value}",
                    data={"case_id": case_id, "type": "new_case", "priority": priority.value},
                )
        else:
            logger.warning("No NGO matched for case %s — escalating to admin.", case_id)

        # ── 4. Notify reporter ────────────────────────────────────────────────
        if reporter_id:
            try:
                profile_resp = (
                    supabase.table("profiles")
                    .select("fcm_token")
                    .eq("id", reporter_id)
                    .single()
                    .execute()
                )
                fcm_token = (profile_resp.data or {}).get("fcm_token")
                if fcm_token:
                    new_status = "accepted" if best_ngo else "pending"
                    send_case_update(fcm_token, case_id, new_status, species)
            except Exception as fcm_exc:
                logger.warning("Reporter FCM notification failed: %s", fcm_exc)

    except Exception as exc:  # noqa: BLE001
        logger.error("AI pipeline error for case %s: %s", case_id, exc, exc_info=True)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/reports", status_code=status.HTTP_202_ACCEPTED)
async def submit_report(
    background_tasks: BackgroundTasks,
    image: UploadFile = File(..., description="Photo of the injured animal"),
    lat: float = Form(..., description="Latitude of incident"),
    lng: float = Form(..., description="Longitude of incident"),
    notes: Optional[str] = Form(None, description="Any additional notes"),
    authorization: Optional[str] = Header(None),
):
    """
    Submit an animal rescue report.

    - Validates image MIME type
    - Compresses image
    - Checks for duplicates
    - Uploads to Supabase Storage
    - Reverse geocodes GPS coordinates
    - Creates rescue_case record
    - Kicks off AI analysis pipeline in background
    - Returns case_id immediately
    """
    supabase = get_supabase()

    # ── Resolve optional reporter ─────────────────────────────────────────────
    reporter_id: Optional[str] = None
    if authorization and authorization.startswith("Bearer "):
        try:
            token = authorization.split(" ", 1)[1]
            user_resp = supabase.auth.get_user(token)
            if user_resp and user_resp.user:
                reporter_id = user_resp.user.id
        except Exception:
            pass  # guest mode — continue without reporter_id

    # ── MIME validation ───────────────────────────────────────────────────────
    content_type = image.content_type or ""
    if content_type not in ALLOWED_MIME_TYPES:
        # Try to detect from filename
        guessed, _ = mimetypes.guess_type(image.filename or "")
        if guessed not in ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=415,
                detail=f"Unsupported image type '{content_type}'. Allowed: JPEG, PNG, WebP, HEIC.",
            )

    raw_bytes = await image.read()
    if len(raw_bytes) > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large. Maximum allowed: {MAX_FILE_SIZE_MB} MB.",
        )

    # ── Image processing ──────────────────────────────────────────────────────
    compressed = compress_image(raw_bytes, quality=85)
    preprocessed = preprocess_image(compressed)

    # ── Duplicate detection ───────────────────────────────────────────────────
    existing_case_id = await find_duplicate_case(lat, lng, preprocessed, supabase)
    if existing_case_id:
        return {
            "success": True,
            "duplicate": True,
            "case_id": existing_case_id,
            "message": "A similar rescue case already exists nearby. Your report has been noted.",
        }

    # ── Upload image to Supabase Storage ──────────────────────────────────────
    case_id = str(uuid.uuid4())
    storage_path = f"{case_id}/original.jpg"

    try:
        supabase.storage.from_("animal-images").upload(
            path=storage_path,
            file=preprocessed,
            file_options={"content-type": "image/jpeg", "upsert": "true"},
        )
    except Exception as exc:
        logger.error("Storage upload failed for case %s: %s", case_id, exc)
        # Continue without image rather than blocking the rescue report
        storage_path = None

    # ── Reverse geocode ───────────────────────────────────────────────────────
    address = await reverse_geocode(lat, lng)

    # ── Create rescue_case record ─────────────────────────────────────────────
    case_row = {
        "id": case_id,
        "reporter_id": reporter_id,
        "lat": lat,
        "lng": lng,
        "address": address,
        "notes": notes,
        "image_path": storage_path,
        "status": "pending",
        "priority_level": None,  # Will be set by AI pipeline
        "assigned_ngo_id": None,
    }

    try:
        supabase.table("rescue_cases").insert(case_row).execute()
    except Exception as exc:
        logger.error("rescue_cases insert failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to create rescue case record.")

    # Create initial event
    try:
        supabase.table("rescue_events").insert(
            {
                "id": str(uuid.uuid4()),
                "case_id": case_id,
                "event_type": "case_created",
                "actor_id": reporter_id,
                "metadata": {"address": address, "notes": notes},
            }
        ).execute()
    except Exception as exc:
        logger.warning("rescue_events insert failed: %s", exc)

    # ── Schedule background AI pipeline ───────────────────────────────────────
    background_tasks.add_task(
        _run_ai_pipeline,
        case_id,
        preprocessed,
        reporter_id,
    )

    return {
        "success": True,
        "duplicate": False,
        "case_id": case_id,
        "address": address,
        "message": "Report submitted successfully. AI analysis is in progress.",
    }


@router.get("/reports/{case_id}/status")
async def get_case_status(case_id: str):
    """Public endpoint to check rescue case status without authentication."""
    supabase = get_supabase()

    try:
        resp = (
            supabase.table("rescue_cases")
            .select(
                "id, status, priority_level, address, created_at, "
                "assigned_ngo_id, assigned_volunteer_id, resolved_at"
            )
            .eq("id", case_id)
            .single()
            .execute()
        )
    except Exception as exc:
        logger.error("get_case_status error: %s", exc)
        raise HTTPException(status_code=404, detail="Case not found.")

    if not resp.data:
        raise HTTPException(status_code=404, detail="Case not found.")

    data = resp.data

    # Try to fetch AI analysis summary
    ai_summary = None
    try:
        ai_resp = (
            supabase.table("ai_analyses")
            .select("animal, severity, recommended_action, confidence")
            .eq("case_id", case_id)
            .single()
            .execute()
        )
        ai_summary = ai_resp.data
    except Exception:
        pass

    return {
        **data,
        "ai_summary": ai_summary,
    }
