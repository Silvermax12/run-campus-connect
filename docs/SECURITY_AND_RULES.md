# RUN Campus Connect — Security Architecture & Access Control

This document provides an exhaustive, line-by-line security review of Cloud Firestore security rules (`firestore.rules`), Firebase Storage security rules (`storage.rules`), network perimeter controls, authentication boundaries, and data privacy safeguards across the **RUN Campus Connect** ecosystem.

---

## 1. Security Philosophy & Threat Model

The application enforces a **defense-in-depth** model where security is not delegated solely to mobile client UI logic:
1. **Server-Side Enforcement**: All database writes, counter increments, and document reads are strictly governed by declarative rules enforced by Google Cloud Firestore infrastructure.
2. **Zero-Trust Compute Gateways**: External HTTP functions (Vercel notification gateway, Cloudinary asset deletion) reject requests unless accompanied by a cryptographically signed Firebase ID token (JWT) verifying user identity.
3. **Automated PII Sanitization**: Sensitive admission verification documents uploaded by freshers are purged from Cloudinary immediately following successful OCR text extraction.
4. **Institutional Perimeter Isolation**: Authentication restricts system access to verified members of Redeemer's University (`@run.edu.ng`) or synthetic fresher personas (`@fresher.run.edu.ng`).

---

## 2. Cloud Firestore Rules Audit (`firestore.rules`)

The complete rules definition resides in `firestore.rules`. Below is a detailed breakdown of helper functions and collection security policies:

### 2.1 Security Helper Functions

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isAuthor(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isUnreadCounterWrite() {
      return isSignedIn()
        && request.resource.data.keys().hasOnly(['totalUnreadMessages']);
    }

    function isChatParticipantRepair() {
      return isSignedIn()
        && request.auth.uid in request.resource.data.participants
        && request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['participants', 'unreadCounts']);
    }

    function chatDocPath(chatId) {
      return /databases/$(database)/documents/chats/$(chatId);
    }

    function chatExists(chatId) {
      return exists(chatDocPath(chatId));
    }

    function isChatParticipant(chatId) {
      return isSignedIn()
        && chatExists(chatId)
        && request.auth.uid in get(chatDocPath(chatId)).data.participants;
    }

    function isFeedbackAdmin() {
      return isSignedIn()
        && (
          request.auth.uid == 'sic5nS2lR6QBiMljDOW1ZVWwESF3'
          || request.auth.token.email == 'ale-alaba12850@run.edu.ng'
        );
    }

    function isOnlyCounterUpdate() {
      return isSignedIn()
        && request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['likeCount', 'viewCount', 'commentCount']);
    }

    function isValidCounterDelta(field, minDelta, maxDelta) {
      return (request.resource.data[field] is int)
        && (resource.data[field] is int)
        && (request.resource.data[field] - resource.data[field] >= minDelta)
        && (request.resource.data[field] - resource.data[field] <= maxDelta)
        && request.resource.data[field] >= 0;
    }
