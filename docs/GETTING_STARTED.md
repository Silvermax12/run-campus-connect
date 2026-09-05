# RUN Campus Connect — Developer Getting Started Guide

This guide provides exhaustive, step-by-step instructions for setting up the complete **RUN Campus Connect** local development environment across all system tiers: the Flutter mobile client, the Python FastAPI OCR microservice, the Vercel serverless push gateway, and the Firebase cloud configuration.

---

## 1. Prerequisites & Environment Requirements

Ensure the following tools and SDKs are installed on your workstation prior to repository setup:

| Tool / Runtime | Minimum Version | Recommended Version | Verification Command | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Flutter SDK** | `3.7.0` | `3.27.x` or latest stable | `flutter --version` | Cross-platform mobile development |
| **Dart SDK** | `^3.7.2` | Bundled with Flutter | `dart --version` | Language runtime & code generation |
| **Android Studio / SDK** | API Level 21 (minSdk) | Target SDK 34 | `adb --version` | Android compilation & device debugging |
| **Node.js** | `18.x` | `20.x LTS` | `node -v` | Vercel serverless push notification gateway |
| **Python** | `3.10.x` | `3.11.x` | `python --version` | Document OCR verification & scraper scripts |
| **Firebase CLI** | `12.x` | Latest stable | `firebase --version` | Firebase deployment & rules management |
| **FlutterFire CLI** | `0.3.0+` | Latest stable | `flutterfire --version` | Firebase options generation |
| **Shorebird CLI** | Optional | Latest stable | `shorebird --version` | Over-the-air code push deployment |

---

## 2. Repository Cloning & Flutter Client Setup

### Step 2.1: Clone the Repository
```bash
git clone https://github.com/Silvermax12/run-campus-connect.git
cd run_campus_connect
```

### Step 2.2: Install Flutter Package Dependencies
Run `flutter pub get` from the root workspace directory to resolve and install all packages declared in `pubspec.yaml`:
```bash
flutter pub get
```

### Step 2.3: Generate Riverpod & Mockito Code
The application relies on `riverpod_generator` and `mockito` to synthesize type-safe providers, async state containers, and mock implementations. Execute `build_runner`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

> [!TIP]
> During active feature development, run the build runner in watch mode to automatically recompile companion files upon saving:
> ```bash
> dart run build_runner watch --delete-conflicting-outputs
> ```

---

## 3. Firebase Cloud Configuration

The platform connects to the Firebase project **`run-campus-connect`**.

