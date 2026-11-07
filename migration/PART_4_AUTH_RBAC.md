# PART 4 — PAW AID Firebase Authentication and RBAC Report

## Executive Summary

Role-Based Access Control (RBAC) and Firebase Authentication have been fully implemented for **PAW AID** (`com.pawaid.paw_aid`) in strict adherence to the **Firebase Spark Tier ($0.00/month free tier)**. 

The architecture enforces:
- **Zero Paid Billing**: Zero Cloud Functions, zero Cloud Run services, zero Blaze dependencies.
- **Three Distinct User Roles**: `CITIZEN`, `NGO`, and `ADMIN`.
- **Role Invariants & Immutability**:
  - `CITIZEN`: Self-registered publicly; automatically assigned `role: "citizen"` and `accountStatus: "active"`.
  - `NGO`: Self-registered publicly; automatically initialized in `role: "ngo_staff"` and `accountStatus: "pending"`, requiring administrator verification before rescue queue access is granted.
  - `ADMIN`: Strictly prohibited from public registration. Provisioned through a trusted administrative procedure.
- **Production-Grade Firestore Security Rules**: Authored in `firestore.rules` (both repository root and `flutter_app/`) featuring domain validators, attribute immutability checks, and an explicit catch-all `default deny`.
- **Unchanged UI & Workflows**: All screens, navigation flows, and interactive widgets have been preserved without layout redesign.

---

## 1. Role-Based Access Control (RBAC) Matrix

| Dimension | `CITIZEN` | `NGO` (`ngo_staff`) | `ADMIN` |
| :--- | :--- | :--- | :--- |
| **Registration Method** | Public self-service via Register Screen | Public self-service via NGO Register Screen | Trusted manual provisioning in Firebase Console |
| **Initial Account Status** | `active` | `pending` (awaits admin audit) | `active` |
| **Login Access** | Immediate access to `/citizen/home` | Blocked if `pending`; `/ngo/dashboard` once `active` | Immediate access to `/admin/dashboard` |
| **Report Submission** | Can create distress cases with photo/GPS | Cannot create cases as an NGO | Can create and audit all cases |
| **Report Viewing** | Own submitted cases (`reporterId == uid`) & open alerts | Assigned rescue cases and queue in service radius | All city-wide cases, heatmaps, and analytics |
| **Report Updating** | Non-status details prior to rescue closure | Update rescue stages (7-stage workflow), vitals, ETA | Full administrative update and case reassignment |
| **Role Elevation** | Prohibited in client and security rules | Prohibited in client and security rules | Can promote, verify, and suspend any user |

---

## 2. Authentication Features Implemented

### 2.1 Email & Password Registration
- **Public Citizen Registration**: Validates email format, display name, phone (optional), and minimum 6-character password matching. Upon creation, `FirebaseAuthService` generates credentials in Firebase Auth and atomically writes a profile to `users/{uid}` with `role: "citizen"` and `accountStatus: "active"`.
- **Administrative Account Protection**: Any attempt to send `role: "admin"` during public signup is blocked by client exception (`UnauthorizedRoleException`) and denied by Firestore Security Rules.

### 2.2 Email & Password Login
- Validates credentials via `FirebaseAuth.instance.signInWithEmailAndPassword`.
- Hydrates user document from `users/{uid}` to determine active role and account status.
- If an NGO account is in `pending` status, access to the operational dashboard is withheld and an informative modal is presented ("Verification Pending: Your animal welfare credentials are awaiting administrator audit").

