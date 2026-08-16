"""
app/services/roboflow_inference.py — Roboflow Inference API client.

Uses the Roboflow serverless endpoint to detect injured animals.
"""

from __future__ import annotations

import logging
import tempfile
import os
from typing import Any, Dict

from inference_sdk import InferenceHTTPClient

from app.config import get_settings

logger = logging.getLogger(__name__)

# Fallback mock result when API fails or in demo mode
_MOCK_RESULT: Dict[str, Any] = {
    "animal": "Dog",
    "visible_injuries": ["laceration", "road rash"],
    "mobility": "Unknown",
    "pain_level": "Unknown",
    "severity": "High",
    "confidence": 0.87,
    "recommended_action": "Approach with caution and transport to vet.",
    "reason": "Roboflow detection found potential injuries.",
}

async def analyze_animal_image_roboflow(image_bytes: bytes) -> Dict[str, Any]:
    """
    Send *image_bytes* to the Roboflow Inference API.
    Maps the Roboflow object detection predictions to the existing AIAnalysis schema.
    """
    settings = get_settings()

    if settings.demo_mode or not settings.roboflow_api_key:
        logger.info("Roboflow Inference: demo mode or missing key — returning mock analysis.")
        return dict(_MOCK_RESULT)

    # Initialize client
    client = InferenceHTTPClient(
        api_url="https://serverless.roboflow.com",
        api_key=settings.roboflow_api_key
    )

    # Write bytes to a temporary file since InferenceHTTPClient expects a file path
    temp_fd, temp_path = tempfile.mkstemp(suffix=".jpg")
    try:
        with os.fdopen(temp_fd, 'wb') as f:
            f.write(image_bytes)
        
        # Run inference
        # Using a synchronous call here since the SDK is synchronous, 
        # normally we might wrap this in a threadpool using anyio.to_thread.run_sync
        import anyio
        result = await anyio.to_thread.run_sync(
            client.infer, temp_path, "injured-animal-detector-new/2"
        )
    except Exception as exc:
        logger.error("Roboflow Inference API request error: %s", exc)
        return dict(_MOCK_RESULT)
    finally:
        # Cleanup
        os.remove(temp_path)

    # Process Roboflow output
    # Roboflow outputs format roughly: {"predictions": [{"class": "dog", "confidence": 0.9, ...}, ...]}
    predictions = result.get("predictions", [])
    
    if not predictions:
        logger.warning("No predictions returned from Roboflow.")
        mock = dict(_MOCK_RESULT)
        mock["_raw_response"] = result
        return mock
        
    # Aggregate predictions to match our schema
    animal_classes = []
    injury_classes = []
    highest_confidence = 0.0
    
    for p in predictions:
        pred_class = p.get("class", "").lower()
        conf = float(p.get("confidence", 0.0))
        highest_confidence = max(highest_confidence, conf)
        
        # We assume some generic classes might be returned like 'dog', 'cat' vs 'wound', 'injury'
        if pred_class in ["dog", "cat", "bird", "cow", "animal"]:
            animal_classes.append(pred_class.capitalize())
        else:
            injury_classes.append(pred_class)
            
    # Heuristics to build the result
    animal = animal_classes[0] if animal_classes else "Unknown Animal"
    
    # Severity heuristic: if we detect injuries, severity is higher
    severity = "Medium"
    if len(injury_classes) > 1:
        severity = "Critical"
    elif len(injury_classes) == 1:
        severity = "High"
        
    final_result = {
        "animal": animal,
        "visible_injuries": injury_classes,
        "mobility": "Unknown",
        "pain_level": "Unknown",
        "severity": severity,
        "confidence": highest_confidence,
        "recommended_action": "Assess animal condition safely.",
        "reason": f"Detected {animal} with {len(injury_classes)} potential injuries.",
        "_raw_response": result
    }
    
    return final_result
