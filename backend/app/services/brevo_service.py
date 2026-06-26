"""
app/services/brevo_service.py — Transactional email via Brevo (formerly Sendinblue).

Uses httpx to POST directly to the Brevo v3 API (/smtp/email) to avoid
SDK version conflicts.  Falls back to a no-op log when BREVO_API_KEY is absent.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, Optional

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

BREVO_SMTP_URL = "https://api.brevo.com/v3/smtp/email"
TIMEOUT = 15.0


async def _send_email(
    to_email: str,
    to_name: str,
    subject: str,
    html_content: str,
) -> bool:
    """
    Internal helper: POST a single transactional email via Brevo.
    Returns True on HTTP 2xx, False otherwise.
    If BREVO_API_KEY is not set, logs and returns True (demo mode).
    """
    settings = get_settings()

    if not settings.brevo_api_key:
        logger.info(
            "[DEMO] Email skipped (no BREVO_API_KEY). To=%s | Subject=%s",
            to_email,
            subject,
        )
        return True

    payload: Dict[str, Any] = {
        "sender": {"name": "PAW-AID Platform", "email": settings.brevo_from_email},
        "to": [{"email": to_email, "name": to_name}],
        "subject": subject,
        "htmlContent": html_content,
    }

    headers = {
        "api-key": settings.brevo_api_key,
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.post(BREVO_SMTP_URL, json=payload, headers=headers)
            resp.raise_for_status()
            logger.info("Brevo email sent to %s (subject: %s)", to_email, subject)
            return True

    except httpx.HTTPStatusError as exc:
        logger.error(
            "Brevo HTTP error %s: %s",
            exc.response.status_code,
            exc.response.text[:300],
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Brevo send error: %s", exc)

    return False


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

async def send_ngo_approval_email(ngo_email: str, ngo_name: str) -> bool:
    subject = "🎉 Your NGO has been approved on PAW-AID!"
    html = f"""
    <html><body style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto;">
      <h2 style="color: #2e7d32;">Congratulations, {ngo_name}! 🐾</h2>
      <p>Your organisation has been <strong>approved</strong> on the PAW-AID platform.</p>
      <p>You can now:</p>
      <ul>
        <li>Receive and respond to animal rescue cases in your area.</li>
        <li>Manage your volunteer team via the PAW-AID NGO dashboard.</li>
        <li>Track real-time rescue analytics.</li>
      </ul>
      <p>Log in at <a href="https://paw-aid.app">paw-aid.app</a> to get started.</p>
      <hr/>
      <p style="color: #888; font-size: 12px;">PAW-AID — AI-powered animal emergency rescue platform</p>
    </body></html>
    """
    return await _send_email(ngo_email, ngo_name, subject, html)


async def send_ngo_rejection_email(ngo_email: str, ngo_name: str, reason: str) -> bool:
    subject = "PAW-AID — NGO Registration Update"
    html = f"""
    <html><body style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto;">
      <h2 style="color: #c62828;">Registration Decision for {ngo_name}</h2>
      <p>Thank you for registering on PAW-AID.  After reviewing your application,
      we were unable to approve your registration at this time.</p>
      <p><strong>Reason:</strong></p>
      <blockquote style="border-left: 4px solid #e53935; padding-left: 12px; color: #555;">
        {reason}
      </blockquote>
      <p>If you believe this is an error or have additional documentation, please
      contact us at <a href="mailto:admin@paw-aid.app">admin@paw-aid.app</a>.</p>
      <hr/>
      <p style="color: #888; font-size: 12px;">PAW-AID — AI-powered animal emergency rescue platform</p>
    </body></html>
    """
    return await _send_email(ngo_email, ngo_name, subject, html)


async def send_ngo_verification_pending(ngo_email: str, ngo_name: str) -> bool:
    subject = "PAW-AID — We received your NGO registration 🐾"
    html = f"""
    <html><body style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto;">
      <h2 style="color: #1565c0;">Thank you for registering, {ngo_name}!</h2>
      <p>We have received your NGO registration and documents.
      Our team will review your application within <strong>2–3 business days</strong>.</p>
      <p>You will receive an email as soon as a decision has been made.</p>
      <p>In the meantime, if you have questions reach us at
      <a href="mailto:admin@paw-aid.app">admin@paw-aid.app</a>.</p>
      <hr/>
      <p style="color: #888; font-size: 12px;">PAW-AID — AI-powered animal emergency rescue platform</p>
    </body></html>
    """
    return await _send_email(ngo_email, ngo_name, subject, html)
