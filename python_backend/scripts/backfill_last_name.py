"""
One-time migration: backfill `lastName` for existing users in the `users` collection.
Run this once to enable search-by-last-name for users created before the feature was added.

Usage (from python_backend/ with venv activated):
    python scripts/backfill_last_name.py

Requires serviceAccountKey.json in python_backend/ (same as other scripts).
Requires: pip install firebase-admin
"""
import re

import firebase_admin
from firebase_admin import credentials, firestore


def init_firebase():
    # serviceAccountKey.json lives in python_backend/ when run as python scripts/backfill_last_name.py
    cred = credentials.Certificate('serviceAccountKey.json')
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    return firestore.client()


def derive_last_name(display_name: str) -> str:
    """Extract last name from full display name."""
    if not display_name or not display_name.strip():
        return display_name or ''
    parts = re.split(r'\s+', display_name.strip())
    return parts[-1] if parts else display_name


def main():
    db = init_firebase()
    users_ref = db.collection('users')
    docs = users_ref.stream()

    updated = 0
    skipped = 0
    for doc in docs:
        data = doc.to_dict()
        display_name = data.get('displayName', '') or ''
        existing_last = data.get('lastName')

        if existing_last is not None and str(existing_last).strip():
            skipped += 1
            continue

        last_name = derive_last_name(display_name)
        if last_name:
            doc.reference.update({'lastName': last_name})
            print(f"Updated {doc.id}: lastName = '{last_name}' (from displayName '{display_name}')")
            updated += 1
        else:
            skipped += 1

    print(f"\nDone. Updated {updated} users, skipped {skipped}.")


if __name__ == '__main__':
    main()
