"""
app/services/priority_engine.py — Emergency priority scoring engine.

Computes a 0–100 composite score from the AI analysis result and maps it
to one of four PriorityLevel buckets: critical / high / medium / low.
"""

from __future__ import annotations

import logging
from typing import Any, Dict

from app.schemas.common import PriorityLevel

logger = logging.getLogger(__name__)

# Keywords in visible_injuries that indicate life-threatening injuries
CRITICAL_INJURY_KEYWORDS = {
    "bleeding",
    "blood",
    "haemorrhage",
    "hemorrhage",
    "fracture",
    "broken bone",
    "compound fracture",
    "open wound",
    "organ",
    "exposed",
    "severed",
    "paralysis",
    "paralysed",
    "paralyzed",
    "unconscious",
    "unresponsive",
    "internal bleeding",
}

# Severity → numeric weight
_SEVERITY_WEIGHTS: Dict[str, float] = {
    "critical": 1.0,
    "high": 0.75,
    "medium": 0.50,
    "low": 0.25,
}

# Mobility → numeric weight
_MOBILITY_WEIGHTS: Dict[str, float] = {
    "unable to stand": 1.0,
    "limping": 0.5,
    "mobile": 0.0,
    "unknown": 0.3,
}

# Pain level → numeric weight
_PAIN_WEIGHTS: Dict[str, float] = {
    "severe": 1.0,
    "moderate": 0.6,
    "mild": 0.3,
    "none": 0.0,
}


def compute_priority(ai_result: Dict[str, Any]) -> PriorityLevel:
    """
    Compute a priority level from the AI analysis result dict.

    Weighted scoring components (total = 100 pts):
    ─────────────────────────────────────────────────────────────────────────
    Component              Weight   Range
    ─────────────────────────────────────────────────────────────────────────
    Severity               30 %     0–30
    Critical injury kws    25 %     0–25  (proportional to matched keywords)
    Mobility               20 %     0–20
    Pain level             15 %     0–15
    Confidence factor      10 %     0–10
    ─────────────────────────────────────────────────────────────────────────

    Thresholds:
        score ≥ 85  → critical
        score ≥ 65  → high
        score ≥ 40  → medium
        else        → low
    """
    try:
        severity_raw = str(ai_result.get("severity", "medium")).lower()
        mobility_raw = str(ai_result.get("mobility", "unknown")).lower()
        pain_raw = str(ai_result.get("pain_level", "moderate")).lower()
        confidence = float(ai_result.get("confidence", 0.5))
        injuries: list = ai_result.get("visible_injuries", [])
        injury_text = " ".join(str(i).lower() for i in injuries)

        # ── Severity component (0–30) ─────────────────────────────────────
        sev_score = _SEVERITY_WEIGHTS.get(severity_raw, 0.5) * 30

        # ── Critical injury keywords component (0–25) ─────────────────────
        matched = sum(1 for kw in CRITICAL_INJURY_KEYWORDS if kw in injury_text)
        # Cap at 3 matches for full score; each match = 8.33 pts
        injury_score = min(matched / 3, 1.0) * 25

        # ── Mobility component (0–20) ─────────────────────────────────────
        mob_score = _MOBILITY_WEIGHTS.get(mobility_raw, 0.3) * 20

        # ── Pain component (0–15) ─────────────────────────────────────────
        pain_score = _PAIN_WEIGHTS.get(pain_raw, 0.6) * 15

        # ── Confidence factor (0–10) ──────────────────────────────────────
        # High confidence amplifies the score; low confidence reduces it.
        conf_score = min(confidence, 1.0) * 10

        total = sev_score + injury_score + mob_score + pain_score + conf_score

        logger.debug(
            "Priority score: sev=%.1f inj=%.1f mob=%.1f pain=%.1f conf=%.1f → total=%.1f",
            sev_score,
            injury_score,
            mob_score,
            pain_score,
            conf_score,
            total,
        )

        if total >= 85:
            return PriorityLevel.critical
        elif total >= 65:
            return PriorityLevel.high
        elif total >= 40:
            return PriorityLevel.medium
        else:
            return PriorityLevel.low

    except Exception as exc:  # noqa: BLE001
        logger.error("compute_priority error: %s — defaulting to high", exc)
        return PriorityLevel.high
