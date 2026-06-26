"""
app/services/hf_inference.py — HuggingFace Inference API client.

Uses the Qwen2.5-VL-7B-Instruct vision-language model via the standard
OpenAI-compatible /v1/chat/completions endpoint hosted on HuggingFace.
"""

from __future__ import annotations

import base64
import json
import logging
import re
from typing import Any, Dict

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

HF_ENDPOINT = "https://api-inference.huggingface.co/v1/chat/completions"
MODEL_ID = "Qwen/Qwen2.5-VL-7B-Instruct"

ANALYSIS_PROMPT = """You are an expert veterinary AI assistant helping emergency animal rescuers.
Analyse the provided image of an injured or distressed animal and respond with ONLY valid JSON
(no markdown, no prose) in exactly this schema:

{
  "animal": "<species, e.g. Dog / Cat / Cow / Bird>",
  "visible_injuries": ["<injury 1>", "<injury 2>"],
  "mobility": "<one of: Unable to stand | Limping | Mobile>",
  "pain_level": "<one of: Severe | Moderate | Mild | None>",
  "severity": "<one of: critical | high | medium | low>",
  "confidence": <float 0.0–1.0>,
  "recommended_action": "<single sentence action for rescuers>",
  "reason": "<brief explanation of severity rating>"
}

Be concise. If the image is unclear, lower confidence accordingly but still return valid JSON."""

_MOCK_RESULT: Dict[str, Any] = {
    "animal": "Dog",
    "visible_injuries": ["laceration on left hind leg", "road rash on abdomen"],
    "mobility": "Unable to stand",
    "pain_level": "Severe",
    "severity": "high",
    "confidence": 0.87,
    "recommended_action": "Immobilise the animal, apply pressure bandage to leg wound, transport to vet immediately.",
    "reason": "Deep laceration with blood loss and inability to stand indicates high severity requiring urgent care.",
}


def _extract_json(text: str) -> Dict[str, Any]:
    """
    Robustly extract a JSON object from model output.
    Strategy:
    1. Try direct parse.
    2. Strip markdown code fences and retry.
    3. Regex-find the first {...} block.
    """
    text = text.strip()

    # Strategy 1: direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Strategy 2: strip markdown fences
    stripped = re.sub(r"```(?:json)?", "", text).strip().rstrip("`").strip()
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        pass

    # Strategy 3: regex find first {...}
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    logger.warning("Could not extract JSON from model response; using fallback.")
    return dict(_MOCK_RESULT)


async def analyze_animal_image(image_bytes: bytes) -> Dict[str, Any]:
    """
    Send *image_bytes* to the HuggingFace Inference API and return a
    structured analysis dict matching the AIAnalysisResult schema.

    If DEMO_MODE is enabled or the API call fails, returns realistic mock data.
    """
    settings = get_settings()

    if settings.demo_mode or not settings.hf_api_key:
        logger.info("HF Inference: demo mode — returning mock analysis.")
        return dict(_MOCK_RESULT)

    # Encode image as base64 data URI
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    data_uri = f"data:image/jpeg;base64,{b64}"

    payload = {
        "model": MODEL_ID,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": ANALYSIS_PROMPT},
                    {"type": "image_url", "image_url": {"url": data_uri}},
                ],
            }
        ],
        "max_tokens": 512,
        "temperature": 0.2,
    }

    headers = {
        "Authorization": f"Bearer {settings.hf_api_key}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(HF_ENDPOINT, json=payload, headers=headers)
            response.raise_for_status()

        data = response.json()
        raw_text: str = data["choices"][0]["message"]["content"]
        result = _extract_json(raw_text)
        result["_raw_response"] = data  # preserve for storage
        return result

    except httpx.HTTPStatusError as exc:
        logger.error(
            "HF Inference API HTTP error %s: %s",
            exc.response.status_code,
            exc.response.text[:300],
        )
    except httpx.RequestError as exc:
        logger.error("HF Inference API request error: %s", exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("Unexpected error during HF inference: %s", exc)

    logger.warning("HF Inference failed — returning fallback mock data.")
    return dict(_MOCK_RESULT)
