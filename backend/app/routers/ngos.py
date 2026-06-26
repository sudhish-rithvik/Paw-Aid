"""
app/routers/ngos.py — NGO management endpoints.

Covers NGO registration, profile management, document upload, volunteer
management, and per-NGO case/analytics views.
"""

from __future__ import annotations

import logging
import uuid
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from pydantic import BaseModel

from app.supabase_client import get_supabase
from app.routers.auth import get_current_user_profile
from app.services.brevo_service import send_ngo_verification_pending
from app.services.image_proc import compress_image

logger = logging.getLogger(__name__)
router = APIRouter(tags=["ngos"])


# ─────────────────────────────────────────────────────────────────────────────
# Request models
# ─────────────────────────────────────────────────────────────────────────────

class NGOUpdateRequest(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    specializations: Optional[List[str]] = None
    num_vehicles: Optional[int] = None
    num_volunteers: Optional[int] = None
    service_radius_km: Optional[float] = None
    operating_hours: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None


class FCMTokenUpdate(BaseModel):
    fcm_token: str


class VolunteerCreate(BaseModel):
    name: str
    phone: str
    profile_id: Optional[str] = None


class LocationUpdate(BaseModel):
    lat: float
    lng: float


class AvailabilityUpdate(BaseModel):
    is_available: bool


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/ngos/register", status_code=status.HTTP_201_CREATED)
async def register_ngo(
    name: str = Form(...),
    registration_number: str = Form(...),
    email: str = Form(...),
    phone: str = Form(...),
    city: str = Form(...),
    state: str = Form(...),
    specializations: str = Form("", description="Comma-separated list of animal specialisations"),
    num_vehicles: int = Form(0),
    num_volunteers: int = Form(0),
    service_radius_km: float = Form(25.0),
    operating_hours: str = Form("24/7"),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    documents: List[UploadFile] = File(default=[], description="Supporting documents (PDF/image)"),
):
    """
    Submit an NGO registration request.
    Creates a pending NGO record, uploads documents to Supabase Storage,
    and sends a confirmation email to the NGO.
    """
    supabase = get_supabase()

    ngo_id = str(uuid.uuid4())
    specs = [s.strip() for s in specializations.split(",") if s.strip()] if specializations else []

    ngo_row = {
        "id": ngo_id,
        "name": name,
        "registration_number": registration_number,
        "email": email,
        "phone": phone,
        "city": city,
        "state": state,
        "specializations": specs,
        "status": "pending",
        "num_vehicles": num_vehicles,
        "num_volunteers": num_volunteers,
        "service_radius_km": service_radius_km,
        "operating_hours": operating_hours,
        "lat": lat,
        "lng": lng,
        "avg_response_sec": None,
        "rescue_success_rate": None,
    }

    try:
        supabase.table("ngos").insert(ngo_row).execute()
    except Exception as exc:
        logger.error("NGO insert failed: %s", exc)
        error_msg = str(exc)
        if "duplicate" in error_msg or "unique" in error_msg.lower():
            raise HTTPException(status_code=409, detail="An NGO with this registration number or email already exists.")
        raise HTTPException(status_code=500, detail="Failed to create NGO record.")

    # ── Upload documents ──────────────────────────────────────────────────────
    uploaded_docs = []
    for doc_file in documents:
        if not doc_file.filename:
            continue
        doc_bytes = await doc_file.read()
        ext = doc_file.filename.rsplit(".", 1)[-1].lower() if "." in doc_file.filename else "bin"
        doc_path = f"{ngo_id}/{uuid.uuid4().hex}.{ext}"
        content_type = doc_file.content_type or "application/octet-stream"

        try:
            supabase.storage.from_("ngo-documents").upload(
                path=doc_path,
                file=doc_bytes,
                file_options={"content-type": content_type, "upsert": "true"},
            )
            doc_row = {
                "id": str(uuid.uuid4()),
                "ngo_id": ngo_id,
                "doc_type": ext,
                "storage_path": doc_path,
                "verified_by": None,
            }
            supabase.table("ngo_documents").insert(doc_row).execute()
            uploaded_docs.append(doc_path)
        except Exception as exc:
            logger.warning("Document upload failed (%s): %s", doc_file.filename, exc)

    # ── Send confirmation email ───────────────────────────────────────────────
    try:
        await send_ngo_verification_pending(email, name)
    except Exception as exc:
        logger.warning("Confirmation email failed: %s", exc)

    return {
        "success": True,
        "ngo_id": ngo_id,
        "status": "pending",
        "documents_uploaded": len(uploaded_docs),
        "message": "NGO registration submitted. You will be notified after review.",
    }


@router.get("/ngos/{ngo_id}")
async def get_ngo_profile(ngo_id: str):
    """Return public NGO profile (no auth required)."""
    supabase = get_supabase()
    try:
        resp = supabase.table("ngos").select(
            "id, name, email, phone, city, state, specializations, status, "
            "avg_response_sec, rescue_success_rate, num_vehicles, num_volunteers, "
            "service_radius_km, operating_hours"
        ).eq("id", ngo_id).single().execute()
    except Exception:
        raise HTTPException(status_code=404, detail="NGO not found.")

    if not resp.data:
        raise HTTPException(status_code=404, detail="NGO not found.")
    return resp.data


@router.patch("/ngos/{ngo_id}")
async def update_ngo_profile(
    ngo_id: str,
    body: NGOUpdateRequest,
    profile: dict = Depends(get_current_user_profile),
):
    """Update NGO profile fields (NGO staff or admin only)."""
    if profile.get("role") not in ("ngo_staff", "admin"):
        raise HTTPException(status_code=403, detail="NGO staff or admin required.")

    supabase = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        raise HTTPException(status_code=422, detail="No update fields provided.")

    try:
        supabase.table("ngos").update(updates).eq("id", ngo_id).execute()
    except Exception as exc:
        logger.error("NGO update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update NGO.")

    return {"success": True, "ngo_id": ngo_id, "updated_fields": list(updates.keys())}


@router.patch("/ngos/{ngo_id}/fcm-token")
async def update_ngo_fcm_token(
    ngo_id: str,
    body: FCMTokenUpdate,
    profile: dict = Depends(get_current_user_profile),
):
    """Update the NGO's FCM push token."""
    if profile.get("role") not in ("ngo_staff", "admin"):
        raise HTTPException(status_code=403, detail="NGO staff or admin required.")

    supabase = get_supabase()
    try:
        supabase.table("ngos").update({"fcm_token": body.fcm_token}).eq("id", ngo_id).execute()
    except Exception as exc:
        logger.error("NGO FCM token update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update FCM token.")

    return {"success": True, "message": "NGO FCM token updated."}


@router.get("/ngos/{ngo_id}/cases")
async def get_ngo_cases(
    ngo_id: str,
    case_status: Optional[str] = Query(None, alias="status"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    profile: dict = Depends(get_current_user_profile),
):
    """Get cases assigned to a specific NGO."""
    supabase = get_supabase()

    query = (
        supabase.table("rescue_cases")
        .select("id, status, priority_level, lat, lng, address, created_at, resolved_at", count="exact")
        .eq("assigned_ngo_id", ngo_id)
    )
    if case_status:
        query = query.eq("status", case_status)

    offset = (page - 1) * per_page
    query = query.order("created_at", desc=True).range(offset, offset + per_page - 1)

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("get_ngo_cases error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch NGO cases.")

    return {
        "cases": resp.data or [],
        "total": resp.count or 0,
        "page": page,
        "per_page": per_page,
    }


@router.get("/ngos/{ngo_id}/analytics")
async def get_ngo_analytics(
    ngo_id: str,
    profile: dict = Depends(get_current_user_profile),
):
    """Return aggregated analytics stats for an NGO."""
    supabase = get_supabase()

    try:
        analytics_resp = (
            supabase.table("ngo_analytics")
            .select("*")
            .eq("ngo_id", ngo_id)
            .order("period_date", desc=True)
            .limit(30)
            .execute()
        )
    except Exception:
        analytics_resp = None

    # Also compute live stats from rescue_cases
    try:
        completed_resp = (
            supabase.table("rescue_cases")
            .select("id", count="exact")
            .eq("assigned_ngo_id", ngo_id)
            .eq("status", "completed")
            .execute()
        )
        active_resp = (
            supabase.table("rescue_cases")
            .select("id", count="exact")
            .eq("assigned_ngo_id", ngo_id)
            .not_.in_("status", ["completed", "closed"])
            .execute()
        )
        completed_count = completed_resp.count or 0
        active_count = active_resp.count or 0
    except Exception:
        completed_count = 0
        active_count = 0

    return {
        "ngo_id": ngo_id,
        "completed_cases": completed_count,
        "active_cases": active_count,
        "historical": (analytics_resp.data if analytics_resp else []),
    }


@router.post("/ngos/{ngo_id}/volunteers", status_code=status.HTTP_201_CREATED)
async def add_volunteer(
    ngo_id: str,
    body: VolunteerCreate,
    profile: dict = Depends(get_current_user_profile),
):
    """Add a volunteer to an NGO."""
    if profile.get("role") not in ("ngo_staff", "admin"):
        raise HTTPException(status_code=403, detail="NGO staff or admin required.")

    supabase = get_supabase()
    vol_id = str(uuid.uuid4())
    vol_row = {
        "id": vol_id,
        "ngo_id": ngo_id,
        "profile_id": body.profile_id,
        "name": body.name,
        "phone": body.phone,
        "is_available": True,
        "lat": None,
        "lng": None,
    }

    try:
        supabase.table("volunteers").insert(vol_row).execute()
    except Exception as exc:
        logger.error("Volunteer insert failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to add volunteer.")

    return {"success": True, "volunteer_id": vol_id}


@router.patch("/volunteers/{volunteer_id}/location")
async def update_volunteer_location(
    volunteer_id: str,
    body: LocationUpdate,
    profile: dict = Depends(get_current_user_profile),
):
    """Update a volunteer's GPS location (real-time tracking)."""
    from datetime import datetime, timezone
    supabase = get_supabase()

    try:
        supabase.table("volunteers").update(
            {
                "lat": body.lat,
                "lng": body.lng,
                "last_location_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", volunteer_id).execute()
    except Exception as exc:
        logger.error("Location update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update location.")

    return {"success": True, "volunteer_id": volunteer_id, "lat": body.lat, "lng": body.lng}


@router.patch("/volunteers/{volunteer_id}/availability")
async def toggle_volunteer_availability(
    volunteer_id: str,
    body: AvailabilityUpdate,
    profile: dict = Depends(get_current_user_profile),
):
    """Toggle a volunteer's availability status."""
    supabase = get_supabase()
    try:
        supabase.table("volunteers").update(
            {"is_available": body.is_available}
        ).eq("id", volunteer_id).execute()
    except Exception as exc:
        logger.error("Availability update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update availability.")

    return {"success": True, "volunteer_id": volunteer_id, "is_available": body.is_available}
