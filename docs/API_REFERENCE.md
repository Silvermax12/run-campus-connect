# RUN Campus Connect — API Reference

This document provides the complete API reference for all HTTP microservices, serverless gateways, and native platform channels utilized within the **RUN Campus Connect** ecosystem.

---

## 1. Python FastAPI — Document Verification API

| Parameter | Specification |
| :--- | :--- |
| **Development Base URL** | `http://127.0.0.1:8000` (ADB Reverse) or `http://10.0.2.2:8000` (Emulator) |
| **Configuration File** | `lib/core/config/api_config.dart` |
| **Source File** | `python_backend/main.py` |
| **Interactive Docs** | `http://127.0.0.1:8000/docs` (Swagger UI) |

---

### 1.1 `GET /` — Health Check

Checks whether the verification service is active and the EasyOCR engine is initialized.

- **Method**: `GET`
- **Authentication**: None
- **Response Headers**: `Content-Type: application/json`

#### Success Response (200 OK)
```json
{
  "service": "RUN Campus Connect – Document Verification API",
  "status": "running",
  "version": "1.0.0"
}
```

---

### 1.2 `POST /verify` — Admission Document Verification

Performs optical character recognition on uploaded admission documents, verifies student credentials, updates Firestore, and purges uploaded image files from Cloudinary.

- **Method**: `POST`
- **Authentication**: Public during development (Service account credentials used server-side)
- **Request Headers**: `Content-Type: application/json`

#### Request Body Schema (`VerifyRequest`)

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `uid` | `string` | Yes | Firebase Auth UID of the fresher student. |
| `jambNumber` | `string` | Yes | JAMB registration number entered by user (e.g. `"12345678AB"`). |
| `fullName` | `string` | Yes | Legal name entered during registration. |
| `slipUrl` | `string` | Yes | Secure Cloudinary URL to the uploaded JAMB result slip. |
| `admissionUrl` | `string` | Yes | Secure Cloudinary URL to the uploaded RUN admission letter. |

#### Example Request Payload
```json
{
  "uid": "OpdZOFkPqkUIizf1jZbw2GbMa8K2",
  "jambNumber": "12345678AB",
  "fullName": "John Ade Okafor",
  "slipUrl": "https://res.cloudinary.com/de0zo490s/image/upload/v1717000000/run_campus_posts/slip123.jpg",
  "admissionUrl": "https://res.cloudinary.com/de0zo490s/image/upload/v1717000000/run_campus_posts/adm123.jpg"
}
```

#### Processing Pipeline
1. **Download**: Microservice downloads both images from Cloudinary into in-memory byte buffers via `requests.get()`.
2. **OCR Extraction**: Converts image bytes into RGB NumPy arrays and invokes `easyocr.Reader.readtext()`.
3. **JAMB Validation**: Validates that `jambNumber.lower()` exists as a substring within the combined OCR text.
4. **Institutional Validation**: Validates that at least one university identifier exists: `"redeemer's university"`, `"redeemers university"`, `"redeemer university"`, or `"run"`.
5. **State Update**: Updates Firestore document `users/{uid}` setting `isVerified = true`.
6. **Data Minimization**: Parses Cloudinary public IDs and executes `cloudinary.uploader.destroy()` to permanently delete the document images.

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Student John Ade Okafor verified successfully. JAMB: 12345678AB"
}
```

#### Error Responses

| Status Code | Reason | Example Response Body |
| :--- | :--- | :--- |
| `400 Bad Request` | JAMB number not found in documents | `{"detail": "JAMB number '12345678AB' was not found in the uploaded documents."}` |
| `400 Bad Request` | University name not found | `{"detail": "Could not verify the documents belong to Redeemer's University (RUN)."}` |
| `400 Bad Request` | Image download failed | `{"detail": "Failed to download images: HTTP 404 Not Found"}` |
| `500 Server Error` | OCR engine execution failed | `{"detail": "OCR processing failed: Out of memory"}` |
| `503 Unavailable` | Firebase Admin SDK uninitialized | `{"detail": "Firebase is not initialised. Ensure serviceAccountKey.json is present."}` |

---

## 2. Vercel Serverless Push & Cleanup Gateway

| Parameter | Specification |
| :--- | :--- |
| **Production Base URL** | `https://run-campus-connect.vercel.app` |
| **Configuration File** | `lib/core/config/app_config.dart` |
| **Directory** | `vercel_functions/api/` |
| **Runtime** | Node.js 18.x (AWS Lambda via Vercel) |
| **Max Execution Timeout** | 10 seconds (`vercel.json`) |

---

### 2.1 `POST /api/send-notification`

Dispatches push notifications via Firebase Cloud Messaging using Firebase Admin SDK credentials.

- **Method**: `POST`
- **Authentication**: `Authorization: Bearer <Firebase_ID_Token>` (Required)
- **Request Headers**: `Content-Type: application/json`