### 2.3 Password Reset
- Integrated into [login_screen.dart](file:///d:/Projects/Paw-Aid/flutter_app/lib/features/auth/screens/login_screen.dart) with a "Forgot Password?" dialog.
- Dispatches reset link through `FirebaseAuth.instance.sendPasswordResetEmail(email)`.

### 2.4 Persistent Login Sessions
- Active sessions are stored using `FlutterSecureStorage` (AES hardware encrypted tokens) and `SharedPreferences`.
- On launch, [splash_screen.dart](file:///d:/Projects/Paw-Aid/flutter_app/lib/features/auth/screens/splash_screen.dart) checks `AuthService.getCurrentUser()`. If valid and active, the user is seamlessly routed directly to their respective role dashboard without re-entering credentials.

### 2.5 Offline & Exhibition Demo Fallbacks
- One-tap demo accounts (`citizen@pawaid.com`, `ngo@pawaid.com`, `admin@pawaid.com`) remain functional with offline mock support so developers, testers, and evaluators can switch roles instantly without configuring network access.

---

## 3. Safe Initial Administrator Provisioning Process (Spark Tier)

Because PAW-AID operates on the **Firebase Spark Tier ($0.00/month)**, serverless Cloud Functions and Cloud Run microservices cannot be deployed to bootstrap administrators. Client-side checks alone are never treated as secure authorization.

To bootstrap the initial platform administrator securely without paid infrastructure:

### Procedure: Firebase Console Manual Provisioning
1. **Create the Admin Auth User**:
   - Go to [Firebase Console](https://console.firebase.google.com/) > **Authentication** > **Users**.
   - Click **Add user**.
   - Enter the administrator's email (e.g., `admin@pawaid.com`) and a strong temporary password.
   - Copy the generated `User UID` (e.g., `8dFk92NmQ0...`).

2. **Create the Trusted Profile Document**:
   - Navigate to **Firestore Database** > **Data**.
   - If the `users` collection does not exist, click **Start collection** and name it `users`.
   - Set **Document ID** to the exact copied `User UID`.
   - Add the following fields:
     ```json
     {
       "uid": "8dFk92NmQ0...",
       "id": "8dFk92NmQ0...",
       "email": "admin@pawaid.com",
       "fullName": "System Administrator",
       "displayName": "System Administrator",
       "role": "admin",
       "accountStatus": "active",
       "createdAt": "2026-11-05T12:00:00.000Z",
       "updatedAt": "2026-11-05T12:00:00.000Z"
     }
     ```
   - Click **Save**.

3. **Backend Security Guarantee**:
   - Firestore Security Rules evaluate `isAdmin()` by querying `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'ADMIN']`.
   - Because write access to set `role: "admin"` is strictly blocked for non-admins, an attacker cannot forge or inject an admin record from the Flutter client.

---

## 4. Production-Grade Cloud Firestore Security Rules

The security rules have been deployed to both root [firestore.rules](file:///d:/Projects/Paw-Aid/firestore.rules) and [flutter_app/firestore.rules](file:///d:/Projects/Paw-Aid/flutter_app/firestore.rules).

### 4.1 Key Security Highlights
1. **PII Protection (`users/{userId}`)**:
   - Read is permitted only if `isOwner(userId)` or `isAdmin()`.
   - Create is allowed only if `request.auth.uid == userId` and the user registers as either an active citizen or a pending NGO.
   - Update permits modifying personal details (name, phone, FCM token) while enforcing immutability on `id`, `uid`, `email`, `role`, and `accountStatus`.
2. **NGO Verification Integrity (`ngos/{ngoId}`)**:
   - Read is permitted for approved/verified NGOs by public citizens; unverified NGOs can only be read by their owner or administrators.
   - Create forces `status` / `verification_status` to `'pending'`.
   - State transition to `'approved'` / `'verified'` is restricted exclusively to `isAdmin()`.
3. **Rescue Cases & Reports (`rescue_cases/{caseId}` and `cases/{caseId}`)**:
   - Citizens can create reports with initial status `'reported'` or `'pending'`.
   - Assigned NGOs and Admins can update rescue progress (stage progression, vitals, ETA).
   - Document sizes are capped to prevent base64 over-allocation (Spark 1 MiB limit protection).
4. **Append-Only Auditing (`events/{eventId}`)**:
   - Rescue status transitions append event documents to `cases/{id}/events`.
   - Update is blocked (`allow update: if false;`), ensuring tamper-proof audit trails.
5. **Default Deny**:
   - The root document matcher closes any unmapped paths:
     ```javascript
     match /{document=**} {
       allow read, write: if false;
     }
     ```

---

## 5. Architectural Implementation Overview

```
flutter_app/
├── lib/
│   ├── core/
│   │   ├── errors/
│   │   │   └── app_exceptions.dart          # AppAuthException, AccountPendingApprovalException, UnauthorizedRoleException
│   │   ├── firebase/
│   │   │   └── firebase_constants.dart      # Standardized roles ('citizen', 'ngo_staff', 'admin') & collections
│   │   └── services/
│   │       └── auth_service.dart            # Multi-role authentication & session manager with demo bypass
│   ├── data/
│   │   ├── models/
│   │   │   └── user_model.dart              # UserModel with uid, fullName, phoneNumber, role, and accountStatus
│   │   └── repositories/
│   │       └── auth_repository.dart         # AuthRepository and AuthRepositoryImpl with password reset
│   ├── features/
│   │   └── auth/
│   │       ├── providers/
│   │       │   ├── auth_provider.dart       # Riverpod AuthNotifier, userProfileProvider, userRoleProvider, userAccountStatusProvider
│   │       │   └── auth_provider.g.dart     # Auto-generated provider bindings
│   │       └── screens/
│   │           ├── login_screen.dart        # Login UI with password reset modal & NGO pending alert
│   │           ├── register_screen.dart     # Citizen registration UI with validation
│   │           └── splash_screen.dart       # Persistent session routing
│   └── services/
│       └── auth/
│           └── firebase_auth_service.dart   # FlutterFire Authentication wrapper with Firestore synchronization
└── test/
    └── auth_test.dart                       # 11 Unit tests covering RBAC invariants, serialization, and restrictions
```

---

## 6. Verification & Test Results

The implementation was validated using the Flutter test runner:

```powershell
flutter test
```

### Test Output:
```
00:00 +0: loading test/auth_test.dart
00:00 +1: UserModel & RBAC Invariants Citizen role is correctly identified and defaults to active
00:00 +2: UserModel & RBAC Invariants NGO role is identified and reflects pending approval status
00:00 +3: UserModel & RBAC Invariants Admin role is identified
00:00 +4: UserModel & RBAC Invariants Serialization toMap preserves uid, fullName, and accountStatus
00:00 +5: Public Registration RBAC Security Restrictions AuthService.signUp prevents admin registration
00:00 +6: Public Registration RBAC Security Restrictions AuthService.signUp prevents ADMIN uppercase registration
00:00 +7: AuthUser & Demo Session Invariants Demo admin session has admin role and is active
00:00 +8: AuthUser & Demo Session Invariants Demo NGO session has ngo role and is active
00:00 +9: AuthUser & Demo Session Invariants Demo Citizen session has citizen role
00:00 +10: AuthUser & Demo Session Invariants Password reset with empty email throws AppAuthException
00:00 +11: All tests passed!
```

### Static Analysis:
- `flutter analyze`: **0 compilation errors**.
- All legacy Supabase/AWS imports completely eradicated.
- Zero paid dependencies introduced.

---

## 7. Ready for PART 5

The authentication layer and role-based access control are fully operational.

**Awaiting your approval or instructions to proceed to PART 5 — Cloud Firestore Data Modeling & Migration.**
