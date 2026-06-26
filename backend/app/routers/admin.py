"""
app/routers/admin.py — Admin-only management endpoints.

All routes enforce role=admin via the require_admin dependency.
Covers: NGO verification, case oversight, user management, and KPI stats.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.supabase_client import get_supabase
from app.routers.auth import require_admin
from app.services.brevo_service import send_ngo_approval_email, send_ngo_rejection_email
from app.services.fcm_service import send_to_token

logger = logging.getLogger(__name__)
router = APIRouter(tags=["admin"])


# ─────────────────────────────────────────────────────────────────────────────
# Request models
# ─────────────────────────────────────────────────────────────────────────────

class RejectNGORequest(BaseModel):
    reason: str


class SuspendUserRequest(BaseModel):
    reason: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# NGO verification
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/admin/ngos/pending")
async def list_pending_ngos(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    _admin: dict = Depends(require_admin),
):
    """List all NGOs with status=pending awaiting verification."""
    supabase = get_supabase()
    offset = (page - 1) * per_page

    try:
        resp = (
            supabase.table("ngos")
            .select("id, name, email, phone, city, state, registration_number, specializations, created_at", count="exact")
            .eq("status", "pending")
            .order("created_at")
            .range(offset, offset + per_page - 1)
            .execute()
        )
    except Exception as exc:
        logger.error("list_pending_ngos error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch pending NGOs.")

    return {
        "ngos": resp.data or [],
        "total": resp.count or 0,
        "page": page,
        "per_page": per_page,
    }


@router.get("/admin/ngos/{ngo_id}")
async def admin_get_ngo(
    ngo_id: str,
    _admin: dict = Depends(require_admin),
):
    """Get full NGO record including all uploaded documents."""
    supabase = get_supabase()

    try:
        ngo_resp = supabase.table("ngos").select("*").eq("id", ngo_id).single().execute()
    except Exception:
        raise HTTPException(status_code=404, detail="NGO not found.")

    if not ngo_resp.data:
        raise HTTPException(status_code=404, detail="NGO not found.")

    ngo = ngo_resp.data

    # Fetch documents
    try:
        docs_resp = (
            supabase.table("ngo_documents")
            .select("id, doc_type, storage_path, verified_by")
            .eq("ngo_id", ngo_id)
            .execute()
        )
        ngo["documents"] = docs_resp.data or []
    except Exception:
        ngo["documents"] = []

    return ngo


@router.post("/admin/ngos/{ngo_id}/approve")
async def approve_ngo(
    ngo_id: str,
    admin: dict = Depends(require_admin),
):
    """Approve an NGO registration and notify via email."""
    supabase = get_supabase()

    try:
        resp = supabase.table("ngos").select("email, name, status").eq("id", ngo_id).single().execute()
    except Exception:
        raise HTTPException(status_code=404, detail="NGO not found.")

    ngo = resp.data
    if not ngo:
        raise HTTPException(status_code=404, detail="NGO not found.")
    if ngo["status"] == "approved":
        raise HTTPException(status_code=409, detail="NGO is already approved.")

    try:
        supabase.table("ngos").update(
            {"status": "approved", "rejection_reason": None}
        ).eq("id", ngo_id).execute()
    except Exception as exc:
        logger.error("NGO approve update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to approve NGO.")

    # Mark documents as verified
    try:
        supabase.table("ngo_documents").update(
            {"verified_by": admin["id"]}
        ).eq("ngo_id", ngo_id).execute()
    except Exception as exc:
        logger.warning("Document verification update failed: %s", exc)

    # Email notification
    try:
        await send_ngo_approval_email(ngo["email"], ngo["name"])
    except Exception as exc:
        logger.warning("Approval email failed: %s", exc)

    return {"success": True, "ngo_id": ngo_id, "status": "approved"}


@router.post("/admin/ngos/{ngo_id}/reject")
async def reject_ngo(
    ngo_id: str,
    body: RejectNGORequest,
    _admin: dict = Depends(require_admin),
):
    """Reject an NGO registration with a reason and notify via email."""
    supabase = get_supabase()

    try:
        resp = supabase.table("ngos").select("email, name, status").eq("id", ngo_id).single().execute()
    except Exception:
        raise HTTPException(status_code=404, detail="NGO not found.")

    ngo = resp.data
    if not ngo:
        raise HTTPException(status_code=404, detail="NGO not found.")

    try:
        supabase.table("ngos").update(
            {"status": "rejected", "rejection_reason": body.reason}
        ).eq("id", ngo_id).execute()
    except Exception as exc:
        logger.error("NGO reject update failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to reject NGO.")

    try:
        await send_ngo_rejection_email(ngo["email"], ngo["name"], body.reason)
    except Exception as exc:
        logger.warning("Rejection email failed: %s", exc)

    return {"success": True, "ngo_id": ngo_id, "status": "rejected", "reason": body.reason}


@router.post("/admin/ngos/{ngo_id}/suspend")
async def suspend_ngo(
    ngo_id: str,
    _admin: dict = Depends(require_admin),
):
    """Suspend an approved NGO."""
    supabase = get_supabase()

    try:
        supabase.table("ngos").update({"status": "suspended"}).eq("id", ngo_id).execute()
    except Exception as exc:
        logger.error("NGO suspend failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to suspend NGO.")

    return {"success": True, "ngo_id": ngo_id, "status": "suspended"}


# ─────────────────────────────────────────────────────────────────────────────
# Case oversight
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/admin/cases")
async def admin_list_cases(
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    case_status: Optional[str] = Query(None, alias="status"),
    priority: Optional[str] = None,
    ngo_id: Optional[str] = None,
    _admin: dict = Depends(require_admin),
):
    """Admin view: all rescue cases with optional filters."""
    supabase = get_supabase()

    query = supabase.table("rescue_cases").select(
        "id, status, priority_level, lat, lng, address, "
        "created_at, resolved_at, assigned_ngo_id, reporter_id, notes",
        count="exact",
    )

    if case_status:
        query = query.eq("status", case_status)
    if priority:
        query = query.eq("priority_level", priority)
    if ngo_id:
        query = query.eq("assigned_ngo_id", ngo_id)

    offset = (page - 1) * per_page
    query = query.order("created_at", desc=True).range(offset, offset + per_page - 1)

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("admin_list_cases error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch cases.")

    return {
        "cases": resp.data or [],
        "total": resp.count or 0,
        "page": page,
        "per_page": per_page,
    }


# ─────────────────────────────────────────────────────────────────────────────
# User management
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/admin/users")
async def admin_list_users(
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    role: Optional[str] = None,
    _admin: dict = Depends(require_admin),
):
    """List all user profiles."""
    supabase = get_supabase()

    query = supabase.table("profiles").select("id, role, display_name, phone, fcm_token", count="exact")
    if role:
        query = query.eq("role", role)

    offset = (page - 1) * per_page
    query = query.range(offset, offset + per_page - 1)

    try:
        resp = query.execute()
    except Exception as exc:
        logger.error("admin_list_users error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch users.")

    return {
        "users": resp.data or [],
        "total": resp.count or 0,
        "page": page,
        "per_page": per_page,
    }


@router.post("/admin/users/{user_id}/suspend")
async def suspend_user(
    user_id: str,
    body: SuspendUserRequest,
    admin: dict = Depends(require_admin),
):
    """Suspend a user account by disabling them in Supabase Auth."""
    supabase = get_supabase()

    try:
        supabase.auth.admin.update_user_by_id(
            user_id,
            {"ban_duration": "876600h"},  # ~100 years
        )
    except Exception as exc:
        logger.error("User suspend failed for %s: %s", user_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to suspend user: {exc}")

    return {
        "success": True,
        "user_id": user_id,
        "action": "suspended",
        "reason": body.reason,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Platform KPIs
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/admin/stats")
async def admin_stats(_admin: dict = Depends(require_admin)):
    """
    Platform-wide KPIs:
    - total cases (all time)
    - by status
    - by priority
    - approved / pending NGO counts
    - total registered users
    """
    supabase = get_supabase()
    stats: dict = {}

    # Total cases
    try:
        resp = supabase.table("rescue_cases").select("id", count="exact").execute()
        stats["total_cases"] = resp.count or 0
    except Exception:
        stats["total_cases"] = 0

    # Cases by status
    try:
        from app.schemas.common import CaseStatus
        by_status = {}
        for s in CaseStatus:
            r = supabase.table("rescue_cases").select("id", count="exact").eq("status", s.value).execute()
            by_status[s.value] = r.count or 0
        stats["cases_by_status"] = by_status
    except Exception:
        stats["cases_by_status"] = {}

    # Cases by priority
    try:
        from app.schemas.common import PriorityLevel
        by_priority = {}
        for p in PriorityLevel:
            r = supabase.table("rescue_cases").select("id", count="exact").eq("priority_level", p.value).execute()
            by_priority[p.value] = r.count or 0
        stats["cases_by_priority"] = by_priority
    except Exception:
        stats["cases_by_priority"] = {}

    # NGO counts
    try:
        approved = supabase.table("ngos").select("id", count="exact").eq("status", "approved").execute()
        pending = supabase.table("ngos").select("id", count="exact").eq("status", "pending").execute()
        stats["approved_ngos"] = approved.count or 0
        stats["pending_ngos"] = pending.count or 0
    except Exception:
        stats["approved_ngos"] = 0
        stats["pending_ngos"] = 0

    # Total users
    try:
        users_resp = supabase.table("profiles").select("id", count="exact").execute()
        stats["total_users"] = users_resp.count or 0
    except Exception:
        stats["total_users"] = 0

    return stats