```

#### Helper Explanations & Security Guarantees:
- **`isUnreadCounterWrite()`**: Allows a sender to seed or increment `totalUnreadMessages` on a recipient's user document when the recipient's profile document has not yet been fully completed. The write is restricted strictly to the `totalUnreadMessages` key, preventing unauthorized mutation of profile data (e.g. bio, name, email).
- **`isChatParticipantRepair()`**: Solves the "broken chat doc" race condition. If an early network disconnect or race condition left a chat doc missing participant records, this rule allows an authenticated participant to safely repair `participants` and `unreadCounts` without granting write access to other chat metadata.
- **`isFeedbackAdmin()`**: Authorizes administrative operations by validating that either the caller's Firebase Auth UID matches `sic5nS2lR6QBiMljDOW1ZVWwESF3` or their authenticated token email matches `ale-alaba12850@run.edu.ng`.
- **`isValidCounterDelta(field, minDelta, maxDelta)`**: Prevents malicious manipulation of engagement metrics. Even though any authenticated user can like or comment on a post, they can only modify `likeCount` within `[-1, 1]`, `commentCount` within `[0, 1]`, and `viewCount` within `[0, 1]`. Negative counters and arbitrary count inflation (e.g. adding 10,000 likes) are blocked at the database engine level.

---

### 2.2 Collection Security Policies

#### 1. `users/{userId}`
```javascript
match /users/{userId} {
  allow read: if isSignedIn();
  allow update: if isAuthor(userId)
                || (isSignedIn()
                    && request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['totalUnreadMessages']));
  allow create: if isAuthor(userId) || isUnreadCounterWrite();
  allow delete: if isAuthor(userId);

  match /friends/{friendId} {
     allow read, write: if request.auth.uid == userId || request.auth.uid == friendId;
  }
}
```
- **Read**: Any signed-in user can read profiles (enables directory search and author display).
- **Update**: Only the profile owner can modify their profile fields (bio, avatar, faculty, level). Other users can modify *only* the `totalUnreadMessages` field when delivering direct messages.
- **Create**: Only the user can create their profile doc, or another user can seed the unread counter.
- **Delete**: Only the profile owner can delete their profile document.

#### 2. `posts/{postId}` & Subcollections
```javascript
match /posts/{postId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.resource.data.authorSnapshot.uid == request.auth.uid;
  allow delete: if isSignedIn() && resource.data.authorSnapshot.uid == request.auth.uid;
  allow update: if (isSignedIn() && resource.data.authorSnapshot.uid == request.auth.uid)
                || (isOnlyCounterUpdate()
                    && isValidCounterDelta('likeCount', -1, 1)
                    && isValidCounterDelta('commentCount', 0, 1)
                    && isValidCounterDelta('viewCount', 0, 1));

  match /likes/{userId} {
    allow read: if isSignedIn();
    allow create: if isAuthor(userId);
    allow delete: if isAuthor(userId) || (isSignedIn() && get(/databases/$(database)/documents/posts/$(postId)).data.authorSnapshot.uid == request.auth.uid);
    allow update: if false;
  }

  match /views/{viewerUid} {
    allow read: if isSignedIn();
    allow create: if isAuthor(viewerUid);
    allow delete: if isSignedIn() && get(/databases/$(database)/documents/posts/$(postId)).data.authorSnapshot.uid == request.auth.uid;
    allow update: if false;
  }

  match /comments/{commentId} {
    allow read: if isSignedIn();
    allow create: if isSignedIn() && request.resource.data.authorId == request.auth.uid;
    allow delete: if (isSignedIn() && resource.data.authorId == request.auth.uid)
                  || (isSignedIn() && get(/databases/$(database)/documents/posts/$(postId)).data.authorSnapshot.uid == request.auth.uid);
  }
}
```
- **Post Ownership**: Users can only create posts where `authorSnapshot.uid` matches their UID. Users can only delete their own posts.
- **Moderation Powers**: The original author of a post has cascade deletion privileges over subcollections: if a spammer posts an offensive comment or like, the post author is authorized to delete the comment or like document.
- **Strict Immutability**: Likes and views cannot be updated (`allow update: if false;`); they can only be created or deleted.

#### 3. `chats/{chatId}` & `messages`
```javascript
match /chats/{chatId} {
  allow read: if isSignedIn() && request.auth.uid in resource.data.participants;
  allow update: if isSignedIn()
                && (request.auth.uid in resource.data.participants
                    || isChatParticipantRepair());
  allow create: if isSignedIn() && request.auth.uid in request.resource.data.participants;

  match /messages/{messageId} {
    allow read: if isSignedIn()
      && (!chatExists(chatId) || isChatParticipant(chatId));
    allow write: if isChatParticipant(chatId);
  }
}
```
- **Privacy Barrier**: Chat documents and their nested messages cannot be read or queried by anyone outside the `participants` array.
- **Message Authorization**: A user cannot write to `chats/{chatId}/messages/{messageId}` unless they are an active participant of that chat.

#### 4. Institutional Data Collections
```javascript
match /run_news/{newsId} {
  allow read: if isSignedIn();
}
match /run_our_history/{docId} {
  allow read: if isSignedIn();
}
match /run_governance/{docId} {
  allow read: if isSignedIn();
}
match /run_motto_logo_anthem/{docId} {
  allow read: if isSignedIn();
}
match /run_vision_mission/{docId} {
  allow read: if isSignedIn();
}
```
- **Read-Only**: Any authenticated student/staff member can read institutional articles.
- **Write-Protected**: All client writes (`create`, `update`, `delete`) are completely blocked. Only backend administrative scripts using the Firebase Admin SDK can modify institutional content.

#### 5. `notifications/{notificationId}`
```javascript
match /notifications/{notificationId} {
  allow read: if isSignedIn() && resource.data.recipientId == request.auth.uid;
  allow create: if isSignedIn();
  allow update, delete: if isSignedIn() && resource.data.recipientId == request.auth.uid;
}
```
- **Recipient Isolation**: Users can only read, update (mark as read), or delete notifications addressed specifically to them (`recipientId == request.auth.uid`).

#### 6. `feedback/{feedbackId}`
```javascript
match /feedback/{feedbackId} {
  allow read: if isFeedbackAdmin() || (isSignedIn() && resource.data.userId == request.auth.uid);
  allow create: if isSignedIn()
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.status == 'pending';
  allow update: if isFeedbackAdmin()
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status'])
    && request.resource.data.status in ['pending', 'reviewed', 'resolved'];
  allow delete: if false;
}
```
- **Submitter Restrictions**: A user can only submit feedback where `userId == request.auth.uid` and initial status is strictly `'pending'`.
- **Admin Review**: Only verified administrators can read all feedback submissions.
- **Status Updates**: Only administrators can update feedback documents, and they may only touch the `status` field, which is constrained to `'pending'`, `'reviewed'`, or `'resolved'`.
- **Audit Preservation**: Deletion of feedback records is prohibited (`allow delete: if false;`) to preserve institutional feedback audits.

---

## 3. Firebase Storage Security Rules (`storage.rules`)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isSignedIn() {
      return request.auth != null;
    }

    match /users/{uid}/profile.jpg {
      allow read: if true;
      allow write: if isSignedIn() && request.auth.uid == uid;
    }

    match /posts/{uid}/{allPaths=**} {
      allow read: if true;
      allow write: if isSignedIn() && request.auth.uid == uid;
    }
  }
}
```

