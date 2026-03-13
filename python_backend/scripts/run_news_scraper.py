"""
Scrape news and vision/mission from run.edu.ng and write to Firebase Firestore.

Pages scraped:
  - https://run.edu.ng/news/           -> run_news collection
  - https://run.edu.ng/vision-mission-strategy/ -> run_vision_mission collection
  - https://run.edu.ng/our-history/    -> run_our_history collection
  - https://run.edu.ng/governance/     -> run_governance collection
  - https://run.edu.ng/motto-logo-anthem/ -> run_motto_logo_anthem collection

Usage:
    python run_news_scraper.py              # headless, all articles (with pagination)
    python run_news_scraper.py --headful    # visible browser for debugging
    python run_news_scraper.py --limit 5    # cap at 5 articles

Requires:
    - serviceAccountKey.json in python_backend/
    - playwright install chromium (run after pip install playwright)
"""

import argparse
import hashlib
import json
import logging
import os
import re
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore
from playwright.sync_api import sync_playwright

# ─── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ─── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(SCRIPT_DIR)
SERVICE_ACCOUNT_PATH = os.path.join(PARENT_DIR, "serviceAccountKey.json")

NEWS_URL = "https://run.edu.ng/news/"
VISION_MISSION_URL = "https://run.edu.ng/vision-mission-strategy/"
OUR_HISTORY_URL = "https://run.edu.ng/our-history/"
GOVERNANCE_URL = "https://run.edu.ng/governance/"
MOTTO_LOGO_ANTHEM_URL = "https://run.edu.ng/motto-logo-anthem/"
COLLECTION_NAME = "run_news"
VISION_MISSION_COLLECTION = "run_vision_mission"
OUR_HISTORY_COLLECTION = "run_our_history"
GOVERNANCE_COLLECTION = "run_governance"
MOTTO_LOGO_ANTHEM_COLLECTION = "run_motto_logo_anthem"
CACHE_FILE_PATH = os.path.join(SCRIPT_DIR, "scrape_cache.json")

# DOM selectors (corrected from Elementor markup)
SELECTOR_ARTICLE = "article.elementor-post"
SELECTOR_THUMBNAIL_LINK = "a.elementor-post__thumbnail__link"
SELECTOR_TITLE_LINK = "h3.elementor-post__title a"
SELECTOR_ENTRY_CONTENT = "div.entry-content.clear"
SELECTOR_LOAD_MORE = "button:has-text('Load more'), .elementor-button:has-text('Load more'), .load-more-align-center button, .load-more-align-center .elementor-button"

# Vision/mission page selectors
SELECTOR_VISION_H2 = "h2.elementor-heading-title"
SELECTOR_D_QUOTE_P = ".d-quote p"


# ─── Local Cache Helpers ─────────────────────────────────────────────────────

def load_cache() -> dict:
    """Load the local scrape cache from disk, or return empty dict."""
    if os.path.exists(CACHE_FILE_PATH):
        try:
            with open(CACHE_FILE_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            logger.warning("Cache file corrupt or unreadable, starting fresh: %s", e)
    return {}


def save_cache(cache: dict) -> None:
    """Persist the cache dict to disk."""
    with open(CACHE_FILE_PATH, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)


def content_hash(data: dict) -> str:
    """
    Produce a deterministic SHA-256 hex digest of *data*, ignoring
    volatile fields like ``scrapedAt`` / ``scrapedTime`` so that
    identical content always yields the same hash.
    """
    # Strip volatile keys before hashing
    stable = {k: v for k, v in data.items() if k not in ("scrapedAt", "scrapedTime")}
    raw = json.dumps(stable, sort_keys=True, default=str)
    return hashlib.sha256(raw.encode()).hexdigest()


def has_changed(cache: dict, cache_key: str, data: dict) -> bool:
    """
    Return True if *data* differs from what is stored in *cache* under
    *cache_key*.  If it has NOT changed, the Firestore write can be
    skipped entirely.
    """
    new_hash = content_hash(data)
    if cache.get(cache_key) == new_hash:
        return False          # identical – nothing to do
    cache[cache_key] = new_hash  # update cache in-memory
    return True


# ─── Utilities ───────────────────────────────────────────────────────────────

def url_to_doc_id(url: str) -> str:
    """Generate a stable document ID from post URL for deduplication."""
    return hashlib.sha256(url.encode()).hexdigest()[:32]


def init_firebase():
    """Initialize Firebase Admin and return Firestore client, or None if not configured."""
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        logger.error(
            "serviceAccountKey.json NOT FOUND at %s. Place it in python_backend/.",
            SERVICE_ACCOUNT_PATH,
        )
        return None

    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)

    return firestore.client()


