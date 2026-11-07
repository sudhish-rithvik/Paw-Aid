# PAW-AID 🐾
### AI-Powered Emergency Response Network for Injured Animals

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Firebase Spark](https://img.shields.io/badge/Firebase-Spark%20($0.00)-orange.svg)](https://firebase.google.com)
[![Cloud Firestore](https://img.shields.io/badge/Database-Cloud%20Firestore-yellow.svg)](https://firebase.google.com/docs/firestore)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

> **Emergency Animal Rescue Platform — Three Roles, One Cohesive Ecosystem.**
> Fully migrated to **Firebase Spark** (Strictly Zero Cloud Billing / $0.00 per month).

PAW-AID connects citizens, NGOs, volunteers, and veterinarians into a single real-time rescue network. When a citizen encounters an injured stray animal, the application performs on-device vision triage, determines clinical urgency, and dispatches the nearest approved rescue team.

---

## 📱 Three Portals. One App.

| Portal | Intended Users | Core Features | Access Control |
|---|---|---|---|
| 🐾 **Citizen** | Public Users | Emergency distress reporting, GPS capture, on-device photo persistence, reactive rescue tracking, notification feed | Defaults to `role: citizen`, `accountStatus: active` |
| 🏥 **NGO** | Verified Rescue Organizations | Live emergency queue, mission acceptance with ETA, 7-stage rescue progression, organizational profile maintenance | Registration defaults to `pending`; access gated by Admin approval |
| 🛡️ **Admin** | Platform Superadmins | Review all reports, verify/approve NGO applications, manual dispatch & assignment, paginated monitoring | Provisioned manually through administrative credentials |

---

## 🏗️ Architecture Overview

The system runs entirely within **Firebase Spark** ($0.00 / month) with zero paid cloud services:

```
Flutter Android Application (com.pawaid.paw_aid)
 ├── Authentication: Firebase Authentication (Email/Password & Sessions)
 ├── Database: Cloud Firestore (Real-Time Streams & Offline Persistence)
 ├── Push Notifications: Firebase Cloud Messaging (FCM Token Registration)
 ├── Vision Triage: Local On-Device Inference (LiteRT / TensorFlow Lite Abstraction)
 ├── Photo Persistence: Local File Storage (LocalPhotoStorageRepository)
 └── Maps & Navigation: flutter_map + OpenStreetMap + OSRM Routing
```

### Free-Tier Spark Constraints Enforced
1. **Zero Firebase Storage:** Firebase Storage buckets require a Blaze billing account. All incident photos are stored in local sandbox storage on the device, with lightweight reference metadata in Cloud Firestore.
2. **Zero Base64 in Cloud Documents:** Documents store only metadata, avoiding Firestore's 1 MiB document ceiling and preserving the 1 GiB free storage quota.
3. **No Cloud Functions / Cloud Run:** All business logic, reactive status monitoring, and validation rules run on-device and in declarative Firestore Security Rules (`firestore.rules`).
4. **Aggressive Cache & Pagination:** Query pagination (default: 20 items) and a 100 MB offline cache protect the free tier daily quota of 50,000 document reads.

---

## 🗄️ Database Schema & Collections

| Collection Path | Document Key | Primary Responsibility |
|---|---|---|
| `users/{userId}` | Firebase Auth `uid` | User profile, role, approval status, contact info, FCM push token |
| `reports/{reportId}` | Report UUID | Distress reports, animal type, coordinates, injury category, severity, assigned NGO |
| `reports/{reportId}/status_history/{historyId}` | History UUID | **Append-only** chronological audit trail for animal recovery |
| `ngos/{ngoId}` | NGO UID | Registered rescue organizations, contact information, service radius, capacity |
| `assignments/{assignmentId}` | Assignment UUID | Dispatch mission queue, acceptance status, responder ETA, rejection logs |
| `notifications/{notificationId}` | Notification UUID | User-isolated notifications and incident alerts |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** 3.22+ (`flutter --version`)
- **Android SDK:** API 24+ (Android 7.0+)
- **Firebase Project:** Created on [Firebase Console](https://console.firebase.google.com) on the **Spark ($0.00)** free tier.

### 1. Firebase Project Setup
1. Create a Firebase project in the Firebase Console (ensure the plan is set to **Spark**).
2. Register an Android app with package name:
   ```
   com.pawaid.paw_aid
   ```
3. Download `google-services.json` and place it at:
   ```
   flutter_app/android/app/google-services.json
   ```
4. Enable **Email/Password** authentication under *Firebase Console → Authentication → Sign-in method*.
5. Create a Cloud Firestore database in **production mode**.

### 2. Deploy Firestore Security Rules
Deploy the security rules from the repository root using the Firebase CLI:
```bash
# Login to Firebase
firebase login

# Set active project
firebase use <YOUR_FIREBASE_PROJECT_ID>

# Deploy security rules
firebase deploy --only firestore:rules
```

### 3. Build & Run the Flutter Application
```bash
cd flutter_app

# Install dependencies
flutter pub get

# Run test suite (29 tests)
flutter test

# Run static analysis
flutter analyze

# Build debug APK
flutter build apk --debug

# Run on connected device or emulator
flutter run
```

---

## 🔒 Security & Firestore Rules

The production security rules are defined in [`firestore.rules`](file:///d:/Projects/Paw-Aid/firestore.rules):
- **Role Elevation Prevention:** Untrusted users cannot register as `admin` or modify their own `role` / `accountStatus`.
- **NGO Gating:** Only NGOs approved by an administrator can view and accept unassigned emergency cases.
- **Append-Only Timeline:** Rescue progression events in `status_history` cannot be edited or deleted (`allow update: if false;`), ensuring tamper-proof audit trails.
- **Default Deny:** All unmatched collections and documents are denied by default.

---

## 🧠 On-Device AI Vision Triage

PAW-AID includes an on-device AI vision triage pipeline designed for **LiteRT** (formerly TensorFlow Lite):
- **Detection & Species:** Detects Dog, Cat, Cattle, Bird, Equine, and other common urban animals.
- **Visible Injury Multi-Label:** Identifies limb fractures, lacerations, burns, and vehicular trauma.
- **Preliminary Urgency:** Computes an urgency rating (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`).
- **Safety Disclaimer:** Explicitly labeled as preliminary emergency dispatch triage, **never** veterinary diagnosis.
- **Offline Fallback:** When `.tflite` model weights are not bundled, an intelligent heuristic triage engine provides preliminary dispatch prioritization without crashing or blocking users.

---

## 📋 Test Suite

The test suite covers authentication, RBAC invariants, report workflows, AI triage abstraction, and Spark plan compliance:

```bash
cd flutter_app
flutter test
```

**Results:**
- `test/auth_test.dart` (10 tests)
- `test/firestore_workflow_test.dart` (8 tests)
- `test/final_integration_test.dart` (10 tests)
- `test/widget_test.dart` (1 test)
- **Total:** 29 / 29 tests passing (100% pass rate).

---

## ⚠️ Known Spark Plan Limitations & Future Roadmap

| Area | Current Spark Implementation | Future Blaze / Server Upgrade Pathway |
|---|---|---|
| **Incident Photos** | Persisted locally on device (`LocalPhotoStorageRepository`). Labeled as "Pending Cloud Storage". | Integrate `firebase_storage` with Firebase Cloud Storage when billing is enabled. |
| **Cross-Device Push** | Device tokens synced to Firestore. Foreground local alerts. | Deploy Cloud Functions (`onDocumentCreated`) using Firebase Admin SDK to push alerts across users. |
| **Initial Admin Setup** | Provisioned manually in Firebase Console or via `scripts/provision_admin.dart`. | Admin claims managed via Identity Platform / custom admin web dashboard. |
| **AI Inference** | On-device LiteRT inference abstraction with local heuristic fallback. | Bundle pre-trained `.tflite` model in `assets/models/` for full offline neural execution. |

---

## 📄 Migration Deliverables & Reports

Detailed technical documentation for each phase of the migration is available in the `migration/` directory:
- [PART 1 — Backend Migration Audit](file:///d:/Projects/Paw-Aid/migration/PART_1_BACKEND_AUDIT.md)
- [PART 2 — Complete Supabase & AWS Removal](file:///d:/Projects/Paw-Aid/migration/PART_2_REMOVAL_REPORT.md)
- [PART 3 — Firebase Foundation Setup](file:///d:/Projects/Paw-Aid/migration/PART_3_FIREBASE_FOUNDATION.md)
- [PART 4 — Firebase Auth & RBAC Architecture](file:///d:/Projects/Paw-Aid/migration/PART_4_AUTH_RBAC.md)
- [PART 5 — Cloud Firestore Backend & Workflows](file:///d:/Projects/Paw-Aid/migration/PART_5_FIRESTORE_WORKFLOWS.md)
- [PART 6 — Final Integration, AI & Validation Report](file:///d:/Projects/Paw-Aid/migration/PART_6_FINAL_VALIDATION.md)
