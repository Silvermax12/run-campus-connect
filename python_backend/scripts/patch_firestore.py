import firebase_admin
from firebase_admin import credentials, firestore

def init_firebase():
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
    return firestore.client()

def clean_text_fallback(text: str) -> str:
    lines = text.strip().split('\n')
    unwanted_exact = {
        "Vision, Mission & Strategy", "Our History", "Motto, Logo & Anthem",
        "Partnership", "Governance", "Directorates & Centres", "Awards & Rankings",
        "TWENTIETH ANNIVERSARY", "Academics", "Admissions"
    }
    cleaned = []
    
    for line in lines:
        cl = line.strip()
        if not cl:
            continue
        if cl in unwanted_exact:
            continue
        cleaned.append(cl)
        
    return '\n\n'.join(cleaned)

def patch_collection(db, coll_name, doc_id, text_field):
    doc_ref = db.collection(coll_name).document(doc_id)
    doc = doc_ref.get()
    
    if doc.exists:
        data = doc.to_dict()
        original_text = data.get(text_field, '')
        
        cleaned_text = clean_text_fallback(original_text)
        
        if original_text != cleaned_text:
            doc_ref.update({text_field: cleaned_text})
            print(f"Updated {coll_name}/{doc_id}")
            print(f"Before length: {len(original_text)}, After length: {len(cleaned_text)}")
        else:
            print(f"No changes needed for {coll_name}/{doc_id}")
    else:
        print(f"Document {coll_name}/{doc_id} not found.")

def main():
    db = init_firebase()
    print("Patching Firestore documents...")
    patch_collection(db, "run_our_history", "our_history", "fullHistory")
    patch_collection(db, "run_governance", "governance", "fullContent")
    patch_collection(db, "run_motto_logo_anthem", "motto_logo_anthem", "fullContent")
    print("Done patching.")

if __name__ == "__main__":
    main()
