"""
Controller to run institutional scrapers and upload to Firestore *only if changed*.

Scrapers:
  - gov.py              -> run_governance/governance
  - history.py          -> run_our_history/our_history
  - vis_mis_stra.py     -> run_vision_mission/vision_mission
  - moto,logo,anth.py   -> run_motto_logo_anthem/motto_logo_anthem
  - news_scraper.py     -> run_news/{doc_id}

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
COLLECTION_NEWS = "run_news"


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


def _with_common_fields(raw: dict[str, Any], url: str) -> dict[str, Any]:
    """
    Take the raw scraper JSON and add common metadata, without changing
    the existing field structure from the individual scraper modules.

    This is the shape that will be stored in Firestore.
    """
    data = dict(raw)  # shallow copy so we don't mutate the original
    data.setdefault("url", url)
    data["scrapedAt"] = datetime.now(timezone.utc)
    # Drop any top-level error key if present
    data.pop("error", None)
    return data


def normalize_governance(raw: dict[str, Any]) -> dict[str, Any]:
    """
    Governance document structure follows gov.py output:
      {
        \"officers\": [...],
        \"senate\": [...],
        ...
      }
    We simply add common metadata fields like url and scrapedAt.
    """
    return _with_common_fields(raw, URL_GOV)


def normalize_history(raw: dict[str, Any]) -> dict[str, Any]:
    """
    History document structure follows history.py output:
      {
        \"title\": \"Our History\",
        \"blocks\": [...],
        \"last_updated\": ...,
        ...
      }
    We only add url and scrapedAt on top.
    """
    return _with_common_fields(raw, URL_HISTORY)


def normalize_vision_mission(raw: dict[str, Any]) -> dict[str, Any]:
    """
    Vision & mission document structure follows vis_mis_stra.py output:
      {
        \"vision\": ...,
        \"mission\": ...,
        \"overview_image\": ...,
        \"vision_strategy\": [...],
        ...
      }
    We preserve these fields and just add url and scrapedAt.
    """
    return _with_common_fields(raw, URL_VMS)


def normalize_motto_logo_anthem(raw: dict[str, Any]) -> dict[str, Any]:
    """
    Motto / logo / anthem document structure follows moto,logo,anth.py output:
      {
        \"motto_section\": [...],
        \"logo_section\": {...},
        \"color_identity\": {...},
        \"anthem\": [...],
        ...
      }
    Again we keep these fields and only add url and scrapedAt.
    """
    return _with_common_fields(raw, URL_MLA)


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
    news_mod = _load_module_from_path("news_scraper_mod", os.path.join(SCRIPT_DIR, "news_scraper.py"))

    raw_gov = _run_scraper(gov_mod.scrape_governance_live, URL_GOV)
    raw_hist = _run_scraper(hist_mod.scrape_campus_history_precise, URL_HISTORY)
    raw_vms = _run_scraper(vms_mod.scrape_vision_mission_strategy_final, URL_VMS)
    raw_mla = _run_scraper(mla_mod.scrape_motto_logo_anthem_complete, URL_MLA)
    raw_news = news_mod.scrape_news()

    jobs: list[tuple[str, str, dict[str, Any]]] = []

    if "error" not in raw_gov:
        jobs.append(("run_governance", "governance", normalize_governance(raw_gov)))
    if "error" not in raw_hist:
        jobs.append(("run_our_history", "our_history", normalize_history(raw_hist)))
    if "error" not in raw_vms:
        jobs.append(("run_vision_mission", "vision_mission", normalize_vision_mission(raw_vms)))
    if "error" not in raw_mla:
        jobs.append(("run_motto_logo_anthem", "motto_logo_anthem", normalize_motto_logo_anthem(raw_mla)))
    if isinstance(raw_news, list):
        for item in raw_news:
            if not isinstance(item, dict):
                continue
            url = str(item.get("url", "")).strip()
            if not url:
                continue
            doc_id = hashlib.sha256(url.encode("utf-8")).hexdigest()[:32]
            jobs.append((COLLECTION_NEWS, doc_id, item))

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

