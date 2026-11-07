# PAW AID — Administrator Provisioning Guide

**Target Environment:** Firebase Spark Plan ($0.00 / month — Strictly Free; No Billing)  
**Security Mechanism:** Sealed `admin_roles/{uid}` Collection & Free Admin SDK CLI  
**Document Status:** Operational Runbook — Awaiting Approval Prior to Execution

---

## 1. Overview & Security Foundation

Under the **Firebase Spark Tier ($0.00/month)**, serverless Cloud Functions and Cloud Run microservices cannot be deployed to bootstrap administrators or manage role assignments. Furthermore, relying on an editable field like `role: 'admin'` inside `users/{userId}` is an insecure anti-pattern that permits privilege escalation if document creation or updates are misconfigured.

### The Sealed `admin_roles/{uid}` Mechanism
To guarantee provable, tamper-proof administrative authority under the Spark plan:
1. **Isolated Sealed Collection:**
   Administrative authorization is stored in a dedicated, top-level collection: `admin_roles/{uid}`.
2. **Absolute Client Lockdown:**
   The Firestore Security Rule for this collection is strictly:
   ```firestore
   match /admin_roles/{adminUid} {
     allow read: if isAuthenticated();
     allow write: if false; // STRICTLY FORBIDDEN to all client SDKs
   }
   ```
   Because `allow write: if false;` applies to all mobile clients, **no Flutter app, web client, or compromised user token can ever create, update, or delete a document in `admin_roles`**.
3. **Decoupled Security Rules Check:**
   Every administrative privilege check in `firestore.rules` queries:
   ```firestore
   function isAdmin() {
     return isAuthenticated() && (
       (request.auth.token != null && 'role' in request.auth.token && request.auth.token.role in ['admin', 'ADMIN']) ||
       exists(/databases/$(database)/documents/admin_roles/$(request.auth.uid))
     );
   }
   ```

---

## 2. Provisioning Method 1: Firebase Console GUI (Recommended for Quick Setup)

This zero-code method uses the free Firebase web management console.

