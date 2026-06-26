"""
app/schemas/common.py — Shared Pydantic models and enumerations used across
multiple routers and services in the PAW-AID backend.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


# ─────────────────────────────────────────────────────────────────────────────
# Enumerations
# ─────────────────────────────────────────────────────────────────────────────

class CaseStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    dispatched = "dispatched"
    animal_picked = "animal_picked"
    vet_treatment = "vet_treatment"
    recovery = "recovery"
    completed = "completed"
    closed = "closed"


# Legal forward transitions for each status
STATUS_TRANSITIONS: Dict[CaseStatus, List[CaseStatus]] = {
    CaseStatus.pending: [CaseStatus.accepted, CaseStatus.closed],
    CaseStatus.accepted: [CaseStatus.dispatched, CaseStatus.closed],
    CaseStatus.dispatched: [CaseStatus.animal_picked, CaseStatus.closed],
    CaseStatus.animal_picked: [CaseStatus.vet_treatment, CaseStatus.completed],
    CaseStatus.vet_treatment: [CaseStatus.recovery, CaseStatus.completed],
    CaseStatus.recovery: [CaseStatus.completed],
    CaseStatus.completed: [CaseStatus.closed],
    CaseStatus.closed: [],
}


class PriorityLevel(str, Enum):
    critical = "critical"
    high = "high"
    medium = "medium"
    low = "low"


class NGOStatus(str, Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"
    suspended = "suspended"


class UserRole(str, Enum):
    citizen = "citizen"
    ngo_staff = "ngo_staff"
    admin = "admin"


# ─────────────────────────────────────────────────────────────────────────────
# AI Analysis
# ─────────────────────────────────────────────────────────────────────────────

class AIAnalysisResult(BaseModel):
    animal: str = Field(..., description="Species of animal (e.g. Dog, Cat, Cow)")
    visible_injuries: List[str] = Field(default_factory=list, description="List of observed injuries")
    mobility: str = Field(..., description="Mobility status: Unable to stand / Limping / Mobile")
    pain_level: str = Field(..., description="Estimated pain: Severe / Moderate / Mild / None")
    severity: str = Field(..., description="Overall severity: critical / high / medium / low")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Model confidence 0-1")
    recommended_action: str = Field(..., description="Short recommended action for rescuers")
    reason: str = Field(..., description="Brief reasoning for the severity assessment")

    @field_validator("severity")
    @classmethod
    def validate_severity(cls, v: str) -> str:
        allowed = {"critical", "high", "medium", "low"}
        if v.lower() not in allowed:
            return "medium"
        return v.lower()

    @field_validator("mobility")
    @classmethod
    def validate_mobility(cls, v: str) -> str:
        allowed = {"unable to stand", "limping", "mobile", "unknown"}
        if v.lower() not in allowed:
            return "unknown"
        return v


# ─────────────────────────────────────────────────────────────────────────────
# Rescue Case
# ─────────────────────────────────────────────────────────────────────────────

class RescueCaseResponse(BaseModel):
    id: str
    reporter_id: Optional[str] = None
    lat: float
    lng: float
    address: Optional[str] = None
    notes: Optional[str] = None
    image_path: Optional[str] = None
    status: CaseStatus
    priority_level: Optional[PriorityLevel] = None
    assigned_ngo_id: Optional[str] = None
    assigned_volunteer_id: Optional[str] = None
    created_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    ai_analysis: Optional[AIAnalysisResult] = None

    model_config = {"from_attributes": True}


# ─────────────────────────────────────────────────────────────────────────────
# NGO
# ─────────────────────────────────────────────────────────────────────────────

class NGOResponse(BaseModel):
    id: str
    name: str
    registration_number: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    specializations: Optional[List[str]] = None
    status: NGOStatus
    avg_response_sec: Optional[float] = None
    rescue_success_rate: Optional[float] = None
    num_vehicles: Optional[int] = None
    num_volunteers: Optional[int] = None
    service_radius_km: Optional[float] = None
    operating_hours: Optional[str] = None

    model_config = {"from_attributes": True}


# ─────────────────────────────────────────────────────────────────────────────
# Generic API responses
# ─────────────────────────────────────────────────────────────────────────────

class SuccessResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    data: Optional[Any] = None


class ErrorResponse(BaseModel):
    success: bool = False
    message: str
    detail: Optional[Any] = None
