"""
app/mock_db.py — In-memory, persistent resilient database for PAW-AID.
Pre-populated with rich sample data for:
- Citizen (Priya Ramesh)
- NGO Staff (Chennai Animal Rescue Foundation)
- Admin (System Admin)
- 4 NGOs (3 approved, 1 pending)
- Multiple rescue cases in all stages (Pending, Accepted, Dispatched, Vet Treatment, Completed)
- Realistic AI analyses for each case
"""

from __future__ import annotations

import json
import logging
import os
import uuid
from copy import deepcopy
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

MOCK_DB_FILE = Path(__file__).resolve().parent.parent / "mock_data.json"


def _generate_default_seed() -> Dict[str, List[Dict[str, Any]]]:
    now = datetime.now(timezone.utc)
    
    admin_id = "00000000-0000-0000-0000-000000000001"
    ngo_user_id = "00000000-0000-0000-0000-000000000002"
    citizen_id = "00000000-0000-0000-0000-000000000003"
    
    ngo_carf_id = "11111111-1111-1111-1111-111111111111"
    ngo_wildlife_id = "22222222-2222-2222-2222-222222222222"
    ngo_bluecross_id = "33333333-3333-3333-3333-333333333333"
    ngo_pending_id = "44444444-4444-4444-4444-444444444444"

    profiles = [
        {
            "id": admin_id,
            "email": "admin@pawaid.com",
            "role": "admin",
            "display_name": "PAW-AID Administrator",
            "phone": "+919000000001",
            "fcm_token": None,
            "is_suspended": False,
            "created_at": (now - timedelta(days=30)).isoformat(),
        },
        {
            "id": ngo_user_id,
            "email": "ngo@pawaid.com",
            "role": "ngo_staff",
            "display_name": "Chennai Rescue Dispatcher",
            "phone": "+914411223344",
            "fcm_token": None,
            "is_suspended": False,
            "created_at": (now - timedelta(days=25)).isoformat(),
        },
        {
            "id": citizen_id,
            "email": "citizen@pawaid.com",
            "role": "citizen",
            "display_name": "Priya Ramesh (Animal Lover)",
            "phone": "+919876543210",
            "fcm_token": None,
            "is_suspended": False,
            "created_at": (now - timedelta(days=20)).isoformat(),
        },
    ]

    ngos = [
        {
            "id": ngo_carf_id,
            "name": "Chennai Animal Rescue Foundation (CARF)",
            "registration_number": "TN/NGO/2019/001",
            "email": "rescue@carf.org.in",
            "phone": "+914411223344",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "address": "42, Pantheon Road, Egmore, Chennai",
            "specializations": ["Dog", "Cat", "Stray Animals"],
            "status": "approved",
            "avg_response_sec": 900,
            "rescue_success_rate": 0.94,
            "num_vehicles": 4,
            "num_volunteers": 12,
            "service_radius_km": 30.0,
            "operating_hours": "24/7",
            "lat": 13.0827,
            "lng": 80.2707,
            "contact_user_id": ngo_user_id,
            "created_at": (now - timedelta(days=25)).isoformat(),
        },
        {
            "id": ngo_wildlife_id,
            "name": "Wildlife SOS Tamil Nadu",
            "registration_number": "TN/NGO/2020/047",
            "email": "info@wildlifesos-tn.org",
            "phone": "+914422334455",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "address": "15, GST Road, Guindy, Chennai",
            "specializations": ["Wildlife", "Birds", "Reptiles", "Monkey"],
            "status": "approved",
            "avg_response_sec": 1800,
            "rescue_success_rate": 0.88,
            "num_vehicles": 2,
            "num_volunteers": 8,
            "service_radius_km": 50.0,
            "operating_hours": "06:00–22:00",
            "lat": 13.0358,
            "lng": 80.2060,
            "contact_user_id": None,
            "created_at": (now - timedelta(days=20)).isoformat(),
        },
        {
            "id": ngo_bluecross_id,
            "name": "Blue Cross of India – Chennai",
            "registration_number": "TN/NGO/2005/003",
            "email": "bluecross@bluecrossindia.org",
            "phone": "+914444004401",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "address": "Velachery Main Road, Guindy, Chennai",
            "specializations": ["Dog", "Cat", "Cow", "Goat", "All Animals"],
            "status": "approved",
            "avg_response_sec": 600,
            "rescue_success_rate": 0.96,
            "num_vehicles": 6,
            "num_volunteers": 22,
            "service_radius_km": 40.0,
            "operating_hours": "24/7",
            "lat": 13.0675,
            "lng": 80.2374,
            "contact_user_id": None,
            "created_at": (now - timedelta(days=35)).isoformat(),
        },
        {
            "id": ngo_pending_id,
            "name": "Paws & Whiskers Sanctuary",
            "registration_number": "TN/NGO/2026/088",
            "email": "sanctuary@paws-whiskers.org",
            "phone": "+919888877777",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "address": "88, OMR Road, Thoraipakkam, Chennai",
            "specializations": ["Puppy Care", "Kitten Shelter"],
            "status": "pending",
            "avg_response_sec": 1200,
            "rescue_success_rate": 0.85,
            "num_vehicles": 2,
            "num_volunteers": 6,
            "service_radius_km": 20.0,
            "operating_hours": "08:00–20:00",
            "lat": 12.9600,
            "lng": 80.2400,
            "contact_user_id": None,
            "created_at": (now - timedelta(days=2)).isoformat(),
        },
    ]

    volunteers = [
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "profile_id": ngo_user_id,
            "ngo_id": ngo_carf_id,
            "name": "CARF Rescue Team",
            "phone": "+914411223344",
            "is_available": True,
            "lat": 13.0827,
            "lng": 80.2707,
            "created_at": (now - timedelta(days=25)).isoformat(),
        }
    ]

    ngo_documents = [
        {
            "id": str(uuid.uuid4()),
            "ngo_id": ngo_pending_id,
            "doc_type": "registration_cert",
            "storage_path": f"{ngo_pending_id}/reg_cert.pdf",
            "file_name": "Trust_Registration_2026.pdf",
            "verified_by": None,
            "created_at": (now - timedelta(days=2)).isoformat(),
        },
        {
            "id": str(uuid.uuid4()),
            "ngo_id": ngo_pending_id,
            "doc_type": "animal_welfare_license",
            "storage_path": f"{ngo_pending_id}/awbi_license.pdf",
            "file_name": "AWBI_Board_License.pdf",
            "verified_by": None,
            "created_at": (now - timedelta(days=2)).isoformat(),
        },
    ]

    cases_raw = [
        {
            "id": "c1111111-1111-1111-1111-111111111111",
            "lat": 13.0827,
            "lng": 80.2707,
            "address": "Marina Beach Promenade, Chennai",
            "notes": "Indie dog hit by a two-wheeler, front leg heavily bleeding and unable to walk.",
            "status": "pending",
            "priority_level": "critical",
            "reporter_id": citizen_id,
            "assigned_ngo_id": None,
            "created_offset_h": 1,
            "animal": "Dog",
            "injuries": ["Heavy bleeding", "Front leg fracture", "Pavement abrasions"],
            "mobility": "Immobile",
            "pain_level": "High",
            "severity": "Critical",
            "confidence": 0.96,
            "action": "Immediate pressure bandage and urgent transport to nearest trauma center.",
            "reason": "Severe arterial bleed observed with complete loss of weight bearing.",
        },
        {
            "id": "c2222222-2222-2222-2222-222222222222",
            "lat": 13.0569,
            "lng": 80.2425,
            "address": "Pondy Bazaar, T Nagar, Chennai",
            "notes": "Young ginger cat trapped near electric transformer, limping severely.",
            "status": "accepted",
            "priority_level": "high",
            "reporter_id": citizen_id,
            "assigned_ngo_id": ngo_carf_id,
            "created_offset_h": 3,
            "animal": "Cat",
            "injuries": ["Right hind leg trauma", "Minor electrical burn"],
            "mobility": "Limping heavily",
            "pain_level": "Moderate",
            "severity": "High",
            "confidence": 0.91,
            "action": "Safe containment using humane trap and antibiotic wound dressing.",
            "reason": "Limb deformity with potential burn complications.",
        },
        {
            "id": "c3333333-3333-3333-3333-333333333333",
            "lat": 13.0358,
            "lng": 80.2060,
            "address": "Kathipara Junction, Guindy, Chennai",
            "notes": "Spotted eagle grounded on highway median, wing droop detected.",
            "status": "dispatched",
            "priority_level": "high",
            "reporter_id": None,
            "assigned_ngo_id": ngo_wildlife_id,
            "created_offset_h": 5,
            "animal": "Bird",
            "injuries": ["Right wing fracture", "Dehydration"],
            "mobility": "Cannot fly",
            "pain_level": "Moderate",
            "severity": "High",
            "confidence": 0.94,
            "action": "Figure-8 wing wrap and electrolyte hydration.",
            "reason": "Asymmetrical wing posture indicating humeral fracture.",
        },
        {
            "id": "c4444444-4444-4444-4444-444444444444",
            "lat": 13.1067,
            "lng": 80.2945,
            "address": "Perambur High Road, Chennai",
            "notes": "Mother stray dog with 4 newborn pups in flooded drainage ditch.",
            "status": "animal_picked",
            "priority_level": "medium",
            "reporter_id": citizen_id,
            "assigned_ngo_id": ngo_carf_id,
            "created_offset_h": 8,
            "animal": "Dog",
            "injuries": ["Hypothermia", "Mild dehydration"],
            "mobility": "Slow",
            "pain_level": "Low",
            "severity": "Medium",
            "confidence": 0.88,
            "action": "Warm incubator and dry nursing nest relocation.",
            "reason": "Environmental exposure threat to newborns.",
        },
        {
            "id": "c5555555-5555-5555-5555-555555555555",
            "lat": 13.0100,
            "lng": 80.2300,
            "address": "Adyar Gandhi Nagar, Chennai",
            "notes": "Cow injured on foot by plastic debris near market, receiving clinical sutures.",
            "status": "vet_treatment",
            "priority_level": "medium",
            "reporter_id": None,
            "assigned_ngo_id": ngo_bluecross_id,
            "created_offset_h": 14,
            "animal": "Cow",
            "injuries": ["Hoof laceration", "Foreign body puncture"],
            "mobility": "Standing",
            "pain_level": "Low",
            "severity": "Medium",
            "confidence": 0.90,
            "action": "Local anesthesia, foreign object removal, and tetanus toxoid.",
            "reason": "Deep sole cut requiring dressing and protective boot.",
        },
        {
            "id": "c6666666-6666-6666-6666-666666666666",
            "lat": 12.9762,
            "lng": 80.1959,
            "address": "Tambaram Sanatorium, Chennai",
            "notes": "Kitten recovering smoothly from ear mite infection and eye conjunctivitis.",
            "status": "recovery",
            "priority_level": "low",
            "reporter_id": citizen_id,
            "assigned_ngo_id": ngo_carf_id,
            "created_offset_h": 26,
            "animal": "Cat",
            "injuries": ["Severe ear mites", "Corneal clouding"],
            "mobility": "Active",
            "pain_level": "Minimal",
            "severity": "Low",
            "confidence": 0.89,
            "action": "Antiparasitic drops and eye ointment twice daily.",
            "reason": "Parasitic condition resolving under treatment.",
        },
        {
            "id": "c7777777-7777-7777-7777-777777777777",
            "lat": 13.0700,
            "lng": 80.2500,
            "address": "Nungambakkam High Road, Chennai",
            "notes": "Golden indie dog successfully treated for hip dislocation, vaccinated and released.",
            "status": "completed",
            "priority_level": "high",
            "reporter_id": citizen_id,
            "assigned_ngo_id": ngo_bluecross_id,
            "created_offset_h": 48,
            "animal": "Dog",
            "injuries": ["Closed hip luxation", "Bruising"],
            "mobility": "Full recovery",
            "pain_level": "None",
            "severity": "High",
            "confidence": 0.95,
            "action": "Surgical reduction completed. Post-op physiotherapy finished.",
            "reason": "Successful healing verified by veterinary surgeon.",
        },
    ]

    rescue_cases = []
    ai_analyses = []
    rescue_events = []

    for c in cases_raw:
        c_time = (now - timedelta(hours=c["created_offset_h"])).isoformat()
        resolved = (now - timedelta(hours=c["created_offset_h"] - 12)).isoformat() if c["status"] == "completed" else None

        rescue_cases.append({
            "id": c["id"],
            "reporter_id": c["reporter_id"],
            "lat": c["lat"],
            "lng": c["lng"],
            "address": c["address"],
            "notes": c["notes"],
            "image_path": f"{c['id']}/original.jpg",
            "status": c["status"],
            "priority_level": c["priority_level"],
            "assigned_ngo_id": c["assigned_ngo_id"],
            "assigned_volunteer_id": None,
            "is_duplicate": False,
            "original_case_id": None,
            "created_at": c_time,
            "resolved_at": resolved,
            "updated_at": c_time,
        })

        ai_analyses.append({
            "id": str(uuid.uuid4()),
            "case_id": c["id"],
            "animal": c["animal"],
            "visible_injuries": c["injuries"],
            "mobility": c["mobility"],
            "pain_level": c["pain_level"],
            "severity": c["severity"],
            "confidence": c["confidence"],
            "recommended_action": c["action"],
            "reason": c["reason"],
            "raw_response": None,
            "is_demo": True,
            "analyzed_at": c_time,
        })

        rescue_events.append({
            "id": str(uuid.uuid4()),
            "case_id": c["id"],
            "event_type": f"status_changed_to_{c['status']}",
            "actor_id": c["assigned_ngo_id"] or c["reporter_id"],
            "old_status": "pending",
            "new_status": c["status"],
            "metadata": {"initial": True},
            "image_path": None,
            "created_at": c_time,
        })

    return {
        "profiles": profiles,
        "ngos": ngos,
        "volunteers": volunteers,
        "ngo_documents": ngo_documents,
        "rescue_cases": rescue_cases,
        "ai_analyses": ai_analyses,
        "rescue_events": rescue_events,
        "ngo_analytics": [],
    }


