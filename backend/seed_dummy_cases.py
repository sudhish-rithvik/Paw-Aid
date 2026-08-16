import asyncio
import io
import json
import random
import sys
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from app.config import get_settings
from app.supabase_client import get_supabase

# Realistic animal images from Unsplash
IMAGE_URLS = [
    "https://images.unsplash.com/photo-1537151608804-ea2f14cb1f3f?w=600&q=80",
    "https://images.unsplash.com/photo-1548681528-6a5c45b66b42?w=600&q=80",
    "https://images.unsplash.com/photo-1518717758536-85ae29035b6d?w=600&q=80",
    "https://images.unsplash.com/photo-1442291928580-fb5d0856a8f1?w=600&q=80",
    "https://images.unsplash.com/photo-1526336024174-e58f5cdd8e13?w=600&q=80",
]

# Chennai-area GPS coordinates
LOCATIONS = [
    (13.0827, 80.2707, "Marina Beach, Chennai"),
    (13.0569, 80.2425, "T Nagar, Chennai"),
    (13.0358, 80.2060, "Guindy, Chennai"),
    (13.1067, 80.2945, "Perambur, Chennai"),
    (12.9762, 80.1959, "Tambaram, Chennai"),
]

def get_image_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        return response.read()

def seed():
    supabase = get_supabase()
    print("Connected to Supabase. Clearing old data...")

    # Fetch citizens and NGOs
    citizens = supabase.table("profiles").select("id").eq("role", "citizen").execute().data
    ngos = supabase.table("ngos").select("id").execute().data

    if not citizens or not ngos:
        print("ERROR: Run seed_data.py first to create citizens and NGOs.")
        sys.exit(1)

    citizen_ids = [c["id"] for c in citizens]
    ngo_ids = [n["id"] for n in ngos]

    # Delete all old rescue cases (and ai_analyses cascade)
    try:
        supabase.table("ai_analyses").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        supabase.table("rescue_cases").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        print("Cleared previous data.")
    except Exception as e:
        print(f"Error clearing data: {e}")

    # Generate 5 cases
    print("Generating 5 dummy cases...")
    for i in range(5):
        case_id = str(uuid.uuid4())
        lat, lng, address = LOCATIONS[i]
        
        # Download image and upload to Supabase storage
        print(f"[{i+1}/5] Downloading image...")
        try:
            image_bytes = get_image_bytes(IMAGE_URLS[i])
            storage_path = f"{case_id}/original.jpg"
            # Attempt to delete first just in case
            supabase.storage.from_("animal-images").remove([storage_path])
            supabase.storage.from_("animal-images").upload(
                path=storage_path,
                file=image_bytes,
                file_options={"content-type": "image/jpeg", "upsert": "true"}
            )
            print(f"[{i+1}/5] Image uploaded to Supabase Storage: {storage_path}")
        except Exception as e:
            print(f"[{i+1}/5] Image upload failed: {e}")
            storage_path = None

        reporter_id = random.choice(citizen_ids)
        assigned_ngo = ngo_ids[i % len(ngo_ids)]
        
        # Mix of statuses
        status = ["pending", "accepted", "dispatched", "vet_treatment", "completed"][i]
        severity = ["critical", "high", "high", "medium", "low"][i]
        priority_map = {"critical": "critical", "high": "high", "medium": "medium", "low": "low"}
        priority = priority_map.get(severity, "medium")
        animal = "Dog" if i in [0, 2] else "Cat"

        case_row = {
            "id": case_id,
            "reporter_id": reporter_id,
            "lat": lat,
            "lng": lng,
            "address": address,
            "notes": f"Found an injured {animal.lower()} near {address}. Needs help!",
            "image_path": storage_path,
            "status": status,
            "priority_level": priority,
            "assigned_ngo_id": assigned_ngo if status != "pending" else None,
            "created_at": (datetime.now(timezone.utc) - timedelta(hours=i*5)).isoformat(),
        }

        try:
            supabase.table("rescue_cases").insert(case_row).execute()
        except Exception as e:
            print(f"[{i+1}/5] Failed to insert case: {e}")
            continue

        ai_row = {
            "id": str(uuid.uuid4()),
            "case_id": case_id,
            "animal": animal,
            "visible_injuries": ["limping", "visible wound"] if severity in ["high", "critical"] else ["minor scratches"],
            "mobility": "Immobile" if severity == "critical" else "Limping",
            "pain_level": "Severe" if severity in ["high", "critical"] else "Mild",
            "severity": severity.capitalize(),
            "confidence": 0.85 + (i * 0.02),
            "recommended_action": "Urgent veterinary attention required." if severity in ["critical", "high"] else "Monitor for 24 hours.",
            "reason": f"AI detected signs of {severity} distress in the {animal.lower()}.",
        }

        try:
            supabase.table("ai_analyses").insert(ai_row).execute()
        except Exception as e:
            print(f"[{i+1}/5] Failed to insert AI analysis: {e}")

        print(f"[{i+1}/5] Successfully created Case {case_id[:8]} ({status}, {priority})")

    print("\n✅ Successfully created 5 showcase cases with images!")

if __name__ == "__main__":
    seed()
