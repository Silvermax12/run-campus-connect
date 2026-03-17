"""
Controller to run institutional scrapers and upload to Firestore *only if changed*.

Scrapers:
  - gov.py              -> run_governance/governance
  - history.py          -> run_our_history/our_history
  - vis_mis_stra.py     -> run_vision_mission/vision_mission
  - moto,logo,anth.py   -> run_motto_logo_anthem/motto_logo_anthem

Caching:
  - Uses a local JSON hash cache so we can skip Firebase initialization and writes
    when content has not changed.

Usage:
  python institutional_controller.py
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from datetime import datetime, timezone
from typing import Any, Callable

import firebase_admin
from firebase_admin import credentials, firestore


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PYTHON_BACKEND_DIR = os.path.dirname(SCRIPT_DIR)
SERVICE_ACCOUNT_PATH = os.path.join(PYTHON_BACKEND_DIR, "serviceAccountKey.json")
CACHE_FILE_PATH = os.path.join(SCRIPT_DIR, "institutional_cache.json")


URL_GOV = "https://run.edu.ng/governance/"
URL_HISTORY = "https://run.edu.ng/our-history/"
URL_VMS = "https://run.edu.ng/vision-mission-strategy/"
URL_MLA = "https://run.edu.ng/motto-logo-anthem/"


def _load_module_from_path(module_name: str, file_path: str):
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module {module_name} from {file_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


def load_cache() -> dict[str, str]:
    if os.path.exists(CACHE_FILE_PATH):
        try:
            with open(CACHE_FILE_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data if isinstance(data, dict) else {}
        except Exception:
            return {}
    return {}


def save_cache(cache: dict[str, str]) -> None:
    with open(CACHE_FILE_PATH, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)


def content_hash(data: dict) -> str:
    stable = {k: v for k, v in data.items() if k not in ("scrapedAt", "scrapedTime", "last_updated")}
    raw = json.dumps(stable, sort_keys=True, default=str)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def has_changed(cache: dict[str, str], cache_key: str, data: dict) -> bool:
    new_hash = content_hash(data)
    if cache.get(cache_key) == new_hash:
        return False
    cache[cache_key] = new_hash
    return True


def init_firestore():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        raise FileNotFoundError(
            f"serviceAccountKey.json NOT FOUND at {SERVICE_ACCOUNT_PATH}"
        )
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def _as_lines(text: str) -> list[str]:
    return [ln.strip() for ln in (text or "").split("\n") if ln.strip()]


def normalize_governance(raw: dict[str, Any]) -> dict[str, Any]:
    officers = raw.get("officers") or []
    senate = raw.get("senate") or []

    team_members = []
    if isinstance(officers, list):
        for o in officers:
            if not isinstance(o, dict):
                continue
            team_members.append(
                {
                    "name": o.get("name", ""),
                    "role": o.get("role", ""),
                    "imageUrl": o.get("image_url", "") if o.get("image_url") != "No Image" else "",
                    "bio": "",
                }
            )

    senate_members = []
    if isinstance(senate, list):
        for s in senate:
            if not isinstance(s, dict):
                continue
            senate_members.append(
                {
                    "name": s.get("name", ""),
                    "position": s.get("designation", ""),
                }
            )

    return {
        "url": URL_GOV,
        "teamMembers": team_members,
        "boardOfTrustees": [],
        "governingCouncil": [],
        "senateMembers": senate_members,
        "scrapedAt": datetime.now(timezone.utc),
    }


def normalize_history(raw: dict[str, Any]) -> dict[str, Any]:
    blocks = raw.get("blocks") or []
    paragraphs: list[str] = []
    image_urls: list[str] = []

    if isinstance(blocks, list):
        for b in blocks:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text":
                content = b.get("content")
                if isinstance(content, list):
                    paragraphs.extend([str(p).strip() for p in content if str(p).strip()])
            elif b.get("type") == "image":
                url = b.get("url")
                if isinstance(url, str) and url.strip():
                    image_urls.append(url.strip())

    return {
        "url": URL_HISTORY,
        "fullHistory": "\n".join(paragraphs),
        "imageUrls": image_urls,
        "scrapedAt": datetime.now(timezone.utc),
    }


def normalize_vision_mission(raw: dict[str, Any]) -> dict[str, Any]:
    strategy_list = raw.get("vision_strategy") or []
    if isinstance(strategy_list, list):
        strategy = "\n".join([str(p).strip() for p in strategy_list if str(p).strip()])
    else:
        strategy = str(strategy_list or "").strip()

    return {
        "url": URL_VMS,
        "visionStatement": str(raw.get("vision", "") or "").strip(),
        "missionStatement": str(raw.get("mission", "") or "").strip(),
        "visionStrategy": strategy,
        "scrapedAt": datetime.now(timezone.utc),
    }


def normalize_motto_logo_anthem(raw: dict[str, Any]) -> dict[str, Any]:
    image_urls: list[str] = []

    logo_section = raw.get("logo_section") or {}
    if isinstance(logo_section, dict):
        imgs = logo_section.get("images")
        if isinstance(imgs, list):
            image_urls.extend([str(u).strip() for u in imgs if str(u).strip()])

    color_identity = raw.get("color_identity") or {}
    if isinstance(color_identity, dict):
        details = color_identity.get("details")
        if isinstance(details, list):
            for d in details:
                if isinstance(d, dict) and d.get("image_url"):
                    image_urls.append(str(d["image_url"]).strip())

    # Build a readable fullContent string for the Flutter screen.
    parts: list[str] = []
    motto_section = raw.get("motto_section") or []
    if isinstance(motto_section, list):
        parts.extend([str(p).strip() for p in motto_section if str(p).strip()])

    if isinstance(logo_section, dict):
        desc = str(logo_section.get("description", "") or "").strip()
        if desc:
            parts.append("")
            parts.append("Logo")
            parts.append(desc)

    if isinstance(color_identity, dict):
        main_text = str(color_identity.get("main_text", "") or "").strip()
        if main_text:
            parts.append("")
            parts.append("Colours")
            parts.append(main_text)

        details = color_identity.get("details") or []
        if isinstance(details, list) and details:
            for d in details:
                if not isinstance(d, dict):
                    continue
                desc = str(d.get("description", "") or "").strip()
                if desc:
                    parts.append(f"- {desc}")

    anthem = raw.get("anthem") or []
    if isinstance(anthem, list) and anthem:
        parts.append("")
        parts.append("Anthem")
        parts.extend([str(l).strip() for l in anthem if str(l).strip()])

    # De-dupe image URLs while preserving order
    seen = set()
    uniq_images: list[str] = []
    for u in image_urls:
        if u and u not in seen:
            seen.add(u)
            uniq_images.append(u)

    return {
        "url": URL_MLA,
        "fullContent": "\n".join(parts).strip(),
        "imageUrls": uniq_images,
        "scrapedAt": datetime.now(timezone.utc),
    }


def _run_scraper(fn: Callable[[str], dict], url: str) -> dict[str, Any]:
    data = fn(url)
    if not isinstance(data, dict):
        return {"error": "Scraper did not return a dict"}
    return data


def main() -> int:
    cache = load_cache()

    gov_mod = _load_module_from_path("gov_scraper", os.path.join(SCRIPT_DIR, "gov.py"))
    hist_mod = _load_module_from_path("history_scraper", os.path.join(SCRIPT_DIR, "history.py"))
    vms_mod = _load_module_from_path("vms_scraper", os.path.join(SCRIPT_DIR, "vis_mis_stra.py"))
    mla_mod = _load_module_from_path("mla_scraper", os.path.join(SCRIPT_DIR, "moto,logo,anth.py"))

    raw_gov = _run_scraper(gov_mod.scrape_governance_live, URL_GOV)
    raw_hist = _run_scraper(hist_mod.scrape_campus_history_precise, URL_HISTORY)
    raw_vms = _run_scraper(vms_mod.scrape_vision_mission_strategy_final, URL_VMS)
    raw_mla = _run_scraper(mla_mod.scrape_motto_logo_anthem_complete, URL_MLA)

    jobs: list[tuple[str, str, dict[str, Any]]] = []

    if "error" not in raw_gov:
        jobs.append(("run_governance", "governance", normalize_governance(raw_gov)))
    if "error" not in raw_hist:
        jobs.append(("run_our_history", "our_history", normalize_history(raw_hist)))
    if "error" not in raw_vms:
        jobs.append(("run_vision_mission", "vision_mission", normalize_vision_mission(raw_vms)))
    if "error" not in raw_mla:
        jobs.append(("run_motto_logo_anthem", "motto_logo_anthem", normalize_motto_logo_anthem(raw_mla)))

    to_write: list[tuple[str, str, dict[str, Any]]] = []
    for collection, doc_id, payload in jobs:
        cache_key = f"{collection}/{doc_id}"
        if has_changed(cache, cache_key, payload):
            to_write.append((collection, doc_id, payload))

    # If nothing changed, don't touch Firebase at all.
    if not to_write:
        print("No changes detected. Skipping Firebase initialization/writes.")
        save_cache(cache)
        return 0

    db = init_firestore()
    written = 0
    for collection, doc_id, payload in to_write:
        db.collection(collection).document(doc_id).set(payload)
        written += 1
        print(f"Wrote {collection}/{doc_id}")

    save_cache(cache)
    print(f"Done. Updated {written} document(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