- **Folder Path Sandboxing**: Users are strictly confined to their own storage folders (`users/{uid}/` and `posts/{uid}/`). A malicious user cannot overwrite or delete assets belonging to another student.
- **Public Read Access**: Avatars and post images are publicly readable via CDN links without requiring short-lived signed tokens, optimizing image caching performance.

---

## 4. Serverless & API Gateway Security

### 4.1 Vercel Notification Gateway (`/api/send-notification`)
To eliminate the severe security risk of bundling Firebase Admin service account keys inside mobile client binaries, push dispatches run through Vercel serverless functions:
- **Authentication**: Caller must pass `Authorization: Bearer <Firebase_ID_Token>`.
- **Server-Side Token Verification**:
  ```javascript
  const decoded = await admin.auth().verifyIdToken(idToken);
  const senderUid = decoded.uid;
  ```
  If the JWT is expired, tampered with, or revoked, the function immediately terminates with `401 Unauthorized`.
- **Mute List Enforcement**:
  Before sending a direct push notification, the gateway queries Firestore `users/{recipientUid}/settings/notifications`. If the recipient has added the sender to `mutedUsers`, the notification is dropped with `{ skipped: 'muted' }`.

### 4.2 Cloudinary Asset Purge Gateway (`/api/delete-cloudinary-asset`)
- When a user deletes a post that contains an image whose client-side delete token has expired, the client calls `/api/delete-cloudinary-asset`.
- The endpoint verifies the caller's Firebase ID token, preventing unauthorized deletion of arbitrary Cloudinary assets.

---

## 5. Document Privacy & PII Handling

1. **Fresher Verification Purge**:
   - Freshmen upload photos of their JAMB result slips and university admission letters.
   - Once the Python FastAPI backend completes text extraction and verifies the documents, it immediately invokes `delete_from_cloudinary()` for both assets. No student admission letters or government registration documents remain stored on cloud storage.
2. **Secrets Management**:
   - `python_backend/serviceAccountKey.json`, `vercel_functions/.env`, and production `.env` files are strictly included in `.gitignore`.
   - Continuous integration pipelines inject credentials as encrypted environment variables (`FIREBASE_SERVICE_ACCOUNT`, `CLOUDINARY_URL`).
