"""
FastAPI backend for verifying student admission documents via OCR.

Flow:
  1. Receive uid, jambNumber, fullName, slipUrl, admissionUrl
  2. Download both images from Cloudinary into memory
  3. Run EasyOCR on both images
  4. Validate that extracted text contains the JAMB number and university name
  5. If valid → update Firestore (isVerified = true)
  6. Delete both images from Cloudinary to save space
"""

import io
import os
import re
import logging
from urllib.parse import urlparse

import cloudinary
import cloudinary.uploader
import easyocr
import firebase_admin
import requests as http_requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore
from PIL import Image
from pydantic import BaseModel

# ─── Load environment variables ──────────────────────────────────────────────
load_dotenv()

# ─── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─── FastAPI App ─────────────────────────────────────────────────────────────
app = FastAPI(
    title="RUN Campus Connect – Document Verification API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Cloudinary ──────────────────────────────────────────────────────────────
# The CLOUDINARY_URL env var is automatically picked up by the SDK.
# Format: cloudinary://API_KEY:API_SECRET@CLOUD_NAME
cloudinary_url = os.getenv("CLOUDINARY_URL")
if not cloudinary_url:
    logger.warning("CLOUDINARY_URL not set – Cloudinary cleanup will fail.")

# ─── Firebase Admin ──────────────────────────────────────────────────────────
SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")

if os.path.exists(SERVICE_ACCOUNT_PATH):
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    logger.info("Firebase Admin SDK initialised successfully.")
else:
    db = None
    logger.error(
        "serviceAccountKey.json NOT FOUND at %s – Firebase writes will fail.",
        SERVICE_ACCOUNT_PATH,
    )

# ─── EasyOCR Reader (loaded once at startup) ────────────────────────────────
logger.info("Loading EasyOCR reader (this may take a moment on first run)...")
reader = easyocr.Reader(["en"], gpu=False)
logger.info("EasyOCR reader ready.")


# ─── Pydantic Models ────────────────────────────────────────────────────────
class VerifyRequest(BaseModel):
    uid: str
    jambNumber: str
    fullName: str
    slipUrl: str
    admissionUrl: str


class VerifyResponse(BaseModel):
    success: bool
    message: str


# ─── Helpers ─────────────────────────────────────────────────────────────────


def download_image(url: str) -> bytes:
    """Download an image from a URL and return raw bytes."""
    resp = http_requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.content


def extract_text(image_bytes: bytes) -> str:
    """Run EasyOCR on raw image bytes and return joined text."""
    image = Image.open(io.BytesIO(image_bytes))
    # Convert to RGB in case the image has an alpha channel
    image = image.convert("RGB")

    # EasyOCR accepts numpy arrays, PIL images, or file paths.
    # Convert to numpy via a buffer for maximum compatibility.
    import numpy as np

    img_array = np.array(image)
    results = reader.readtext(img_array, detail=0)
    text = " ".join(results)
    logger.info("OCR extracted text (%d chars): %s", len(text), text[:200])
    return text


def extract_public_id(cloudinary_url: str) -> str | None:
    """
    Extract the Cloudinary public_id from a secure URL.

    Example URL:
      https://res.cloudinary.com/de0zo490s/image/upload/v1234567890/run_campus_posts/abc123.jpg
    Returns:
      run_campus_posts/abc123
    """
    try:
        parsed = urlparse(cloudinary_url)
        path = parsed.path  # /de0zo490s/image/upload/v1234567890/folder/file.jpg

        # Find the version segment (v followed by digits) and take everything after it
        match = re.search(r"/v\d+/(.+)$", path)
        if match:
            public_id_with_ext = match.group(1)
        else:
            # Fallback: take everything after /upload/
            match = re.search(r"/upload/(.+)$", path)
            if match:
                public_id_with_ext = match.group(1)
            else:
                logger.warning("Could not parse public_id from URL: %s", cloudinary_url)
                return None

        # Strip file extension
        public_id = os.path.splitext(public_id_with_ext)[0]
        return public_id
    except Exception as e:
        logger.error("Error extracting public_id: %s", e)
        return None


def delete_from_cloudinary(url: str) -> bool:
    """Delete an asset from Cloudinary by its URL. Returns True on success."""
    public_id = extract_public_id(url)
    if not public_id:
        logger.warning("Skipping Cloudinary delete – could not extract public_id from: %s", url)
        return False

    logger.info("Deleting Cloudinary asset: %s", public_id)
    result = cloudinary.uploader.destroy(public_id)
    success = result.get("result") == "ok"
    if success:
        logger.info("Successfully deleted: %s", public_id)
    else:
        logger.warning("Cloudinary delete returned: %s for %s", result, public_id)
    return success


# ─── Routes ──────────────────────────────────────────────────────────────────


@app.get("/")
def root():
    return {
        "service": "RUN Campus Connect – Document Verification API",
        "status": "running",
        "version": "1.0.0",
    }


@app.post("/verify", response_model=VerifyResponse)
def verify_documents(payload: VerifyRequest):
    """
    Verify a student's admission documents:
      1. Download slip + admission letter images
      2. OCR both images
      3. Check for JAMB number and university name
      4. Update Firestore → isVerified = true
      5. Delete images from Cloudinary
    """

    if db is None:
        raise HTTPException(
            status_code=503,
            detail="Firebase is not initialised. Ensure serviceAccountKey.json is present.",
        )

    # ── Step 1: Download images ──────────────────────────────────────────
    try:
        logger.info("Downloading JAMB slip from: %s", payload.slipUrl)
        slip_bytes = download_image(payload.slipUrl)

        logger.info("Downloading admission letter from: %s", payload.admissionUrl)
        admission_bytes = download_image(payload.admissionUrl)
    except Exception as e:
        logger.error("Failed to download images: %s", e)
        raise HTTPException(status_code=400, detail=f"Failed to download images: {e}")

    # ── Step 2: OCR ──────────────────────────────────────────────────────
    try:
        slip_text = extract_text(slip_bytes)
        admission_text = extract_text(admission_bytes)
    except Exception as e:
        logger.error("OCR failed: %s", e)
        raise HTTPException(status_code=500, detail=f"OCR processing failed: {e}")

    # Combine both texts for searching
    combined_text = f"{slip_text} {admission_text}".lower()
    logger.info("Combined OCR text: %s", combined_text[:300])

    # ── Step 3: Validation ───────────────────────────────────────────────
    jamb_number_lower = payload.jambNumber.lower()

    # Check 1: JAMB number must appear in the documents
    if jamb_number_lower not in combined_text:
        logger.warning("JAMB number '%s' NOT found in OCR text.", payload.jambNumber)
        raise HTTPException(
            status_code=400,
            detail=f"JAMB number '{payload.jambNumber}' was not found in the uploaded documents.",
        )

    # Check 2: University name must appear
    university_keywords = ["redeemer's university", "redeemers university", "redeemer university", "run"]
    university_found = any(kw in combined_text for kw in university_keywords)

    if not university_found:
        logger.warning("University name not found in OCR text.")
        raise HTTPException(
            status_code=400,
            detail="Could not verify the documents belong to Redeemer's University (RUN).",
        )

    logger.info("✅ Validation passed for JAMB %s", payload.jambNumber)

    # ── Step 4: Update Firestore ─────────────────────────────────────────
    try:
        user_ref = db.collection("users").document(payload.uid)
        user_ref.update({"isVerified": True})
        logger.info("Firestore updated: users/%s → isVerified = true", payload.uid)
    except Exception as e:
        logger.error("Firestore update failed: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to update verification status: {e}")

    # ── Step 5: Cleanup – delete images from Cloudinary ──────────────────
    try:
        delete_from_cloudinary(payload.slipUrl)
        delete_from_cloudinary(payload.admissionUrl)
    except Exception as e:
        # Log but don't fail the request – verification already succeeded
        logger.error("Cloudinary cleanup failed (non-fatal): %s", e)

    return VerifyResponse(
        success=True,
        message=f"Student {payload.fullName} verified successfully. JAMB: {payload.jambNumber}",
    )
