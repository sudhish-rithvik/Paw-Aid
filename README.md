# PAW-AID 🐾
### AI-Powered Emergency Response Network for Injured Animals

[![Flutter](https://img.shields.io/badge/Flutter-3.41.4-blue)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-green)](https://fastapi.tiangolo.com)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-darkgreen)](https://supabase.com)
[![HuggingFace](https://img.shields.io/badge/AI-Qwen2.5--VL--7B-yellow)](https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple)](LICENSE)

> **100% Free Stack. Zero Credit Card Required.**

PAW-AID connects citizens, NGOs, volunteers, and veterinarians in one AI-powered rescue ecosystem. When a citizen photographs an injured stray animal, Qwen2.5-VL-7B analyzes the injury, determines severity, and intelligently dispatches the best-suited NGO — all within seconds.

---

## 📱 Three Portals. One App.

| Portal | Users | Key Features |
|--------|-------|-------------|
| 🐾 **Citizen** | Anyone | Guest reporting, real-time tracking, rescue history |
| 🏥 **NGO** | Verified orgs | AI rescue queue, live map, 7-stage mission tracking |
| 🛡️ **Admin** | Superadmin | NGO verification, city heatmap, platform analytics |

---

## 🏗️ Architecture

```
Flutter Android App (Single APK, role-based)
         │
         ▼
FastAPI Backend (Python)
         │
    ┌────┼────────────────┐
    ▼    ▼                ▼
Supabase  HuggingFace   Firebase
(DB+Auth  Qwen2.5-VL    FCM Push
+Storage) Inference API
         │
    ┌────┴────────┐
    ▼             ▼
OpenStreetMap   OSRM/ORS
 flutter_map    Routing+ETA
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.22+ (`flutter --version`)
- Python 3.11+
- Android Studio / Android emulator
- [Supabase](https://supabase.com) account (free)
- [HuggingFace](https://huggingface.co/settings/tokens) token (free)
- [Firebase](https://console.firebase.google.com) project (free)

### 1. Database Setup (Supabase)
1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run `supabase/schema.sql`
3. In **Storage**, create two buckets:
   - `animal-images` (public)
   - `ngo-documents` (private)
   - `rescue-stages` (public)
4. Note your **Project URL** and **Service Role Key** from Settings > API

### 2. Firebase Setup
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app with package name `com.pawaid.paw_aid`
3. Download `google-services.json` → place at `flutter_app/android/app/google-services.json`
4. Enable **Cloud Messaging** in Firebase console
5. Download service account JSON → place at `backend/secrets/firebase-service-account.json`

### 3. Backend Setup
```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate   # Windows
# source venv/bin/activate   # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Configure environment
copy .env.example .env
# Edit .env with your Supabase URL, service key, HF token, etc.

# Create uploads directory
mkdir uploads

# Start backend
uvicorn app.main:app --reload --port 8000
```

Open http://localhost:8000/docs to see the interactive API documentation.

### 4. Flutter App Setup
```bash
cd flutter_app

# Install dependencies
flutter pub get

# Configure Supabase credentials
# Edit lib/core/constants/api_constants.dart:
# - Set supabaseUrl = 'https://your-project.supabase.co'
# - Set supabaseAnonKey = 'your-anon-key'

# Run on Android emulator or device
flutter run
```

---

## 🔑 Required API Keys

| Service | Where to Get | Cost |
|---------|-------------|------|
| Supabase URL + Service Key | supabase.com/dashboard | Free |
| HuggingFace API Token | huggingface.co/settings/tokens | Free |
| Firebase project + FCM | console.firebase.google.com | Free |
| OpenRouteService API key | openrouteservice.org | Free (2000 req/day) |
| Brevo email | app.brevo.com | Free (300 emails/day) |

---

## 🤖 AI Pipeline

1. Citizen uploads animal photo via app
2. FastAPI backend compresses image (OpenCV)
3. Calls **HuggingFace Inference API** with Qwen2.5-VL-7B-Instruct
4. Model returns structured JSON:
   ```json
   {
     "animal": "Dog",
     "visible_injuries": ["Heavy bleeding", "Front leg fracture"],
     "mobility": "Unable to stand",
     "pain_level": "High",
     "severity": "Critical",
     "confidence": 96.4,
     "recommended_action": "Immediate rescue required",
     "reason": "Heavy bleeding with inability to move"
   }
   ```
5. **Priority Engine** computes: Critical / High / Medium / Low
6. **Duplicate Detector** checks GPS + time + image hash
7. **NGO Matcher** scores all approved NGOs (6-factor algorithm)
8. Best NGO gets FCM push notification
9. Citizen sees real-time status updates

**Demo Mode**: Set `DEMO_MODE=true` in `.env` — returns realistic mock AI responses instantly without any API calls.

---

## 🗺️ Maps (100% Free)

| Feature | Technology |
|---------|-----------|
| Interactive map | flutter_map + OpenStreetMap tiles |
| Rescue heatmap | flutter_map_heatmap |
| GPS → Address | Nominatim reverse geocoding |
| Routes + ETA | OSRM (Open Source Routing Machine) |
| Distance matrix | OpenRouteService |

---

## 📊 NGO Recommendation Score

Instead of nearest-NGO-only dispatch, each NGO receives a weighted score:

| Factor | Weight |
|--------|--------|
| Estimated travel time | 35% |
| Current workload | 25% |
| Volunteer availability | 20% |
| Species specialization match | 10% |
| Historical response time | 5% |
| Past rescue success rate | 5% |

---

## 🔄 Rescue Lifecycle

```
PENDING → ACCEPTED → DISPATCHED → ANIMAL PICKED UP
                                        ↓
                                  VET TREATMENT
                                        ↓
                                    RECOVERY
                                        ↓
                                    COMPLETED ❤️
```

Citizen receives FCM push notification at every stage change.

---

## 📁 Project Structure

```
paw-aid/
├── backend/          # FastAPI Python backend
├── flutter_app/      # Flutter Android application
├── supabase/
│   └── schema.sql    # Database schema (run in Supabase SQL editor)
└── README.md
```

---

## 🧪 Seeding Demo Data

```bash
cd backend
python seed_data.py
```

This creates:
- 3 approved NGOs (Chennai area)
- 20 rescue cases in various stages/severities
- 1 admin account (update role in Supabase after creating)
- 5 citizen profiles

---

## 🛠️ Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile | Flutter | 3.41.4 |
| State | Riverpod | 2.x |
| Navigation | go_router | 14.x |
| Backend | FastAPI | 0.115 |
| Database | Supabase PostgreSQL | Latest |
| Auth | Supabase Auth | Latest |
| Storage | Supabase Storage | Latest |
| AI | HuggingFace → Qwen2.5-VL-7B | Latest |
| Maps | flutter_map + OSM | 7.x |
| Notifications | Firebase FCM | Latest |
| Charts | fl_chart | 0.68 |
| Email | Brevo | v3 |

---

## 📄 License

MIT License — free to use, modify, and distribute.

---

*Built for hackathons. Built to save lives. 🐾*
