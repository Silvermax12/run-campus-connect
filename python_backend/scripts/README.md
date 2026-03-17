# RUN News Scraper

Scrapes run.edu.ng and writes to Firebase Firestore:

- **run_news**: News from https://run.edu.ng/news/
- **run_vision_mission**: Vision, Mission & Strategy from https://run.edu.ng/vision-mission-strategy/
- **run_our_history**: Our History from https://run.edu.ng/our-history/
- **run_governance**: Governance from https://run.edu.ng/governance/
- **run_motto_logo_anthem**: Motto, Logo & Anthem from https://run.edu.ng/motto-logo-anthem/

## Setup

1. From `python_backend/`, activate venv and install dependencies:

   ```bash
   .\venv\Scripts\Activate.ps1   # Windows PowerShell
   pip install -r scripts/requirements-scraper.txt
   playwright install chromium
   ```

2. Ensure `serviceAccountKey.json` exists in `python_backend/` (same as main FastAPI backend).

## Usage

```bash
# From python_backend/ with venv activated:
python scripts/run_news_scraper.py              # Headless, all articles
python scripts/run_news_scraper.py --headful    # Visible browser (debugging)
python scripts/run_news_scraper.py --limit 5    # Cap at 5 articles
```

## Firebase Schema

### run_news
| Field     | Type     | Description                    |
|-----------|----------|--------------------------------|
| url       | string   | Post URL                       |
| heading   | string   | Post title                     |
| imageUrl  | string   | Thumbnail image URL            |
| fullPost  | string   | Full post content (plain text) |
| scrapedAt | timestamp| When scraped                   |

Document IDs are derived from URL hashes for deduplication on re-runs.

### run_vision_mission
Document ID: `vision_mission` (single document)

| Field          | Type     | Description                             |
|----------------|----------|-----------------------------------------|
| url            | string   | Page URL                                |
| visionStatement| string   | Vision statement quote                  |
| missionStatement| string  | Mission statement quote                 |
| visionStrategy | string   | Vision strategy full text               |
| scrapedAt      | timestamp| When scraped                            |

### run_our_history
Document ID: `our_history` (single document)

| Field      | Type     | Description                          |
|------------|----------|--------------------------------------|
| url        | string   | Page URL                             |
| fullHistory| string   | Full history text (all paragraphs)   |
| imageUrls  | array    | Image URLs from the page             |
| scrapedAt  | timestamp| When scraped                         |

### run_governance
Document ID: `governance` (single document)

| Field            | Type     | Description                                            |
|------------------|----------|--------------------------------------------------------|
| url              | string   | Page URL                                               |
| teamMembers      | array    | Leadership team: `{name, role, imageUrl, bio}`         |
| boardOfTrustees  | array    | Board of Trustees: `{name, role}`                      |
| governingCouncil | array    | Governing Council: `{name, role}`                      |
| senateMembers    | array    | Senate: `{name, position}`                             |
| scrapedAt        | timestamp| When scraped                                           |

### run_motto_logo_anthem
Document ID: `motto_logo_anthem` (single document)

| Field       | Type     | Description                                      |
|-------------|----------|--------------------------------------------------|
| url         | string   | Page URL                                         |
| fullContent | string   | Motto, logo description, colours, anthem lyrics  |
| imageUrls   | array    | Image URLs (e.g. colored-logo.png)               |
| scrapedAt   | timestamp| When scraped                                     |
