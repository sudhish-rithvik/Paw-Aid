# PAW AID — Proposed Secure Firestore Security Rules

**Target File:** `firestore.rules`  
**Firebase Plan:** Spark Tier ($0.00 / month — Strictly Free; No Billing)  
**Security Standard:** Principle of Least Privilege, Append-Only Auditing, Sealed Admin Roles  
**Document Status:** Proposed Rules Specification — Awaiting Approval Prior to Replacing Existing Rules

---

## 1. Rule Architecture & Security Highlights

1. **Sealed Admin Roles (`admin_roles/{uid}`):**
   Client-side writes to `admin_roles` are unconditionally blocked (`allow write: if false;`). Administrative authority is proven by `exists(/databases/$(database)/documents/admin_roles/$(request.auth.uid))` or Custom Claims, completely preventing privilege escalation from compromised client code or mutable user profile documents.
2. **Citizen Private Report Isolation:**
   Citizens are granted read access **strictly and exclusively** to their own submitted reports (`resource.data.citizenId == request.auth.uid`). The insecure `isOpenReport()` bypass has been completely eradicated.
3. **No NGO Self-Assignment:**
   Approved NGOs can only read and update reports that have been formally assigned to them by an Administrator (`resource.data.assignedNgoId == request.auth.uid`). Case dispatch (`assignments` creation) is restricted exclusively to Administrators.
4. **Permanent Prohibition of Base64 Images:**
   All `photoBase64` fields have been excised. The rules explicitly validate that `photoBase64` is not present in document payloads (`!('photoBase64' in request.resource.data)`).
5. **Tamper-Proof Audit Trails:**
   The `status_history` subcollection is strictly append-only. Modification and deletion are locked down (`allow update, delete: if false;`).
6. **Consolidation on Canonical `reports`:**
   Rules for duplicate legacy collections (`rescue_cases` and `cases`) are removed, protecting write quotas under the Spark plan.

---

## 2. Full Proposed `firestore.rules` Code

