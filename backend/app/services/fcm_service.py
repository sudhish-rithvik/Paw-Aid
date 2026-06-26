"""
app/services/fcm_service.py — Firebase Cloud Messaging (FCM) push notifications.

Initialises the firebase_admin SDK once using a service account JSON file.
Falls back gracefully when credentials are not configured (demo / CI mode).
"""

from __future__ import annotations

import logging
from typing import Any, Dict, Optional

from app.config import get_settings

logger = logging.getLogger(__name__)

_firebase_initialised = False

# Status → emoji mapping for rich notifications
_STATUS_EMOJI: Dict[str, str] = {
    "pending": "🕐",
    "accepted": "✅",
    "dispatched": "🚗",
    "animal_picked": "🐾",
    "vet_treatment": "🏥",
    "recovery": "💚",
    "completed": "🎉",
    "closed": "📁",
}

_STATUS_MESSAGES: Dict[str, str] = {
    "pending": "Your rescue report is being reviewed.",
    "accepted": "A rescue team has accepted the case!",
    "dispatched": "Rescue team is on the way.",
    "animal_picked": "The animal has been picked up.",
    "vet_treatment": "The animal is receiving veterinary treatment.",
    "recovery": "The animal is in recovery.",
    "completed": "Rescue successfully completed! Thank you 🐾",
    "closed": "This rescue case has been closed.",
}


def _init_firebase() -> bool:
    """
    Initialise Firebase Admin SDK once per process.
    Returns True if successfully initialised (or already initialised).
    """
    global _firebase_initialised  # noqa: PLW0603

    if _firebase_initialised:
        return True

    settings = get_settings()

    if not settings.firebase_credentials_path:
        logger.warning(
            "FIREBASE_CREDENTIALS_PATH not set — FCM notifications disabled (demo mode)."
        )
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:  # type: ignore[attr-defined]
            cred = credentials.Certificate(settings.firebase_credentials_path)
            firebase_admin.initialize_app(cred)

        _firebase_initialised = True
        logger.info("Firebase Admin SDK initialised successfully.")
        return True

    except Exception as exc:  # noqa: BLE001
        logger.error("Firebase init error: %s", exc)
        return False


def send_to_token(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> bool:
    """
    Send a push notification to a specific FCM device token.

    Returns True on success, False on failure.
    Stale / unregistered tokens return False; callers should remove them.
    """
    if not _init_firebase():
        logger.debug("FCM send skipped (demo mode): [%s] %s", title, body)
        return True  # Pretend success in demo mode

    try:
        from firebase_admin import messaging

        notification = messaging.Notification(title=title, body=body)
        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                priority="high",
            ),
        )
        apns_config = messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", badge=1),
            )
        )

        message = messaging.Message(
            notification=notification,
            data={str(k): str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=android_config,
            apns=apns_config,
        )

        messaging.send(message)
        logger.info("FCM notification sent to token %s…", fcm_token[:20])
        return True

    except Exception as exc:  # noqa: BLE001
        exc_name = type(exc).__name__
        if "Unregistered" in exc_name or "InvalidRegistration" in exc_name:
            logger.warning("Stale FCM token detected: %s", fcm_token[:20])
            return False
        logger.error("FCM send_to_token error (%s): %s", exc_name, exc)
        return False


def send_case_update(
    fcm_token: str,
    case_id: str,
    new_status: str,
    animal: str = "Animal",
) -> bool:
    """
    Send a rich case-status notification to the reporter.
    """
    emoji = _STATUS_EMOJI.get(new_status, "🔔")
    status_msg = _STATUS_MESSAGES.get(new_status, f"Case status updated to: {new_status}")

    title = f"{emoji} PAW-AID: {animal} Rescue Update"
    body = status_msg

    data: Dict[str, str] = {
        "case_id": case_id,
        "new_status": new_status,
        "animal": animal,
        "type": "case_update",
    }

    return send_to_token(fcm_token, title, body, data)
