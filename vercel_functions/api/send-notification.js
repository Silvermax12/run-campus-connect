import admin from 'firebase-admin';

// ---------------------------------------------------------------------------
// Global scope — initialized ONCE and reused across warm Lambda invocations.
// This avoids the cold-start penalty on every request.
// ---------------------------------------------------------------------------
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
    ),
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * POST /api/send-notification
 *
 * Headers:
 *   Authorization: Bearer <Firebase ID Token>  ← caller proves who they are
 *   Content-Type: application/json
 *
 * Body (chat DM):
 *   { "type": "chat", "recipientUid": "...", "title": "...", "body": "...", "data": { ... } }
 *
 * Body (topic broadcast):
 *   { "type": "broadcast", "topic": "global", "title": "...", "body": "...", "data": { ... } }
 */
export default async function handler(req, res) {
  // ── Method guard ─────────────────────────────────────────────────────────
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  // ── 1. Verify Firebase ID Token ──────────────────────────────────────────
  const authHeader = req.headers.authorization ?? '';
  const idToken = authHeader.startsWith('Bearer ')
    ? authHeader.split('Bearer ')[1]
    : null;

  if (!idToken) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }

  let senderUid;
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    senderUid = decoded.uid;
  } catch (err) {
    console.error('[FCM] Invalid ID token:', err.message);
    return res.status(401).json({ error: 'Invalid or expired ID token' });
  }

  // ── 2. Parse and validate body ───────────────────────────────────────────
  const { type, recipientUid, topic, title, body, data = {} } = req.body ?? {};

  if (!title || !body) {
    return res.status(400).json({ error: 'title and body are required' });
  }

  // ── 3a. Chat DM — send to a specific device token ────────────────────────
  if (type === 'chat') {
    if (!recipientUid) {
      return res.status(400).json({ error: 'recipientUid required for chat notifications' });
    }

    // Mute check: skip if recipient has muted this sender
    try {
      const settingsSnap = await db
        .collection('users')
        .doc(recipientUid)
        .collection('settings')
        .doc('notifications')
        .get();

      const mutedUsers = settingsSnap.data()?.mutedUsers ?? [];
      if (mutedUsers.includes(senderUid)) {
        console.log(`[FCM] Skipped — ${recipientUid} has muted ${senderUid}`);
        return res.status(200).json({ skipped: 'muted' });
      }
    } catch (err) {
      // Non-fatal: if settings doc doesn't exist, treat as unmuted.
      console.warn('[FCM] Could not read mute settings:', err.message);
    }

    // Fetch recipient's FCM token
    const userSnap = await db.collection('users').doc(recipientUid).get();
    const fcmToken = userSnap.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`[FCM] No FCM token for user ${recipientUid} — skipping`);
      return res.status(200).json({ skipped: 'no_token' });
    }

    try {
      const messageId = await messaging.send({
        token: fcmToken,
        notification: { title, body },
        data: stringifyData(data),
        android: {
          priority: 'high',
          notification: {
            channelId: 'campus_connect_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      });
      console.log(`[FCM] Chat notification sent: ${messageId}`);
      return res.status(200).json({ success: true, messageId });
    } catch (err) {
      console.error('[FCM] Failed to send chat notification:', err.message);
      return res.status(500).json({ error: err.message });
    }
  }

  // ── 3b. Broadcast — send to an FCM topic ─────────────────────────────────
  if (type === 'broadcast') {
    if (!topic) {
      return res.status(400).json({ error: 'topic required for broadcast notifications' });
    }

    // Sanitize topic: only allow alphanumeric + underscore
    const safeTopic = topic.replace(/[^a-zA-Z0-9_]/g, '_');

    try {
      const messageId = await messaging.send({
        topic: safeTopic,
        notification: { title, body },
        data: stringifyData(data),
        android: {
          priority: 'high',
          notification: {
            channelId: 'campus_connect_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      });
      console.log(`[FCM] Broadcast sent to topic "${safeTopic}": ${messageId}`);
      return res.status(200).json({ success: true, messageId });
    } catch (err) {
      console.error('[FCM] Failed to send broadcast:', err.message);
      return res.status(500).json({ error: err.message });
    }
  }

  return res.status(400).json({ error: 'type must be "chat" or "broadcast"' });
}

// ---------------------------------------------------------------------------
// Helper — FCM data payload values must all be strings
// ---------------------------------------------------------------------------
function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );
}
