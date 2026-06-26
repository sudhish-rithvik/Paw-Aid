"""
app/routers/auth.py — Authentication endpoints.

Relies on Supabase Auth for JWT issuance and verification.
The backend only stores additional profile data in the `profiles` table.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel, EmailStr

from app.supabase_client import get_supabase
from app.schemas.common import UserRole

logger = logging.getLogger(__name__)
router = APIRouter(tags=["auth"])


# ─────────────────────────────────────────────────────────────────────────────
# Request / Response models
# ─────────────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: str
    password: str
    display_name: Optional[str] = None
    phone: Optional[str] = None
    role: UserRole = UserRole.citizen


class LoginRequest(BaseModel):
    email: str
    password: str


class FCMTokenUpdate(BaseModel):
    fcm_token: str


class UserProfileResponse(BaseModel):
    id: str
    email: Optional[str] = None
    role: Optional[str] = None
    display_name: Optional[str] = None
    phone: Optional[str] = None
    fcm_token: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# Dependency: get current authenticated user from Bearer token
# ─────────────────────────────────────────────────────────────────────────────

async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> dict:
    """
    Verify Supabase JWT from Authorization header and return the user dict.
    Raises HTTP 401 if the token is missing or invalid.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split(" ", 1)[1]
    supabase = get_supabase()

    try:
        user_resp = supabase.auth.get_user(token)
        if not user_resp or not user_resp.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token.",
            )
        return {"user": user_resp.user, "token": token}
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        logger.warning("Token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token verification failed.",
        )


async def get_current_user_profile(
    auth_data: dict = Depends(get_current_user),
) -> dict:
    """
    Returns the raw Supabase user object merged with profile table data.
    """
    supabase = get_supabase()
    user = auth_data["user"]
    user_id = user.id

    try:
        profile_resp = (
            supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        )
        profile = profile_resp.data or {}
    except Exception:
        profile = {}

    return {
        "id": user_id,
        "email": user.email,
        "role": profile.get("role", "citizen"),
        "display_name": profile.get("display_name"),
        "phone": profile.get("phone"),
        "fcm_token": profile.get("fcm_token"),
    }


async def require_admin(profile: dict = Depends(get_current_user_profile)) -> dict:
    if profile.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required.",
        )
    return profile


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest):
    """Register a new citizen account."""
    supabase = get_supabase()

    try:
        auth_resp = supabase.auth.admin.create_user(
            {
                "email": body.email,
                "password": body.password,
                "email_confirm": True,  # skip email confirmation for hackathon
            }
        )
        user = auth_resp.user
        if not user:
            raise HTTPException(status_code=400, detail="User creation failed.")

    except Exception as exc:  # noqa: BLE001
        error_msg = str(exc)
        if "already registered" in error_msg or "already exists" in error_msg:
            raise HTTPException(status_code=409, detail="Email already registered.")
        raise HTTPException(status_code=400, detail=f"Registration failed: {error_msg}")

    # Insert profile record
    try:
        supabase.table("profiles").insert(
            {
                "id": user.id,
                "role": body.role.value,
                "display_name": body.display_name or body.email.split("@")[0],
                "phone": body.phone,
            }
        ).execute()
    except Exception as exc:
        logger.error("Profile insert failed for user %s: %s", user.id, exc)

    return {
        "success": True,
        "message": "Account created successfully.",
        "user_id": user.id,
    }


@router.post("/login")
async def login(body: LoginRequest):
    """Sign in with email + password; returns Supabase JWT + user profile."""
    supabase = get_supabase()

    try:
        auth_resp = supabase.auth.sign_in_with_password(
            {"email": body.email, "password": body.password}
        )
        session = auth_resp.session
        user = auth_resp.user

        if not session or not user:
            raise HTTPException(status_code=401, detail="Invalid credentials.")

    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        error_msg = str(exc)
        if "Invalid login credentials" in error_msg or "invalid_credentials" in error_msg:
            raise HTTPException(status_code=401, detail="Invalid email or password.")
        raise HTTPException(status_code=400, detail=f"Login failed: {error_msg}")

    # Fetch profile
    try:
        profile_resp = (
            supabase.table("profiles").select("*").eq("id", user.id).single().execute()
        )
        profile = profile_resp.data or {}
    except Exception:
        profile = {}

    return {
        "success": True,
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "expires_in": session.expires_in,
        "user": {
            "id": user.id,
            "email": user.email,
            "role": profile.get("role", "citizen"),
            "display_name": profile.get("display_name"),
            "phone": profile.get("phone"),
        },
    }


@router.get("/me", response_model=UserProfileResponse)
async def get_me(profile: dict = Depends(get_current_user_profile)):
    """Return the authenticated user's profile."""
    return profile


@router.patch("/me/fcm-token")
async def update_fcm_token(
    body: FCMTokenUpdate,
    profile: dict = Depends(get_current_user_profile),
):
    """Update the FCM device token for push notifications."""
    supabase = get_supabase()
    user_id = profile["id"]

    try:
        supabase.table("profiles").update({"fcm_token": body.fcm_token}).eq("id", user_id).execute()
    except Exception as exc:
        logger.error("FCM token update failed for user %s: %s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to update FCM token.")

    return {"success": True, "message": "FCM token updated."}