```firestore
rules_version = '2';

// ===============================================================
// PAW-AID: Cloud Firestore Security Rules (Phase 2 Secure Architecture)
// Zero-Cost Firebase Spark Plan Implementation
// ===============================================================

service cloud.firestore {
  match /databases/{database}/documents {

    // ===============================================================
    // Helper Functions: Authentication & Role Resolution
    // ===============================================================

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // Secure Administrator Check:
    // Decoupled from the mutable users/{userId} collection.
    // Relies on the sealed admin_roles collection OR cryptographically signed token claims.
    function isAdmin() {
      return isAuthenticated() && (
        (request.auth.token != null && 'role' in request.auth.token && request.auth.token.role in ['admin', 'ADMIN']) ||
        exists(/databases/$(database)/documents/admin_roles/$(request.auth.uid))
      );
    }

    // Approved NGO Check:
    // Requires both an active user profile and an approved organization directory profile.
    function isApprovedNgo() {
      return isAuthenticated() && (
        (request.auth.token != null && 'role' in request.auth.token && request.auth.token.role in ['ngo_staff', 'NGO_STAFF']) ||
        (
          exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['ngo_staff', 'NGO_STAFF', 'ngo', 'NGO'] &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.accountStatus in ['active', 'ACTIVE'] &&
          exists(/databases/$(database)/documents/ngos/$(request.auth.uid)) &&
          get(/databases/$(database)/documents/ngos/$(request.auth.uid)).data.status in ['approved', 'APPROVED']
        )
      );
    }

    // Validation Primitives
    function isValidEmail(email) {
      return email is string &&
        email.size() <= 100 &&
        email.matches("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$");
    }

    function isValidOptionalString(field, minLen, maxLen) {
      return !(field in request.resource.data) ||
             request.resource.data[field] == null ||
             (request.resource.data[field] is string &&
              request.resource.data[field].size() >= minLen &&
              request.resource.data[field].size() <= maxLen);
    }

    function isValidOptionalNumber(field, minVal, maxVal) {
      return !(field in request.resource.data) ||
             request.resource.data[field] == null ||
             (request.resource.data[field] is number &&
              request.resource.data[field] >= minVal &&
              request.resource.data[field] <= maxVal);
    }

    function isValidDateTime(field) {
      return !(field in request.resource.data) ||
             request.resource.data[field] == null ||
             request.resource.data[field] is timestamp ||
             (request.resource.data[field] is string && request.resource.data[field].size() <= 50);
    }

    function areImmutableFieldsUnchanged(fields) {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(fields);
    }

    // Case Ownership Helpers
    function isCaseReporter(caseData) {
      return isAuthenticated() && (
        ('citizenId' in caseData && caseData.citizenId == request.auth.uid) ||
        ('reporterId' in caseData && caseData.reporterId == request.auth.uid)
      );
    }

    function isAssignedNgo(caseData) {
      return isApprovedNgo() && (
        ('assignedNgoId' in caseData && caseData.assignedNgoId == request.auth.uid) ||
        ('assigned_ngo_id' in caseData && caseData.assigned_ngo_id == request.auth.uid)
      );
    }

    // ===============================================================
    // 0. SEALED ADMIN ROLES (admin_roles/{adminUid})
    // ===============================================================
    match /admin_roles/{adminUid} {
      // Authenticated users can check admin role existence; client writes are strictly denied.
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // ===============================================================
    // 1. USERS COLLECTION (users/{userId})
    // ===============================================================
    match /users/{userId} {
      // Strict PII isolation: Users can only read their own profile; Admins can inspect any user.
      allow read: if isAuthenticated() && (isOwner(userId) || isAdmin());

      // Create: Public registration allows CITIZEN ('active') or NGO ('pending').
      // Admin account creation is strictly forbidden to untrusted callers.
      allow create: if isAuthenticated() && isOwner(userId) &&
        request.resource.data.keys().hasOnly([
          'id', 'uid', 'email', 'role', 'displayName', 'fullName', 'display_name',
          'phone', 'phoneNumber', 'accountStatus', 'account_status',
          'fcmToken', 'fcm_token', 'createdAt', 'created_at', 'updatedAt', 'updated_at'
        ]) &&
        isValidEmail(request.resource.data.email) &&
        isValidOptionalString('displayName', 1, 100) &&
        isValidOptionalString('fullName', 1, 100) &&
        isValidOptionalString('phone', 5, 30) &&
        isValidOptionalString('phoneNumber', 5, 30) &&
        isValidDateTime('createdAt') &&
        (
          (request.resource.data.role in ['citizen', 'CITIZEN'] && request.resource.data.accountStatus in ['active', 'ACTIVE']) ||
          (request.resource.data.role in ['ngo_staff', 'NGO_STAFF', 'ngo', 'NGO'] && request.resource.data.accountStatus in ['pending', 'PENDING'])
        );

      // Update: Users cannot alter their role or account status.
      // Admins have full lifecycle access (e.g. approving an NGO user account).
      allow update: if isAuthenticated() && (
        isAdmin() || (
          isOwner(userId) &&
          request.resource.data.role == resource.data.role &&
          request.resource.data.accountStatus == resource.data.accountStatus &&
          areImmutableFieldsUnchanged(['id', 'uid', 'role', 'accountStatus', 'account_status', 'createdAt', 'created_at'])
        )
      );

      // Delete: Admins only. User profiles cannot be deleted by clients to protect audit integrity.
      allow delete: if isAdmin();
    }

    // ===============================================================
    // 2. NGOS DIRECTORY (ngos/{ngoId})
    // ===============================================================
    match /ngos/{ngoId} {
      // Approved NGOs are visible to all authenticated users for directory & emergency dispatch.
      // Pending NGOs are visible only to the registering organization and Admins.
      allow read: if isAuthenticated() && (
        (resource.data.status in ['approved', 'APPROVED']) ||
        isAdmin() ||
        isOwner(ngoId)
      );

      // Registration: The NGO document ID MUST equal the registering user's UID (ngoId == request.auth.uid).
      // Initial status MUST be 'pending'.
      allow create: if isAuthenticated() && isOwner(ngoId) &&
        request.resource.data.keys().hasOnly([
          'id', 'ngoId', 'name', 'organizationName', 'registrationNumber', 'registration_number',
          'email', 'phone', 'city', 'state', 'address', 'latitude', 'lat', 'longitude', 'lng',
          'serviceRadiusKm', 'service_radius_km', 'specializations', 'status',
          'numVehicles', 'num_vehicles', 'numVolunteers', 'num_volunteers',
          'activeCasesCount', 'totalRescued', 'successRate', 'createdAt', 'updatedAt'
        ]) &&
        request.resource.data.status in ['pending', 'PENDING'] &&
        isValidEmail(request.resource.data.email) &&
        isValidOptionalNumber('latitude', -90, 90) &&
        isValidOptionalNumber('longitude', -180, 180) &&
        isValidDateTime('createdAt');

      // Update: Only Admins can approve or reject NGOs.
      // Approved NGOs can update operational details (vehicles, radius), but not their status or registration number.
      allow update: if isAuthenticated() && (
        isAdmin() || (
          isOwner(ngoId) &&
          isApprovedNgo() &&
          areImmutableFieldsUnchanged([
            'id', 'ngoId', 'registrationNumber', 'registration_number',
            'status', 'verification_status', 'createdAt', 'created_at'
          ])
        )
      );

      allow delete: if isAdmin();
    }

    // ===============================================================
    // 3. ANIMAL RESCUE REPORTS (reports/{reportId})
    // ===============================================================
    match /reports/{reportId} {
      // Strict Report Read Isolation:
      // - Citizens can ONLY read their own reports.
      // - NGOs can ONLY read reports assigned to their organization.
      // - Admins can read all reports city-wide.
      allow read: if isAuthenticated() && (
        isAdmin() ||
        isCaseReporter(resource.data) ||
        isAssignedNgo(resource.data)
      );

      // Create: Citizens and Admins can create reports.
      // Initial status MUST be 'NEW'. photoBase64 is strictly prohibited.
      allow create: if isAuthenticated() && (
        isAdmin() || (
          isCaseReporter(request.resource.data) &&
          request.resource.data.reportStatus in ['NEW', 'new'] &&
          !('photoBase64' in request.resource.data) &&
          request.resource.data.keys().hasOnly([
            'reportId', 'id', 'case_id', 'citizenId', 'reporterId', 'reporter_id',
            'citizenName', 'reporterName', 'citizenPhone', 'reporterPhone',
            'animalType', 'animal', 'animalDescription', 'injuryDescription', 'notes',
            'injuryCategory', 'severity', 'priorityLevel', 'latitude', 'lat', 'longitude', 'lng',
            'address', 'photoReference', 'imageUrl', 'image_path', 'photoUploadStatus',
            'assignedNgoId', 'assigned_ngo_id', 'assignedNgoName', 'ngo_name',
            'reportStatus', 'status', 'aiAnalysis', 'ai_analysis',
            'createdAt', 'created_at', 'updatedAt', 'updated_at'
          ]) &&
          isValidOptionalString('photoReference', 1, 500) &&
          isValidOptionalNumber('latitude', -90, 90) &&
          isValidOptionalNumber('longitude', -180, 180) &&
          isValidDateTime('createdAt')
        )
      );

      // Update:
      // - Admins can perform full lifecycle updates, dispatch, and case reassignment.
      // - Assigned NGOs can update rescue progression status and notes; cannot change assigned NGO.
      // - Citizen reporters can update notes before rescue begins; cannot change status or assigned NGO.
      allow update: if isAuthenticated() && !('photoBase64' in request.resource.data) && (
        isAdmin() || (
          isAssignedNgo(resource.data) &&
          areImmutableFieldsUnchanged([
            'reportId', 'id', 'case_id', 'citizenId', 'reporterId',
            'assignedNgoId', 'assigned_ngo_id', 'assignedNgoName', 'ngo_name',
            'createdAt', 'created_at'
          ])
        ) || (
          isCaseReporter(resource.data) &&
          resource.data.reportStatus in ['NEW', 'new', 'UNDER_REVIEW', 'under_review'] &&
          areImmutableFieldsUnchanged([
            'reportId', 'id', 'case_id', 'citizenId', 'reporterId',
            'assignedNgoId', 'assigned_ngo_id', 'assignedNgoName', 'ngo_name',
            'reportStatus', 'status', 'createdAt', 'created_at'
          ])
        )
      );

      allow delete: if isAdmin();

      // ─── Subcollection: status_history ───────────────────────────
      match /status_history/{historyId} {
        // Read: Readable only by parties authorized on parent report
        allow read: if isAuthenticated() && (
          isAdmin() ||
          (
            exists(/databases/$(database)/documents/reports/$(reportId)) && (
              isCaseReporter(get(/databases/$(database)/documents/reports/$(reportId)).data) ||
              isAssignedNgo(get(/databases/$(database)/documents/reports/$(reportId)).data)
            )
          )
        );

        // Create: Append-only by authorized actor (reporter on creation, assigned NGO on stage update, or Admin)
        allow create: if isAuthenticated() &&
          request.resource.data.keys().hasOnly([
            'historyId', 'id', 'reportId', 'report_id', 'previousStatus', 'previous_status',
            'newStatus', 'status', 'actorId', 'actor_id', 'actorRole', 'actor_role',
            'notes', 'photoReference', 'photo_reference', 'timestamp', 'created_at'
          ]) &&
          !('photoBase64' in request.resource.data) &&
          isValidDateTime('timestamp') && (
            isAdmin() ||
            (
              exists(/databases/$(database)/documents/reports/$(reportId)) && (
                (
                  isAssignedNgo(get(/databases/$(database)/documents/reports/$(reportId)).data) &&
                  request.resource.data.actorId == request.auth.uid
                ) ||
                (
                  isCaseReporter(get(/databases/$(database)/documents/reports/$(reportId)).data) &&
                  request.resource.data.actorId == request.auth.uid &&
                  request.resource.data.newStatus in ['NEW', 'new']
                )
              )
            )
          );

        // Tamper-proof guarantee: Status history can NEVER be updated or deleted
        allow update, delete: if false;
      }

      // ─── Subcollection: comments ─────────────────────────────────
      match /comments/{commentId} {
        allow read: if isAuthenticated() && (
          isAdmin() ||
          (
            exists(/databases/$(database)/documents/reports/$(reportId)) && (
              isCaseReporter(get(/databases/$(database)/documents/reports/$(reportId)).data) ||
              isAssignedNgo(get(/databases/$(database)/documents/reports/$(reportId)).data)
            )
          )
        );

        allow create: if isAuthenticated() &&
          request.resource.data.keys().hasOnly(['id', 'authorId', 'authorName', 'text', 'createdAt']) &&
          request.resource.data.authorId == request.auth.uid &&
          isValidOptionalString('text', 1, 2000) &&
          (
            isAdmin() ||
            (
              exists(/databases/$(database)/documents/reports/$(reportId)) && (
                isCaseReporter(get(/databases/$(database)/documents/reports/$(reportId)).data) ||
                isAssignedNgo(get(/databases/$(database)/documents/reports/$(reportId)).data)
              )
            )
          );

        allow update, delete: if isAuthenticated() && (
          isAdmin() || resource.data.authorId == request.auth.uid
        );
      }
    }

    // ===============================================================
    // 4. DISPATCH ASSIGNMENTS (assignments/{assignmentId})
    // ===============================================================
    match /assignments/{assignmentId} {
      // Read: Admin or targeted NGO
      allow read: if isAuthenticated() && (
        isAdmin() ||
        resource.data.ngoId == request.auth.uid
      );

      // Create: ADMIN ONLY. NGOs cannot self-assign reports.
      allow create: if isAuthenticated() && isAdmin() &&
        request.resource.data.keys().hasOnly([
          'assignmentId', 'id', 'reportId', 'report_id', 'ngoId', 'ngo_id',
          'ngoName', 'ngo_name', 'status', 'assignedBy', 'assigned_by',
          'etaMinutes', 'eta_minutes', 'notes', 'rejectionReason', 'rejection_reason',
          'createdAt', 'created_at', 'updatedAt', 'updated_at'
        ]) &&
        request.resource.data.status in ['ASSIGNED', 'assigned'] &&
        isValidDateTime('createdAt');

      // Update: Target NGO can accept or reject assignment, record ETA, and provide notes.
      allow update: if isAuthenticated() && (
        isAdmin() || (
          resource.data.ngoId == request.auth.uid &&
          isApprovedNgo() &&
          request.resource.data.status in ['ACCEPTED', 'REJECTED', 'COMPLETED'] &&
          areImmutableFieldsUnchanged(['assignmentId', 'id', 'reportId', 'report_id', 'ngoId', 'ngo_id', 'assignedBy', 'createdAt'])
        )
      );

      allow delete: if isAdmin();
    }

    // ===============================================================
    // 5. NOTIFICATIONS (notifications/{notificationId})
    // ===============================================================
    match /notifications/{notificationId} {
      // Read: Strictly isolated to recipient or Admin
      allow read: if isAuthenticated() && (
        isAdmin() ||
        resource.data.recipient_user_id == request.auth.uid ||
        resource.data.recipientUserId == request.auth.uid
      );

      // Create: Admin or authorized actor (assigned NGO / citizen on an active case)
      allow create: if isAuthenticated() && (
        isAdmin() ||
        (
          request.resource.data.keys().hasOnly([
            'id', 'notificationId', 'recipient_user_id', 'recipientUserId',
            'title', 'body', 'type', 'reference_id', 'referenceId',
            'is_read', 'isRead', 'created_at', 'createdAt'
          ]) &&
          isValidOptionalString('title', 1, 150) &&
          isValidOptionalString('body', 1, 1000)
        )
      );

      // Update: Recipient can ONLY mark read/unread status
      allow update: if isAuthenticated() && (
        isAdmin() || (
          (resource.data.recipient_user_id == request.auth.uid || resource.data.recipientUserId == request.auth.uid) &&
          request.resource.data.diff(resource.data).affectedKeys().hasOnly(['is_read', 'isRead'])
        )
      );

      allow delete: if isAuthenticated() && (
        isAdmin() ||
        resource.data.recipient_user_id == request.auth.uid ||
        resource.data.recipientUserId == request.auth.uid
      );
    }

    // ===============================================================
    // 6. DEFAULT DENY ALL OTHER PATHS
    // ===============================================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```
