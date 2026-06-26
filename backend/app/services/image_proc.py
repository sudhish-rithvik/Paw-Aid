"""
app/services/image_proc.py — OpenCV-based image preprocessing utilities.

All operations are synchronous (CPU-bound) and are expected to be called
from within an executor if used inside an async context.
"""

from __future__ import annotations

import io
import logging

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

MAX_DIMENSION = 1024  # pixels — cap for both width and height


def preprocess_image(image_bytes: bytes) -> bytes:
    """
    Preprocess raw image bytes for optimal AI analysis:
    1. Decode to OpenCV BGR array.
    2. Cap the longest dimension to MAX_DIMENSION (preserve aspect ratio).
    3. Apply CLAHE (Contrast Limited Adaptive Histogram Equalisation) on the
       luminance channel so low-light rescue photos are enhanced.
    4. Re-encode as JPEG bytes.

    Falls back to returning the original bytes on any error.
    """
    try:
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)

        if img is None:
            logger.warning("OpenCV could not decode image; returning original bytes.")
            return image_bytes

        # ── Resize if needed ─────────────────────────────────────────────────
        h, w = img.shape[:2]
        if max(h, w) > MAX_DIMENSION:
            scale = MAX_DIMENSION / max(h, w)
            new_w = int(w * scale)
            new_h = int(h * scale)
            img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
            logger.debug("Resized image from %dx%d to %dx%d", w, h, new_w, new_h)

        # ── CLAHE on luminance channel (YCrCb colour space) ──────────────────
        ycrcb = cv2.cvtColor(img, cv2.COLOR_BGR2YCrCb)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        ycrcb[:, :, 0] = clahe.apply(ycrcb[:, :, 0])
        img = cv2.cvtColor(ycrcb, cv2.COLOR_YCrCb2BGR)

        # ── Encode back to JPEG ───────────────────────────────────────────────
        success, buffer = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        if not success:
            logger.warning("cv2.imencode failed; returning original bytes.")
            return image_bytes

        return buffer.tobytes()

    except Exception as exc:  # noqa: BLE001
        logger.error("preprocess_image error: %s", exc)
        return image_bytes


def compress_image(image_bytes: bytes, quality: int = 85) -> bytes:
    """
    Re-encode *image_bytes* as a JPEG with the given *quality* (1–95).
    Uses Pillow for wider format support (PNG, WebP, BMP, …).
    Falls back to original bytes on error.
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as im:
            # Convert to RGB to drop alpha channel (JPEG doesn't support RGBA)
            if im.mode not in ("RGB", "L"):
                im = im.convert("RGB")

            out = io.BytesIO()
            im.save(out, format="JPEG", quality=quality, optimize=True)
            compressed = out.getvalue()

        logger.debug(
            "Compressed image: %d → %d bytes (quality=%d)",
            len(image_bytes),
            len(compressed),
            quality,
        )
        return compressed

    except Exception as exc:  # noqa: BLE001
        logger.error("compress_image error: %s", exc)
        return image_bytes
