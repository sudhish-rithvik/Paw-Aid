# Cloudinary Free-Tier Setup Guide for PAW-AID

PAW-AID supports direct client-side photo uploading to **Cloudinary** on their **100% Free Plan** (No Credit Card required, 25 GB monthly bandwidth/storage).

---

### Step 1: Create a Free Cloudinary Account
1. Visit **[cloudinary.com/users/register_free](https://cloudinary.com/users/register_free)**.
2. Sign up with your email. No credit card or billing information is required.

---

### Step 2: Get Your Cloud Name
1. Once logged into the **Cloudinary Dashboard / Programmable Media**, locate your **Product Environment Credentials**.
2. Note your **Cloud name** (e.g., `dhyzpjv4m` or `pawaid-app`).

---

### Step 3: Create an Unsigned Upload Preset
1. In Cloudinary Console, click the **Settings gear icon (⚙️)** in the bottom left.
2. Navigate to **Upload** $\rightarrow$ scroll down to **Upload presets**.
3. Click **Add upload preset**.
4. Configure the following:
   - **Upload preset name:** Enter a name such as `paw_aid_cases` (or keep the auto-generated name).
   - **Signing Mode:** Select **Unsigned** *(Crucial: This permits mobile uploads without exposing your private secret API key!)*.
   - **Folder:** Set to `paw_aid_reports` (optional, keeps photos organized).
5. Click **Save** in the top right.

---

### Step 4: Configure PAW-AID
You have two simple options to provide your Cloudinary credentials:

#### Option A: Edit `AppConfig` directly in code
In `flutter_app/lib/core/config/app_config.dart`:
```dart
static const String cloudinaryCloudName = String.fromEnvironment(
  'CLOUDINARY_CLOUD_NAME',
  defaultValue: 'YOUR_CLOUD_NAME', // <- Put your Cloud Name here
);

static const String cloudinaryUploadPreset = String.fromEnvironment(
  'CLOUDINARY_UPLOAD_PRESET',
  defaultValue: 'paw_aid_cases', // <- Put your Unsigned Preset name here
);
```

#### Option B: Pass via `--dart-define` at runtime
```bash
flutter run \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset_name
```

---

### Step 5: How It Works & Fallback Resilience
- **Direct Upload:** When a citizen captures an injured animal's photo, PAW-AID directly streams the image to Cloudinary CDN via multipart HTTPS upload.
- **Universal Visibility:** The resulting secure URL (`https://res.cloudinary.com/...`) is stored in Firestore under `photoReference`. All Citizens, NGOs, and Admins can see the photo from any device.
- **Offline / Zero-Failure Fallback:** If Cloudinary is offline, unconfigured, or the user is without internet, the app compresses the photo and falls back to local storage and Base64 Firestore preservation so no emergency report is ever dropped.
