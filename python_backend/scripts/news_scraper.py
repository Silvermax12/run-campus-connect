"""
Dedicated RUN news scraper utilities.

This module is intentionally Firestore-agnostic.
It only scrapes and returns structured news documents.

Firestore writes are handled by institutional_controller.py.
"""

from __future__ import annotations
from datetime import datetime, timezone
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup


NEWS_URL = "https://run.edu.ng/news/"


def _fetch_html(url: str) -> str:
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        )
    }
    resp = requests.get(url, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.text


def _extract_listing_items(html: str) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select("article.elementor-post")
    items: list[dict] = []

    for card in cards:
        title_link = card.select_one("h3.elementor-post__title a")
        if not title_link:
            continue

        heading = title_link.get_text(" ", strip=True)
        link = (title_link.get("href") or "").strip()
        if not heading or not link:
            continue

        img = card.select_one("a.elementor-post__thumbnail__link img")
        image_url = (img.get("src") or "").strip() if img else ""
        if image_url:
            image_url = urljoin(NEWS_URL, image_url)

        items.append(
            {
                "heading": heading,
                "url": urljoin(NEWS_URL, link),
                "imageUrl": image_url,
            }
        )

    return items


def _extract_full_post(url: str) -> str:
    try:
        html = _fetch_html(url)
        soup = BeautifulSoup(html, "html.parser")
        entry = soup.select_one("div.entry-content.clear")
        if not entry:
            return ""

        # Remove common noisy blocks if present.
        for sel in [
            "div.elementor-widget-nav-menu",
            "div.elementor-post-navigation",
            "nav.elementor-nav-menu--main",
            ".post-navigation",
            ".sidebar",
            ".widget",
        ]:
            for node in entry.select(sel):
                node.decompose()

        text = entry.get_text("\n", strip=True)
        lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
        return "\n\n".join(lines)
    except Exception:
        return ""


def scrape_news() -> list[dict]:
    html = _fetch_html(NEWS_URL)
    listing = _extract_listing_items(html)

    docs: list[dict] = []
    for item in listing:
        docs.append(
            {
                "heading": item["heading"],
                "imageUrl": item["imageUrl"],
                "fullPost": _extract_full_post(item["url"]),
                "url": item["url"],
                "scrapedAt": datetime.now(timezone.utc),
            }
        )
    return docs


def main() -> int:
    docs = scrape_news()
    print(f"Scraped {len(docs)} news item(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

