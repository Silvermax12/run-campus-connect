import requests
from bs4 import BeautifulSoup
import json
from urllib.parse import urljoin

def scrape_motto_logo_anthem_complete(url):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        print(f"Connecting to {url}...")
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        data = {
            "motto_section": [],
            "logo_section": {
                "description": "",
                "images": []
            },
            "color_identity": {
                "main_text": "",
                "details": []
            },
            "anthem": [],
            "last_updated": "2026-03-17"
        }

        # 1. Motto Section (IDs: b3becad, 6f33b89e)
        motto_ids = ['b3becad', '6f33b89e']
        for mid in motto_ids:
            el = soup.select_one(f'.elementor-element-{mid} .elementor-widget-container')
            if el:
                data["motto_section"].append(el.get_text(strip=True))

        # 2. Logo Section
        # Description text (ID: a3851c2)
        logo_desc_el = soup.select_one('.elementor-element-a3851c2 .elementor-widget-container')
        if logo_desc_el:
            data["logo_section"]["description"] = logo_desc_el.get_text(strip=True)
        
        # Logo Images (Colored: 55689804, White: e9beb7a)
        logo_img_ids = ['55689804', 'e9beb7a']
        for lid in logo_img_ids:
            img = soup.select_one(f'.elementor-element-{lid} img')
            if img and img.get('src'):
                data["logo_section"]["images"].append(urljoin(url, img['src']))

        # 3. Color Identity
        # Intro text (ID: 1d114c9)
        color_intro = soup.select_one('.elementor-element-1d114c9 .elementor-widget-container')
        if color_intro:
            data["color_identity"]["main_text"] = color_intro.get_text(strip=True)

        # Color Details (Image ID, Description ID)
        color_map = [
            ('50861af', '497d95d'), # Blue
            ('181862e', 'e3b994a'), # White
            ('0c0c0df', 'b02edaa'), # Green
            ('75ba1ba', '9706a5d')  # Gold
        ]

        for img_id, text_id in color_map:
            img_el = soup.select_one(f'.elementor-element-{img_id} img')
            text_el = soup.select_one(f'.elementor-element-{text_id} .elementor-widget-container')
            if img_el and text_el:
                data["color_identity"]["details"].append({
                    "image_url": urljoin(url, img_el['src']),
                    "description": text_el.get_text(strip=True)
                })

        # 4. Anthem (ID: a7e8810)
        anthem_box = soup.select_one('.elementor-element-a7e8810 .elementor-widget-container')
        if anthem_box:
            # Separator ensures <br> tags preserve line breaks
            lines = anthem_box.get_text(separator="\n", strip=True).split("\n")
            data["anthem"] = [l.strip() for l in lines if l.strip()]

        return data

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    # --- TEST EXECUTION ---
    TARGET_URL = "https://run.edu.ng/motto-logo-anthem/"
    result = scrape_motto_logo_anthem_complete(TARGET_URL)

    if "error" not in result:
        print("\n--- SUCCESS ---")
        print(f"Motto segments: {len(result['motto_section'])}")
        print(f"Logo description captured: {'Yes' if result['logo_section']['description'] else 'No'}")
        print(f"Logos: {len(result['logo_section']['images'])}")
        print(f"Colors mapped: {len(result['color_identity']['details'])}")

        with open('campus_identity_final.json', 'w') as f:
            json.dump(result, f, indent=4)
    else:
        print(result["error"])