class MockDatabase:
    """Thread-safe persistent JSON database mimicking Supabase PostgREST."""

    def __init__(self):
        self.tables: Dict[str, List[Dict[str, Any]]] = {}
        self.load()

    def load(self):
        if MOCK_DB_FILE.exists():
            try:
                with open(MOCK_DB_FILE, "r", encoding="utf-8") as f:
                    self.tables = json.load(f)
                logger.info("Loaded mock DB from %s", MOCK_DB_FILE)
                return
            except Exception as e:
                logger.warning("Failed to load mock DB, reseeding: %s", e)
        self.tables = _generate_default_seed()
        self.save()

    def save(self):
        try:
            with open(MOCK_DB_FILE, "w", encoding="utf-8") as f:
                json.dump(self.tables, f, indent=2, default=str)
        except Exception as e:
            logger.error("Failed to save mock DB: %s", e)

    def get_table(self, name: str) -> List[Dict[str, Any]]:
        if name not in self.tables:
            self.tables[name] = []
        return self.tables[name]


# Global singleton
_mock_db = MockDatabase()


class MockQueryBuilder:
    def __init__(self, db: MockDatabase, table_name: str):
        self.db = db
        self.table_name = table_name
        self.rows = deepcopy(db.get_table(table_name))
        self.count_mode = None
        self._single = False
        self._maybe_single = False
        self._not_in_field = None
        self._not_in_vals = None

    def select(self, columns: str = "*", count: Optional[str] = None):
        self.count_mode = count
        return self

    def eq(self, field: str, value: Any):
        self.rows = [r for r in self.rows if str(r.get(field)) == str(value)]
        return self

    def neq(self, field: str, value: Any):
        self.rows = [r for r in self.rows if str(r.get(field)) != str(value)]
        return self

    def in_(self, field: str, values: List[Any]):
        val_strs = [str(v) for v in values]
        self.rows = [r for r in self.rows if str(r.get(field)) in val_strs]
        return self

    @property
    def not_(self):
        builder = self

        class NotProxy:
            def in_(self, field: str, values: List[Any]):
                val_strs = [str(v) for v in values]
                builder.rows = [r for r in builder.rows if str(r.get(field)) not in val_strs]
                return builder

        return NotProxy()

    def or_(self, expr: str):
        # Format: "assigned_ngo_id.eq.123,status.eq.pending"
        conditions = expr.split(",")
        matched = []
        for r in self.rows:
            match = False
            for cond in conditions:
                parts = cond.strip().split(".")
                if len(parts) == 3 and parts[1] == "eq":
                    f, _, v = parts
                    if str(r.get(f)) == str(v):
                        match = True
                        break
            if match and r not in matched:
                matched.append(r)
        self.rows = matched
        return self

    def order(self, field: str, desc: bool = False):
        self.rows.sort(key=lambda r: r.get(field) or "", reverse=desc)
        return self

    def limit(self, n: int):
        self.rows = self.rows[:n]
        return self

    def range(self, start: int, end: int):
        self.rows = self.rows[start : end + 1]
        return self

    def single(self):
        self._single = True
        return self

    def maybeSingle(self):
        self._maybe_single = True
        return self

    def insert(self, data: Any):
        table = self.db.get_table(self.table_name)
        if isinstance(data, list):
            for item in data:
                if "id" not in item:
                    item["id"] = str(uuid.uuid4())
                table.append(deepcopy(item))
            self.rows = data
        else:
            item = deepcopy(data)
            if "id" not in item:
                item["id"] = str(uuid.uuid4())
            table.append(item)
            self.rows = [item]
        self.db.save()
        return self

    def update(self, data: Dict[str, Any]):
        table = self.db.get_table(self.table_name)
        updated = []
        for r in self.rows:
            for master in table:
                if master.get("id") == r.get("id"):
                    master.update(data)
                    updated.append(master)
        self.rows = updated
        self.db.save()
        return self

    def upsert(self, data: Any, on_conflict: Optional[str] = "id"):
        table = self.db.get_table(self.table_name)
        items = data if isinstance(data, list) else [data]
        key = on_conflict or "id"
        result = []
        for item in items:
            val = item.get(key)
            existing = next((m for m in table if m.get(key) == val), None)
            if existing:
                existing.update(item)
                result.append(existing)
            else:
                table.append(deepcopy(item))
                result.append(item)
        self.rows = result
        self.db.save()
        return self

    def delete(self):
        table = self.db.get_table(self.table_name)
        ids_to_del = {r.get("id") for r in self.rows if r.get("id")}
        self.db.tables[self.table_name] = [m for m in table if m.get("id") not in ids_to_del]
        self.db.save()
        return self

    def execute(self):
        total_count = len(self.rows) if self.count_mode else None
        if self._single:
            data = self.rows[0] if self.rows else None
        elif self._maybe_single:
            data = self.rows[0] if self.rows else None
        else:
            data = self.rows

        class Response:
            def __init__(self, d, c):
                self.data = d
                self.count = c

        return Response(data, total_count)