#### Action Type A: Direct Chat Push (`type: "chat"`)

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `type` | `string` | Yes | Must be `"chat"`. |
| `recipientUid` | `string` | Yes | Target user's Firebase Auth UID. |
| `title` | `string` | Yes | Notification title (Sender's display name). |
| `body` | `string` | Yes | Message text preview. |
| `data` | `map` | No | Route parameters: `chatId`, `targetUserId`, `messageId`. |

##### Example Request
```json
{
  "type": "chat",
  "recipientUid": "lhl3X8HUc9QgOhv7n6qFln8SWvI2",
  "title": "Jane Doe",
  "body": "Hey! Are you heading to the faculty library?",
  "data": {
    "type": "chat",
    "chatId": "MHQV5D3Z20ZwtwcbcEALnYyet8W2_lhl3X8HUc9QgOhv7n6qFln8SWvI2",
    "targetUserId": "MHQV5D3Z20ZwtwcbcEALnYyet8W2",
    "messageId": "msg_98765"
  }
}
```

##### Server Execution Logic
1. Verifies the sender's Firebase ID token using `admin.auth().verifyIdToken()`.
2. Queries `users/{recipientUid}/settings/notifications`. If the recipient has added the sender to `mutedUsers`, returns `{ "skipped": "muted" }`.
3. Reads `users/{recipientUid}.fcmToken`. If missing, returns `{ "skipped": "no_token" }`.
4. Sends the FCM message to the device token with high priority.
5. Performs server-side delivery marking: executes `FieldValue.arrayUnion(recipientUid)` on `chats/{chatId}/messages/{messageId}.deliveredTo`.

---

#### Action Type B: Topic Broadcast Push (`type: "broadcast"`)

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `type` | `string` | Yes | Must be `"broadcast"`. |
| `topic` | `string` | Yes | Destination FCM topic (e.g. `"global"`, `"faculty_engineering"`). |
| `title` | `string` | Yes | Broadcast alert title. |
| `body` | `string` | Yes | Broadcast body text. |
| `data` | `map` | No | Deep-link parameters: `{ "type": "broadcast" }`. |

##### Example Request
```json
{
  "type": "broadcast",
  "topic": "faculty_computing_and_digital_technology",
  "title": "New Faculty Post",
  "body": "A new departmental seminar schedule was posted.",
  "data": {
    "type": "broadcast"
  }
}
```

---

#### Action Type C: Admin Feedback Alert (`type: "feedback"`)

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `type` | `string` | Yes | Must be `"feedback"`. |
| `recipientUid` | `string` | Yes | Admin UID (`sic5nS2lR6QBiMljDOW1ZVWwESF3`). |
| `title` | `string` | Yes | `"New feedback submitted"`. |
| `body` | `string` | Yes | Submitter name, category, and rating summary. |
| `data` | `map` | No | `{ "type": "feedback", "screen": "feedback" }`. |

---

#### Gateway Response Codes

| Status Code | Cause / Meaning | Response Body |
| :--- | :--- | :--- |
| `200 OK` | Notification successfully dispatched | `{"success": true, "messageId": "projects/run-campus-connect/messages/..."}` |
| `200 OK` | Delivery skipped (recipient muted sender) | `{"skipped": "muted"}` |
| `200 OK` | Delivery skipped (recipient has no token) | `{"skipped": "no_token"}` |
| `400 Bad Request` | Missing required payload parameters | `{"error": "recipientUid required for chat notifications"}` |
| `401 Unauthorized` | Missing or invalid ID token | `{"error": "Invalid or expired ID token"}` |
| `405 Method Not Allowed` | Non-POST HTTP method | `{"error": "Method Not Allowed"}` |
| `500 Server Error` | FCM SDK delivery failure | `{"error": "Requested entity was not found."}` |

---

### 2.2 `POST /api/delete-cloudinary-asset`

Performs authenticated deletion of post images from Cloudinary when an author deletes a post.

- **Method**: `POST`
- **Authentication**: `Authorization: Bearer <Firebase_ID_Token>` (Required)
- **Request Headers**: `Content-Type: application/json`

#### Request Payload
```json
{
  "publicId": "run_campus_posts/a1b2c3d4e5"
}
```

#### Success Response (200 OK)
```json
{
  "result": {
    "result": "ok"
  }
}
```

---

## 3. Android Native Platform Channel (`MethodChannel`)

The application defines a native Android MethodChannel for low-level delta patching operations:

- **Channel Name**: `com.run.campus.connect/installer`
- **Implementation**: Native Kotlin in Android Runner delegating to `libhpatchz.so` via JNI.

### 3.1 Method: `getSourceApkPath`
- **Arguments**: None
- **Returns**: `String` — Absolute filesystem path to the currently running installed base APK (e.g. `/data/app/~~.../com.run.campus_connect-.../base.apk`).

### 3.2 Method: `applyPatch`
Invokes the HPatch differential patching library loaded via JNI to reconstruct a target APK from the installed base APK and a downloaded patch.

- **Arguments**:
  ```dart
  <String, String>{
    'oldFile': '/data/app/.../base.apk',
    'patchFile': '/data/user/0/com.run.campus_connect/app_flutter/diff.patch',
    'outFile': '/data/user/0/com.run.campus_connect/app_flutter/combined_update.apk',
  }
  ```
- **Returns**: `int` — Exit code (0 for success).
- **Exceptions**: Throws `PlatformException` with code `'SPLIT_APK'` if the device uses Google Play Split APKs, or code `'PATCH_FAILED'` on failure.

### 3.3 Method: `installApkSession`
Initiates a standard Android `PackageInstaller` session to install the reconstructed APK file.

- **Arguments**:
  ```dart
  <String, dynamic>{
    'apkPath': '/data/user/0/com.run.campus_connect/app_flutter/combined_update.apk',
  }
  ```
- **Returns**: `void`