def extract_listing_data(page, limit: int | None) -> list[dict]:
    """
    Extract (url, heading, imageUrl) for each article from the news listing.
    Optionally click "Load more" up to 3 times.
    """
    articles = []
    seen_urls = set()
    load_more_attempts = 0
    max_load_more = 3

    while True:
        page.wait_for_selector(SELECTOR_ARTICLE, timeout=15000)

        cards = page.query_selector_all(SELECTOR_ARTICLE)
        for card in cards:
            if limit is not None and len(articles) >= limit:
                break

            try:
                title_el = card.query_selector(SELECTOR_TITLE_LINK)
                if not title_el:
                    continue

                url = title_el.get_attribute("href")
                if not url or url in seen_urls:
                    continue

                heading = title_el.inner_text().strip()
                if not heading:
                    continue

                # Image: img inside thumbnail link, or thumbnail link's background
                image_url = ""
                thumb_link = card.query_selector(SELECTOR_THUMBNAIL_LINK)
                if thumb_link:
                    img = thumb_link.query_selector("img")
                    if img:
                        image_url = img.get_attribute("src") or ""
                    # Fallback: check for background-image on child div
                    if not image_url:
                        thumb_div = thumb_link.query_selector("div")
                        if thumb_div:
                            style = thumb_div.get_attribute("style") or ""
                            match = re.search(r'url\(["\']?([^"\')\s]+)["\']?\)', style)
                            if match:
                                image_url = match.group(1)

                seen_urls.add(url)
                articles.append({
                    "url": url,
                    "heading": heading,
                    "imageUrl": image_url or "",
                })
            except Exception as e:
                logger.warning("Skipped article due to error: %s", e)
                continue

        if limit is not None and len(articles) >= limit:
            break

        # Try "Load more"
        load_btn = page.query_selector(SELECTOR_LOAD_MORE)
        if load_btn and load_more_attempts < max_load_more:
            try:
                load_btn.click()
                page.wait_for_timeout(2000)
                load_more_attempts += 1
                logger.info("Clicked Load more (attempt %d/%d)", load_more_attempts, max_load_more)
            except Exception:
                break
        else:
            break

    return articles[:limit] if limit else articles


def fetch_full_post(page, url: str) -> str:
    """Navigate to post URL and extract full content from div.entry-content.clear."""
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=30000)
        content_el = page.wait_for_selector(SELECTOR_ENTRY_CONTENT, timeout=10000)
        return content_el.inner_text().strip() if content_el else ""
    except Exception as e:
        logger.warning("Could not fetch full post for %s: %s", url, e)
        return ""