class MockAuthAdmin:
    def __init__(self, db: MockDatabase):
        self.db = db

    def create_user(self, payload: Dict[str, Any]):
        email = payload.get("email", "")
        uid = str(uuid.uuid4())
        profiles = self.db.get_table("profiles")
        existing = next((p for p in profiles if p.get("email") == email), None)
        if existing:
            raise Exception("Email already registered.")
        p = {
            "id": uid,
            "email": email,
            "role": "citizen",
            "display_name": payload.get("user_metadata", {}).get("display_name", email.split("@")[0]),
            "phone": None,
            "fcm_token": None,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        profiles.append(p)
        self.db.save()

        class UserObj:
            def __init__(self, u_id, u_email):
                self.id = u_id
                self.email = u_email

        class Resp:
            def __init__(self, u):
                self.user = u

        return Resp(UserObj(uid, email))

    def list_users(self):
        profiles = self.db.get_table("profiles")
        class UserObj:
            def __init__(self, u_id, u_email):
                self.id = u_id
                self.email = u_email
        return [UserObj(p["id"], p.get("email")) for p in profiles]

    def update_user_by_id(self, user_id: str, data: Dict[str, Any]):
        profiles = self.db.get_table("profiles")
        for p in profiles:
            if p.get("id") == user_id:
                p.update(data)
                break
        self.db.save()


class MockAuth:
    def __init__(self, db: MockDatabase):
        self.db = db
        self.admin = MockAuthAdmin(db)

    def get_user(self, token: str):
        profiles = self.db.get_table("profiles")
        # Token format: dev-token-<role> or standard token
        if token.startswith("dev-token-"):
            role = token.split("dev-token-")[1]
            target = next((p for p in profiles if p.get("role") == role), profiles[0])
        else:
            target = profiles[0]

        class UserObj:
            def __init__(self, p):
                self.id = p["id"]
                self.email = p.get("email", "user@pawaid.com")

        class Resp:
            def __init__(self, u):
                self.user = u

        return Resp(UserObj(target))

    def sign_in_with_password(self, creds: Dict[str, Any]):
        email = creds.get("email", "").strip().lower()
        profiles = self.db.get_table("profiles")
        p = next((x for x in profiles if (x.get("email") or "").strip().lower() == email), None)
        if not p:
            # Fallback demo auth: Create on the fly
            p = {
                "id": str(uuid.uuid4()),
                "email": email,
                "role": "admin" if "admin" in email else ("ngo_staff" if "ngo" in email else "citizen"),
                "display_name": email.split("@")[0].title(),
                "phone": "+919000000000",
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
            profiles.append(p)
            self.db.save()

        class UserObj:
            def __init__(self, user_p):
                self.id = user_p["id"]
                self.email = user_p["email"]

        class SessionObj:
            def __init__(self, user_p):
                self.access_token = f"dev-token-{user_p.get('role', 'citizen')}"
                self.refresh_token = "mock-refresh-token"
                self.expires_in = 86400

        class Resp:
            def __init__(self, user_p):
                self.user = UserObj(user_p)
                self.session = SessionObj(user_p)

        return Resp(p)


class MockStorageBucket:
    def __init__(self, bucket_name: str):
        self.bucket_name = bucket_name
        self.upload_dir = Path("uploads") / bucket_name
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    def upload(self, path: str, file: Any, file_options: Any = None):
        target = self.upload_dir / path
        target.parent.mkdir(parents=True, exist_ok=True)
        data = file if isinstance(file, (bytes, bytearray)) else file.read()
        target.write_bytes(data)
        return {"Key": path}

    def remove(self, paths: List[str]):
        for p in paths:
            target = self.upload_dir / p
            if target.exists():
                try:
                    target.unlink()
                except Exception:
                    pass
        return {}

    def get_public_url(self, path: str) -> str:
        from app.config import get_settings
        settings = get_settings()
        return f"{settings.backend_url}/uploads/{self.bucket_name}/{path}"


class MockStorage:
    def __init__(self):
        self.buckets: Dict[str, MockStorageBucket] = {}

    def from_(self, bucket_name: str) -> MockStorageBucket:
        if bucket_name not in self.buckets:
            self.buckets[bucket_name] = MockStorageBucket(bucket_name)
        return self.buckets[bucket_name]


class MockSupabaseClient:
    """Drop-in mock for supabase.Client when offline or in DEMO_MODE."""

    def __init__(self):
        self.db = _mock_db
        self.auth = MockAuth(self.db)
        self.storage = MockStorage()

    def table(self, table_name: str) -> MockQueryBuilder:
        return MockQueryBuilder(self.db, table_name)
