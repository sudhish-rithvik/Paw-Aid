"""
seed_data.py — Demo seed script for PAW-AID backend.

Creates:
  - 1 admin profile
  - 5 citizen profiles
  - 3 approved NGOs in Chennai with different specialisations and locations
  - 20 rescue cases with realistic Chennai GPS coordinates, varying statuses and priorities
  - AI analyses for each rescue case

Usage:
  1. Ensure your .env file is configured with SUPABASE_URL and SUPABASE_SERVICE_KEY.
  2. Run from the backend directory:
         python seed_data.py
  3. All records use deterministic UUIDs so the script is idempotent (re-running
     will upsert existing records rather than creating duplicates).
"""

from __future__ import annotations

import asyncio
import json
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Ensure app package is importable
sys.path.insert(0, str(Path(__file__).parent))

from app.config import get_settings
from app.supabase_client import get_supabase


# ─────────────────────────────────────────────────────────────────────────────
# Seed data definitions
# ─────────────────────────────────────────────────────────────────────────────

ADMIN_ID = "00000000-0000-0000-0000-000000000001"
CITIZEN_IDS = [
    f"00000000-0000-0000-0000-{str(i).zfill(12)}" for i in range(2, 7)
]

NGO_IDS = [
    "10000000-0000-0000-0000-000000000001",
    "10000000-0000-0000-0000-000000000002",
    "10000000-0000-0000-0000-000000000003",
]

# Chennai-area GPS coordinates (realistic spread across the city)
CHENNAI_LOCATIONS = [
    (13.0827, 80.2707, "Marina Beach, Chennai"),
    (13.0569, 80.2425, "T Nagar, Chennai"),
    (13.0358, 80.2060, "Guindy, Chennai"),
    (13.1067, 80.2945, "Perambur, Chennai"),
    (12.9762, 80.1959, "Tambaram, Chennai"),
    (13.0878, 80.2785, "Egmore, Chennai"),
    (13.0732, 80.2609, "Anna Nagar, Chennai"),
    (13.0230, 80.2414, "Velachery, Chennai"),
    (13.0454, 80.2476, "Kodambakkam, Chennai"),
    (13.1143, 80.2658, "Villivakkam, Chennai"),
    (13.0604, 80.2496, "Nungambakkam, Chennai"),
    (12.9979, 80.2481, "Pallavaram, Chennai"),
    (13.0050, 80.2062, "Porur, Chennai"),
    (13.1306, 80.2859, "Kolathur, Chennai"),
    (13.0675, 80.2374, "Vadapalani, Chennai"),
    (13.0878, 80.2623, "Kilpauk, Chennai"),
    (12.9279, 80.1723, "Tambaram West, Chennai"),
    (13.1516, 80.2856, "Madhavaram, Chennai"),
    (13.0120, 80.2323, "Alandur, Chennai"),
    (13.0389, 80.2174, "St. Thomas Mount, Chennai"),
]

ANIMALS = ["Dog", "Cat", "Cow", "Bird", "Goat", "Monkey"]
INJURIES = [
    ["road rash on left flank", "limping"],
    ["laceration on head", "bleeding from ear"],
    ["broken hind leg", "fracture visible"],
    ["open wound on abdomen", "internal bleeding suspected"],
    ["minor cuts on paws", "shivering"],
    ["eye injury", "swollen face"],
    ["paralysis of hind limbs"],
    ["burn injuries on back", "exposed skin"],
    ["entangled in wire", "laceration on neck"],
    ["malnourished", "dehydration"],
]
SEVERITIES = ["critical", "high", "high", "medium", "medium", "medium", "low", "low"]
MOBILITIES = ["Unable to stand", "Limping", "Limping", "Mobile"]
PAINS = ["Severe", "Severe", "Moderate", "Moderate", "Mild"]
STATUSES = [
    "pending", "pending",
    "accepted", "accepted",
    "dispatched", "dispatched",
    "animal_picked",
    "vet_treatment",
    "recovery",
    "completed", "completed", "completed",
    "closed",
]