def scrape_vision_mission(page) -> dict | None:
    """
    Scrape Vision, Mission & Strategy from https://run.edu.ng/vision-mission-strategy/
    Extracts: Vision Statement, Mission Statement, Vision Strategy.
    """
    try:
        page.goto(VISION_MISSION_URL, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_selector("div.entry-content.clear", timeout=10000)

        # Vision and Mission - from .d-quote p elements (quotes under each heading)
        vision_statement = ""
        mission_statement = ""
        quotes = page.query_selector_all(SELECTOR_D_QUOTE_P)
        if len(quotes) >= 1:
            vision_statement = quotes[0].inner_text().strip()
        if len(quotes) >= 2:
            mission_statement = quotes[1].inner_text().strip()

        # Vision Strategy - find h2 "Vision Strategy" then get the following section's content
        vision_strategy = ""
        sections = page.query_selector_all("section.elementor-inner-section")
        for i, sec in enumerate(sections):
            h2 = sec.query_selector(SELECTOR_VISION_H2)
            if h2:
                title = h2.inner_text().strip()
                if "Vision Strategy" in title:
                    # Content is in the next sibling section (widget-wrap with paragraphs)
                    if i + 1 < len(sections):
                        vision_strategy = sections[i + 1].inner_text().strip()
                    else:
                        wrap = sec.query_selector("div.elementor-widget-wrap")
                        if wrap:
                            vision_strategy = wrap.inner_text().strip()
                    break

        return {
            "url": VISION_MISSION_URL,
            "visionStatement": vision_statement,
            "missionStatement": mission_statement,
            "visionStrategy": vision_strategy,
            "scrapedAt": datetime.now(timezone.utc),
        }
    except Exception as e:
        logger.warning("Could not scrape vision-mission-strategy: %s", e)
        return None


def scrape_our_history(page) -> dict | None:
    """
    Scrape Our History from https://run.edu.ng/our-history/
    Extracts: full history text and image URLs from entry-content.
    """
    try:
        page.goto(OUR_HISTORY_URL, wait_until="domcontentloaded", timeout=30000)
        entry = page.wait_for_selector("div.entry-content.clear", timeout=10000)
        if not entry:
            return None

        full_history = entry.inner_text().strip()

        # Extract image URLs from img elements within entry-content
        image_urls = []
        imgs = entry.query_selector_all("img[src]")
        seen = set()
        for img in imgs:
            src = img.get_attribute("src")
            if src and src not in seen:
                seen.add(src)
                image_urls.append(src)

        return {
            "url": OUR_HISTORY_URL,
            "fullHistory": full_history,
            "imageUrls": image_urls,
            "scrapedAt": datetime.now(timezone.utc),
        }
    except Exception as e:
        logger.warning("Could not scrape our-history: %s", e)
        return None


def scrape_governance(page) -> dict | None:
    """
    Scrape Governance from https://run.edu.ng/governance/
    Extracts: full governance content (awsm-team grid, Board of Trustees,
    Governing Council, Senate) and image URLs from entry-content.
    """
    try:
        page.goto(GOVERNANCE_URL, wait_until="domcontentloaded", timeout=30000)
        entry = page.wait_for_selector("div.entry-content.clear", timeout=10000)
        if not entry:
            return None

        full_content = entry.inner_text().strip()

        # Extract image URLs (profile photos, etc.) from img elements within entry-content
        image_urls = []
        imgs = entry.query_selector_all("img[src]")
        seen = set()
        for img in imgs:
            src = img.get_attribute("src")
            if src and src not in seen:
                seen.add(src)
                image_urls.append(src)

        return {
            "url": GOVERNANCE_URL,
            "fullContent": full_content,
            "imageUrls": image_urls,
            "scrapedAt": datetime.now(timezone.utc),
        }
    except Exception as e:
        logger.warning("Could not scrape governance: %s", e)
        return None


def scrape_motto_logo_anthem(page) -> dict | None:
    """
    Scrape Motto, Logo & Anthem from https://run.edu.ng/motto-logo-anthem/
    Extracts: motto, logo description, university colours, anthem lyrics,
    and image URLs (e.g. colored-logo.png) from entry-content.
    """
    try:
        page.goto(MOTTO_LOGO_ANTHEM_URL, wait_until="domcontentloaded", timeout=30000)
        entry = page.wait_for_selector("div.entry-content.clear", timeout=10000)
        if not entry:
            return None

        full_content = entry.inner_text().strip()

        # Extract image URLs (logo, etc.) from img elements within entry-content
        image_urls = []
        imgs = entry.query_selector_all("img[src]")
        seen = set()
        for img in imgs:
            src = img.get_attribute("src")
            if src and src not in seen:
                seen.add(src)
                image_urls.append(src)

        return {
            "url": MOTTO_LOGO_ANTHEM_URL,
            "fullContent": full_content,
            "imageUrls": image_urls,
            "scrapedAt": datetime.now(timezone.utc),
        }
    except Exception as e:
        logger.warning("Could not scrape motto-logo-anthem: %s", e)
        return None


def scrape_and_save(
    headful: bool = False,
    limit: int | None = None,
) -> int:
    """Run scraper and save to Firestore. Returns number of documents written."""
    db = init_firebase()
    if db is None:
        sys.exit(1)

    cache = load_cache()
    written = 0
    skipped = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=not headful)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        page = context.new_page()

        try:
            # 1. Scrape vision-mission-strategy page
            logger.info("Scraping %s", VISION_MISSION_URL)
            vision_data = scrape_vision_mission(page)
            if vision_data:
                cache_key = f"{VISION_MISSION_COLLECTION}/vision_mission"
                if has_changed(cache, cache_key, vision_data):
                    db.collection(VISION_MISSION_COLLECTION).document("vision_mission").set(
                        vision_data
                    )
                    written += 1
                    logger.info("Saved to %s/vision_mission", VISION_MISSION_COLLECTION)
                else:
                    skipped += 1
                    logger.info("No change – skipped %s/vision_mission", VISION_MISSION_COLLECTION)

            # 2. Scrape our-history page
            logger.info("Scraping %s", OUR_HISTORY_URL)
            history_data = scrape_our_history(page)
            if history_data:
                cache_key = f"{OUR_HISTORY_COLLECTION}/our_history"
                if has_changed(cache, cache_key, history_data):
                    db.collection(OUR_HISTORY_COLLECTION).document("our_history").set(
                        history_data
                    )
                    written += 1
                    logger.info("Saved to %s/our_history", OUR_HISTORY_COLLECTION)
                else:
                    skipped += 1
                    logger.info("No change – skipped %s/our_history", OUR_HISTORY_COLLECTION)

            # 3. Scrape governance page
            logger.info("Scraping %s", GOVERNANCE_URL)
            governance_data = scrape_governance(page)
            if governance_data:
                cache_key = f"{GOVERNANCE_COLLECTION}/governance"
                if has_changed(cache, cache_key, governance_data):
                    db.collection(GOVERNANCE_COLLECTION).document("governance").set(
                        governance_data
                    )
                    written += 1
                    logger.info("Saved to %s/governance", GOVERNANCE_COLLECTION)
                else:
                    skipped += 1
                    logger.info("No change – skipped %s/governance", GOVERNANCE_COLLECTION)

            # 4. Scrape motto-logo-anthem page
            logger.info("Scraping %s", MOTTO_LOGO_ANTHEM_URL)
            motto_data = scrape_motto_logo_anthem(page)
            if motto_data:
                cache_key = f"{MOTTO_LOGO_ANTHEM_COLLECTION}/motto_logo_anthem"
                if has_changed(cache, cache_key, motto_data):
                    db.collection(MOTTO_LOGO_ANTHEM_COLLECTION).document("motto_logo_anthem").set(
                        motto_data
                    )
                    written += 1
                    logger.info("Saved to %s/motto_logo_anthem", MOTTO_LOGO_ANTHEM_COLLECTION)
                else:
                    skipped += 1
                    logger.info("No change – skipped %s/motto_logo_anthem", MOTTO_LOGO_ANTHEM_COLLECTION)

            # 5. Scrape news listing and detail pages
            logger.info("Navigating to %s", NEWS_URL)
            page.goto(NEWS_URL, wait_until="domcontentloaded", timeout=45000)

            articles = extract_listing_data(page, limit)
            logger.info("Found %d articles", len(articles))

            for i, item in enumerate(articles):
                url = item["url"]
                heading = item["heading"]
                image_url = item["imageUrl"]

                logger.info("[%d/%d] Fetching: %s", i + 1, len(articles), heading[:50] + "…")

                full_post = fetch_full_post(page, url)

                doc_id = url_to_doc_id(url)
                doc_data = {
                    "url": url,
                    "heading": heading,
                    "imageUrl": image_url,
                    "fullPost": full_post,
                    "scrapedAt": datetime.now(timezone.utc),
                }

                cache_key = f"{COLLECTION_NAME}/{doc_id}"
                if has_changed(cache, cache_key, doc_data):
                    db.collection(COLLECTION_NAME).document(doc_id).set(doc_data)
                    written += 1
                    logger.info("Saved to %s/%s", COLLECTION_NAME, doc_id)
                else:
                    skipped += 1
                    logger.info("No change – skipped %s/%s", COLLECTION_NAME, doc_id)

        finally:
            browser.close()

    # Persist cache only once, after all work is done
    save_cache(cache)
    logger.info("Cache updated at %s (written=%d, skipped=%d)", CACHE_FILE_PATH, written, skipped)

    return written


def main():
    parser = argparse.ArgumentParser(description="Scrape RUN news and save to Firebase")
    parser.add_argument("--headful", action="store_true", help="Show browser window")
    parser.add_argument("--limit", type=int, default=None, help="Max number of articles to scrape")
    args = parser.parse_args()

    written = scrape_and_save(headful=args.headful, limit=args.limit)
    logger.info(
        "Done. Wrote %d documents (%s, %s, %s, %s, %s)",
        written,
        VISION_MISSION_COLLECTION,
        OUR_HISTORY_COLLECTION,
        GOVERNANCE_COLLECTION,
        MOTTO_LOGO_ANTHEM_COLLECTION,
        COLLECTION_NAME,
    )


if __name__ == "__main__":
    main()