### Step 3.1: Firebase Project Services Activation
Ensure the following services are enabled in the [Firebase Console](https://console.firebase.google.com/project/run-campus-connect/overview):
1. **Authentication**:
   - **Email/Password**: Enabled (supports standard student accounts).
   - **Google Sign-In**: Enabled. You must configure the OAuth 2.0 Web Client ID and add Android SHA-1 fingerprints.
2. **Cloud Firestore**:
   - Database created in production or test mode.
   - Region: `europe-west` or `us-central1` (matching existing project).
3. **Firebase Cloud Messaging (FCM)**:
   - Enabled for Android and iOS clients.
4. **Firebase Remote Config**:
   - Initialized with default update parameters (see Section 6).

### Step 3.2: Configure Google Sign-In Fingerprints (Android)
To enable Google Sign-In on local Android emulators or physical hardware:
1. Extract your local debug keystore SHA-1 and SHA-256 fingerprints:
   ```bash
   # Windows (PowerShell)
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
2. In the Firebase Console, navigate to **Project Settings** → **Your Apps** → **Android (`com.run.campus_connect`)**.
3. Add the SHA-1 and SHA-256 certificate fingerprints.
4. Download the updated `google-services.json` and replace `android/app/google-services.json`.

### Step 3.3: Regenerate Firebase Options (If Needed)
If you switch to a development or staging Firebase project, reconfigure the Dart bindings:
```bash
flutterfire configure --project=run-campus-connect
```
This updates `lib/firebase_options.dart` and `firebase.json`.

### Step 3.4: Deploy Security Rules
Deploy Firestore and Storage security rules to enforce access controls:
```bash
firebase deploy --only firestore:rules,storage:rules
```

---

## 4. Python FastAPI Document Verification Setup

The OCR microservice handles freshman admission verification using **EasyOCR** and PyTorch.

### Step 4.1: Create and Activate Virtual Environment
```bash
cd python_backend

# Windows (PowerShell)
python -m venv venv
.\venv\Scripts\Activate.ps1

# macOS / Linux
python3 -m venv venv
source venv/bin/activate
```

### Step 4.2: Install Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

> [!NOTE]
> EasyOCR relies on PyTorch. The default `requirements.txt` installs CPU-compatible PyTorch wheels. For GPU acceleration on machines with NVIDIA CUDA, install the CUDA-enabled PyTorch build from [pytorch.org](https://pytorch.org).

### Step 4.3: Service Account Key Installation
1. Go to Firebase Console → **Project Settings** → **Service Accounts**.
2. Click **Generate New Private Key**.
3. Save the JSON file as `serviceAccountKey.json` inside the `python_backend/` directory:
   ```
   run_campus_connect/
   └── python_backend/
       └── serviceAccountKey.json   <-- Placed here (gitignored)
   ```

### Step 4.4: Configure Environment Variables
Create a `.env` file inside `python_backend/`:
```env
CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@de0zo490s
```

### Step 4.5: Launch the Verification Server
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
- The service will start at `http://127.0.0.1:8000`.
- Verify the service is operational:
  ```bash
  curl http://127.0.0.1:8000/
  # Expected: {"service":"RUN Campus Connect – Document Verification API","status":"running","version":"1.0.0"}
  ```
- Interactive Swagger UI documentation is available at `http://127.0.0.1:8000/docs`.

---

## 5. Vercel Serverless Notification Gateway Setup

The Vercel functions (`vercel_functions/`) act as the secure push notification dispatch gateway, ensuring Firebase Admin server credentials remain off mobile devices.

### Step 5.1: Install Node Dependencies
```bash
cd vercel_functions
npm install
```

### Step 5.2: Configure Local Environment Variables
Copy `.env.example` to `.env.local`:
```bash
cp .env.example .env.local
```
Edit `.env.local` with the following variables:
```env
# Single-line JSON string representation of your Firebase Service Account
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"run-campus-connect",...}

# Cloudinary connection string for asset deletion
CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@de0zo490s
```

### Step 5.3: Run Vercel Serverless Functions Locally
```bash
npx vercel dev
```
By default, Vercel will host the serverless endpoints on `http://localhost:3000`.

### Step 5.4: Deploy to Vercel Production
```bash
npx vercel --prod
```
After deployment, copy your assigned Vercel URL (e.g., `https://run-campus-connect.vercel.app`) and verify it matches `lib/core/config/app_config.dart`:
```dart
static const String vercelBaseUrl = 'https://run-campus-connect.vercel.app';
```

---

## 6. Cloudinary Configuration

Media uploads (avatars, feed images, fresher admission slips) utilize **Cloudinary**.

### Credentials
Configured in `lib/core/config/cloudinary_config.dart`:
```dart
class CloudinaryConfig {
  static const String cloudName = 'de0zo490s';
  static const String uploadPreset = 'run-campus-connect';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
```

Ensure the unsigned upload preset `run-campus-connect` exists in your Cloudinary console with folder target set to `run_campus_posts/`.

---

## 7. Device Execution Workflows

### Scenario A: Physical Android Device via USB
When running the Flutter app on a physical Android phone while hosting the Python verification API on your local PC:
1. Connect device via USB with USB Debugging enabled.
2. Execute ADB reverse port forwarding:
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```
   *This forwards all device requests from `http://127.0.0.1:8000` over the USB cable directly to port 8000 on your development machine.*
3. Run the application:
   ```bash
   flutter run
   ```

### Scenario B: Android Emulator
If running on an Android Emulator:
1. If you run `adb reverse tcp:8000 tcp:8000`, the default `ApiConfig.baseUrl` (`http://127.0.0.1:8000`) will resolve cleanly.
2. If ADB reverse is not used, update `lib/core/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:8000';
   ```
   *(Android emulators use `10.0.2.2` as an alias to the host machine's loopback interface).*

### Scenario C: Offline / Isolated Testing
To prevent Google Fonts CDN download timeouts in offline environments, compile with the system fonts define:
```bash
flutter run --dart-define=USE_SYSTEM_FONTS=true
```

---

## 8. Seeding Test Data & Automated UAT Accounts

To provision a fresh set of realistic test users across all faculties and verification states:
1. Ensure `python_backend/serviceAccountKey.json` is in place.
2. Run the seeding script:
   ```bash
   cd python_backend
   python scripts/seed_uat_accounts.py
   ```
3. This creates or refreshes the following accounts with shared password `UatRunConnect123!`:

| Account Key | Email Address | Assigned Role / Attributes |
| :--- | :--- | :--- |
| `student_a` | `uat.student.a@run.edu.ng` | Engineering / Computer Engineering (Level 300) |
| `student_b` | `uat.student.b@run.edu.ng` | Engineering / Computer Engineering (Level 300) |
| `student_c` | `uat.student.c@run.edu.ng` | Faculty of Law (Level 200) |
| `no_profile` | `uat.noprofile@run.edu.ng` | User with no `users/{uid}` profile document |
| `unverified` | `uat.unverified@run.edu.ng` | User with unconfirmed email address |
| `birthday` | `uat.birthday@run.edu.ng` | Birthday set to current date (triggers birthday bot) |
| `fresher_pending` | `12345678uat@fresher.run.edu.ng` | Fresher pending OCR verification (`isVerified: false`) |
| `fresher_verified` | `87654321uat@fresher.run.edu.ng` | Verified fresher account (`isVerified: true`) |
| `admin` | `ale-alaba12850@run.edu.ng` | System administrator for feedback triage |

---

## 9. Comprehensive Troubleshooting Matrix

| Symptom / Error | Root Cause | Remediation Procedure |
| :--- | :--- | :--- |
| `MissingPluginException(No implementation found for method ...)` | Native platform plugins were added or updated while the app was running. | Perform a full stop, execute `flutter clean`, `flutter pub get`, and rebuild the app. |
| `build_runner` throws conflicting output error | A generated `*.g.dart` file has stale metadata or was modified manually. | Run `dart run build_runner build --delete-conflicting-outputs`. |
| Google Sign-In throws error `12500` or `10` | The Android debug keystore SHA-1 fingerprint is missing from Firebase. | Extract your debug SHA-1 with `keytool` and add it under Firebase Project Settings → Android App. |
| Fresher verification fails with `Connection refused` | Mobile client cannot reach Python backend on port 8000. | Run `adb reverse tcp:8000 tcp:8000` for physical devices, or use `10.0.2.2:8000` on emulators. |
| EasyOCR takes 2–5 minutes on first run | EasyOCR is downloading CRAFT and text recognition weights (~150MB). | Normal behavior on first launch. Subsequent runs will load cached models instantly from `~/.EasyOCR/model`. |
| Vercel push fails with `401 Unauthorized` | Invalid or expired Firebase ID token sent in `Authorization` header. | Verify the caller is authenticated via `FirebaseAuth.instance.currentUser?.getIdToken()`. |
| Push notification not displayed in foreground | System heads-up alerts are intentionally suppressed when app is resumed. | Expected behavior. Look at in-app unread badges or minimize the app to verify background delivery. |
| Firestore write fails with `PERMISSION_DENIED` | Write violates rules in `firestore.rules` (e.g. non-admin updating status). | Review `firestore.rules` and verify the test user has the appropriate role or ownership. |