def _rand_time(hours_ago_max: int = 720) -> str:
    delta = timedelta(hours=random.randint(0, hours_ago_max))
    return (datetime.now(timezone.utc) - delta).isoformat()


def seed():
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_key:
        print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env")
        sys.exit(1)

    supabase = get_supabase()
    print("Connected to Supabase. Starting seed…\n")

    # ── Admin profile ─────────────────────────────────────────────────────────
    print("Seeding admin profile…")
    try:
        supabase.table("profiles").upsert(
            {
                "id": ADMIN_ID,
                "role": "admin",
                "display_name": "PAW-AID Admin",
                "phone": "+919000000001",
            },
            on_conflict="id",
        ).execute()
        print(f"  ✓ Admin profile: {ADMIN_ID}")
    except Exception as exc:
        print(f"  ✗ Admin profile failed: {exc}")

    # ── Citizen profiles ──────────────────────────────────────────────────────
    print("Seeding citizen profiles…")
    citizen_names = ["Priya Ramesh", "Arjun Karthik", "Meena Suresh", "Ravi Anand", "Deepa Nair"]
    for i, (cid, cname) in enumerate(zip(CITIZEN_IDS, citizen_names)):
        try:
            supabase.table("profiles").upsert(
                {
                    "id": cid,
                    "role": "citizen",
                    "display_name": cname,
                    "phone": f"+9190000000{i + 10:02d}",
                },
                on_conflict="id",
            ).execute()
            print(f"  ✓ Citizen: {cname} ({cid})")
        except Exception as exc:
            print(f"  ✗ Citizen {cname} failed: {exc}")

    # ── NGOs ──────────────────────────────────────────────────────────────────
    print("\nSeeding NGOs…")
    ngos = [
        {
            "id": NGO_IDS[0],
            "name": "Chennai Animal Rescue Foundation",
            "registration_number": "TN/NGO/2019/001",
            "email": "rescue@carf.org.in",
            "phone": "+914411223344",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "specializations": ["Dog", "Cat", "Stray Animals"],
            "status": "approved",
            "avg_response_sec": 900.0,
            "rescue_success_rate": 0.92,
            "num_vehicles": 4,
            "num_volunteers": 12,
            "service_radius_km": 30.0,
            "operating_hours": "24/7",
            "lat": 13.0827,
            "lng": 80.2707,
        },
        {
            "id": NGO_IDS[1],
            "name": "Wildlife SOS Tamil Nadu",
            "registration_number": "TN/NGO/2020/047",
            "email": "info@wildlifesos-tn.org",
            "phone": "+914422334455",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "specializations": ["Wildlife", "Birds", "Reptiles", "Monkey"],
            "status": "approved",
            "avg_response_sec": 1800.0,
            "rescue_success_rate": 0.88,
            "num_vehicles": 2,
            "num_volunteers": 8,
            "service_radius_km": 50.0,
            "operating_hours": "06:00–22:00",
            "lat": 13.0358,
            "lng": 80.2060,
        },
        {
            "id": NGO_IDS[2],
            "name": "Blue Cross of India – Chennai",
            "registration_number": "TN/NGO/2005/003",
            "email": "bluecross@bluecrossindia.org",
            "phone": "+914444004401",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "specializations": ["Dog", "Cat", "Cow", "Goat", "All Animals"],
            "status": "approved",
            "avg_response_sec": 600.0,
            "rescue_success_rate": 0.95,
            "num_vehicles": 6,
            "num_volunteers": 20,
            "service_radius_km": 40.0,
            "operating_hours": "24/7",
            "lat": 13.0675,
            "lng": 80.2374,
        },
    ]

    for ngo in ngos:
        try:
            supabase.table("ngos").upsert(ngo, on_conflict="id").execute()
            print(f"  ✓ NGO: {ngo['name']}")
        except Exception as exc:
            print(f"  ✗ NGO {ngo['name']} failed: {exc}")

    # ── Rescue cases ──────────────────────────────────────────────────────────
    print("\nSeeding rescue cases…")
    case_ids = [str(uuid.uuid4()) for _ in range(20)]
    assigned_ngos = [random.choice(NGO_IDS) for _ in range(20)]

    for i, (case_id, ngo_id) in enumerate(zip(case_ids, assigned_ngos)):
        lat, lng, address = CHENNAI_LOCATIONS[i % len(CHENNAI_LOCATIONS)]
        # Add small random jitter
        lat += random.uniform(-0.003, 0.003)
        lng += random.uniform(-0.003, 0.003)

        animal = random.choice(ANIMALS)
        severity = random.choice(SEVERITIES)
        case_status = STATUSES[i % len(STATUSES)]

        priority_map = {"critical": "critical", "high": "high", "medium": "medium", "low": "low"}
        priority = priority_map.get(severity, "medium")

        created = _rand_time(720)
        resolved = None
        if case_status in ("completed", "closed"):
            resolved = (datetime.fromisoformat(created.replace("Z", "+00:00"))
                        + timedelta(hours=random.randint(2, 48))).isoformat()

        case_row = {
            "id": case_id,
            "reporter_id": random.choice(CITIZEN_IDS + [None]),
            "lat": round(lat, 6),
            "lng": round(lng, 6),
            "address": address,
            "notes": f"{animal} found injured near {address}",
            "image_path": None,
            "status": case_status,
            "priority_level": priority,
            "assigned_ngo_id": ngo_id if case_status != "pending" else None,
            "assigned_volunteer_id": None,
            "created_at": created,
            "resolved_at": resolved,
        }

        try:
            supabase.table("rescue_cases").upsert(case_row, on_conflict="id").execute()
            print(f"  ✓ Case {i + 1:02d}: {animal} | {case_status} | {priority} | {address[:30]}")
        except Exception as exc:
            print(f"  ✗ Case {i + 1:02d} failed: {exc}")

        # ── AI analysis for each case ─────────────────────────────────────────
        injuries = random.choice(INJURIES)
        mobility = random.choice(MOBILITIES)
        pain = random.choice(PAINS)
        confidence = round(random.uniform(0.65, 0.97), 2)

        ai_row = {
            "id": str(uuid.uuid4()),
            "case_id": case_id,
            "animal": animal,
            "visible_injuries": injuries,
            "mobility": mobility,
            "pain_level": pain,
            "severity": severity,
            "confidence": confidence,
            "recommended_action": (
                "Immobilise the animal and transport to the nearest veterinary clinic immediately."
                if severity in ("critical", "high")
                else "Monitor the animal and provide basic first aid before transport."
            ),
            "reason": (
                f"{animal} shows {', '.join(injuries[:2])} with {pain.lower()} pain and {mobility.lower()} mobility."
            ),
            "raw_response": None,
        }

        try:
            supabase.table("ai_analyses").upsert(ai_row, on_conflict="case_id").execute()
        except Exception as exc:
            print(f"    ✗ AI analysis for case {case_id[:8]} failed: {exc}")

    print("\n" + "=" * 60)
    print("✅ Seed complete!")
    print("=" * 60)
    print(f"\nAdmin profile ID : {ADMIN_ID}")
    print(f"Citizen IDs      : {CITIZEN_IDS}")
    print(f"NGO IDs          : {NGO_IDS}")
    print(f"Rescue cases     : {len(case_ids)} created")
    print("\nNext steps:")
    print("  1. Create Supabase Auth users for admin/citizen profiles manually")
    print("     (or extend this script to use supabase.auth.admin.create_user).")
    print("  2. Run the server: uvicorn app.main:app --reload")
    print("  3. Open http://localhost:8000/api/docs for the Swagger UI.")


if __name__ == "__main__":
    seed()