### Step 1: Create the User in Firebase Authentication
1. Navigate to the [Firebase Console](https://console.firebase.google.com/).
2. Select your project: **`paw-aid-app`**.
3. In the left navigation sidebar, click **Build** > **Authentication**.
4. In the **Users** tab, click **Add user**.
5. Enter the administrator's designated email (e.g. `admin@pawaid.com`) and a strong, temporary password (minimum 12 characters).
6. Click **Add user**.
7. Locate the newly created user in the user table and copy the **User UID** (e.g., `8dFk92NmQ0xLpZ19v82A...`).

```
+-------------------------------------------------------------+
| User UID: 8dFk92NmQ0xLpZ19v82A                              |
| Email: admin@pawaid.com                                     |
| Providers: Password                                         |
+-------------------------------------------------------------+
```

### Step 2: Provision Authority in the `admin_roles` Collection
1. In the left navigation sidebar, click **Build** > **Firestore Database**.
2. In the **Data** tab:
   * If the `admin_roles` collection does not yet exist, click **Start collection**.
   * Set **Collection ID** to: `admin_roles`.
   * Click **Next**.
3. Set **Document ID** to the exact copied **User UID** (e.g. `8dFk92NmQ0xLpZ19v82A`).
4. Add the following fields:

| Field Name | Type | Value |
| :--- | :--- | :--- |
| `role` | `string` | `admin` |
| `grantedAt` | `timestamp` | Current timestamp |
| `grantedBy` | `string` | `FirebaseConsoleOwner` |
| `email` | `string` | `admin@pawaid.com` |

5. Click **Save**.

### Step 3: Create the Matching `users` Profile Document
1. In **Firestore Database**, navigate to the `users` collection.
2. Click **Add document**.
3. Set **Document ID** to the same **User UID** (`8dFk92NmQ0xLpZ19v82A`).
4. Add the user profile fields:
   ```json
   {
     "id": "8dFk92NmQ0xLpZ19v82A",
     "uid": "8dFk92NmQ0xLpZ19v82A",
     "email": "admin@pawaid.com",
     "fullName": "System Administrator",
     "displayName": "System Administrator",
     "role": "admin",
     "accountStatus": "active",
     "createdAt": "2026-11-07T12:00:00Z",
     "updatedAt": "2026-11-07T12:00:00Z"
   }
   ```
5. Click **Save**.

*Result:* The user is now fully recognized as an Administrator by both the Flutter UI and Firestore Security Rules.

---

## 3. Provisioning Method 2: Free Local Admin SDK CLI (Automated & Scriptable)

The **Firebase Admin SDK** is completely free, incurs ₹0 billing, and works seamlessly with the Firebase Spark plan. By running a local script on the project owner's workstation, administrators can be provisioned and granted cryptographically signed Custom Claims without deploying any cloud compute.

### Step 1: Generate a Service Account Key
1. In [Firebase Console](https://console.firebase.google.com/), open **Project Settings** (gear icon) > **Service accounts**.
2. Select **Node.js** (or Python).
3. Click **Generate new private key**, then click **Generate key**.
4. Save the JSON file securely on your local computer as `tools/serviceAccountKey.json`.

> [!CAUTION]
> Never commit `serviceAccountKey.json` to version control. Add it to `.gitignore`.

### Step 2: The Local Provisioning Script (`tools/provision_admin.js`)
Create a local script in the `tools/` folder:

```javascript
/**
 * PAW AID — Free Local Administrator Provisioning Tool (Spark Tier)
 * Usage: node tools/provision_admin.js <admin-email> <password> <displayName>
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

async function provisionAdmin(email, password, displayName) {
  console.log(`\n--- Provisioning Administrator: ${email} ---`);

  // 1. Check if user already exists in Firebase Auth, or create new
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`[Auth] Existing user found with UID: ${userRecord.uid}`);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: displayName,
      });
      console.log(`[Auth] Created new user with UID: ${userRecord.uid}`);
    } else {
      throw error;
    }
  }

  const uid = userRecord.uid;

  // 2. Set Custom User Claim (Free in Firebase Auth, instantly verified in rules)
  await auth.setCustomUserClaims(uid, { role: 'admin' });
  console.log(`[Auth] Custom claim { role: 'admin' } set on user.`);

  // 3. Write document to sealed admin_roles collection
  await db.collection('admin_roles').doc(uid).set({
    role: 'admin',
    email: email,
    grantedAt: admin.firestore.FieldValue.serverTimestamp(),
    grantedBy: 'LocalAdminCLI',
  });
  console.log(`[Firestore] Document created in sealed admin_roles/${uid}`);

  // 4. Create or update user profile document in users collection
  await db.collection('users').doc(uid).set({
    id: uid,
    uid: uid,
    email: email,
    fullName: displayName,
    displayName: displayName,
    role: 'admin',
    accountStatus: 'active',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`[Firestore] User profile synchronized in users/${uid}`);

  console.log('\n SUCCESS: Administrator provisioned with zero cloud billing.\n');
}

// Execution arguments
const [email, password, name] = process.argv.slice(2);
if (!email || !password || !name) {
  console.error('Usage: node tools/provision_admin.js <email> <password> <displayName>');
  process.exit(1);
}

provisionAdmin(email, password, name).catch(console.error);
```

### Step 3: Run the Script
```bash
node tools/provision_admin.js admin@pawaid.com "AdminSecurePass2026!" "PAW-AID System Admin"
```

---

## 4. Verification Procedures

To confirm that administrative authority is active and enforcing security:

### 4.1 In-App Verification
1. Launch the Flutter app on an emulator or test device.
2. On the **Login Screen**, sign in with the provisioned administrator credentials (`admin@pawaid.com`).
3. **Verify Routing:** Confirm the app directs the user to `/admin/dashboard`.
4. **Verify NGO Verification Queue:** Navigate to the **NGO Verification Screen** (`/admin/verification`). Confirm that pending NGO applications load from Cloud Firestore without encountering a `PERMISSION_DENIED` exception.
5. **Verify City-Wide Rescue Overview:** Navigate to **All Cases** (`/admin/all-cases`). Confirm that city-wide rescue incidents submitted by citizens are visible.

### 4.2 Security Rules Verification (Local Emulator)
Verify that client-side self-promotion is blocked:
```javascript
// Test: Non-admin trying to write to admin_roles
const nonAdminContext = testEnv.authenticatedContext('citizen-user-123');
const nonAdminDb = nonAdminContext.firestore();

await firebase.assertFails(
  nonAdminDb.collection('admin_roles').doc('citizen-user-123').set({ role: 'admin' })
);
// Result: PERMISSION_DENIED (Passes)
```

---

## 5. Administrator Revocation & Emergency Procedures

If an administrator leaves the organization, or credentials are compromised:

### Immediate Revocation Procedure
1. **Remove Authority from `admin_roles`:**
   * Open **Firebase Console** > **Firestore Database** > `admin_roles`.
   * Delete the document matching the administrator's UID.
   * *Instant Effect:* Firestore Security Rules immediately deny administrative read and write operations on the next request.
2. **Revoke Custom User Claims (if Admin SDK was used):**
   Run the local CLI revocation script:
   ```javascript
   await admin.auth().setCustomUserClaims(uid, { role: 'citizen' });
   await admin.auth().revokeRefreshTokens(uid);
   ```
3. **Disable Auth Account:**
   * Open **Firebase Console** > **Authentication**.
   * Locate the user > Click **More options** (three dots) > **Disable account**.
4. **Demote User Profile:**
   * In Firestore `users/{uid}`, update `role: 'citizen'` and `accountStatus: 'suspended'`.

---

## 6. Periodic Security Audit Checklist

Review the following quarterly to maintain system integrity under the Spark tier:
* [ ] **Audit `admin_roles` Size:** Confirm that only active, verified personnel exist in the `admin_roles` collection.
* [ ] **Audit Daily Read/Write Quotas:** Check Firebase Console > **Usage** to ensure total daily Firestore reads stay safely within the 50,000 read ceiling.
* [ ] **Audit Storage Footprint:** Confirm total Firestore storage remains below 200 MB (safely under the 1 GiB free ceiling) and verify that no Base64 strings have been introduced.
* [ ] **Rotate Service Account Keys:** Delete unused service account keys in Google Cloud / Firebase Console.
