import admin from 'firebase-admin';
import { v2 as cloudinary } from 'cloudinary';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT),
    ),
  });
}

if (process.env.CLOUDINARY_URL) {
  cloudinary.config({ secure: true });
}

/**
 * POST /api/delete-cloudinary-asset
 *
 * Headers:
 *   Authorization: Bearer <Firebase ID Token>
 *   Content-Type: application/json
 *
 * Body:
 *   { "publicId": "run_campus_posts/abc123" }
 */
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const authHeader = req.headers.authorization ?? '';
  const idToken = authHeader.startsWith('Bearer ')
    ? authHeader.split('Bearer ')[1]
    : null;

  if (!idToken) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }

  try {
    await admin.auth().verifyIdToken(idToken);
  } catch (err) {
    console.error('[Cloudinary] Invalid ID token:', err.message);
    return res.status(401).json({ error: 'Invalid or expired ID token' });
  }

  const publicId = req.body?.publicId;
  if (!publicId || typeof publicId !== 'string') {
    return res.status(400).json({ error: 'publicId is required' });
  }

  if (!process.env.CLOUDINARY_URL) {
    return res.status(500).json({ error: 'CLOUDINARY_URL is not configured' });
  }

  try {
    const result = await cloudinary.uploader.destroy(publicId);
    return res.status(200).json({ result });
  } catch (err) {
    console.error('[Cloudinary] Delete failed:', err.message);
    return res.status(500).json({ error: 'Failed to delete Cloudinary asset' });
  }
}
