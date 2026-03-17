import requests
from bs4 import BeautifulSoup
import json
from urllib.parse import urljoin

def scrape_vision_mission_strategy_final(url):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        print(f"Connecting to {url}...")
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        data = {
            "vision": "",
            "mission": "",
            "overview_image": "",
            "vision_strategy": [],
            "last_updated": "2026-03-17"
        }

        # 1. Vision Statement (ID: 68fd2c8)
        vision_el = soup.select_one('.elementor-element-68fd2c8 .elementor-widget-container')
        if vision_el:
            data["vision"] = vision_el.get_text(strip=True).strip('“”') #

        # 2. Mission Statement (ID: 71c7abe)
        mission_el = soup.select_one('.elementor-element-71c7abe .elementor-widget-container')
        if mission_el:
            data["mission"] = mission_el.get_text(strip=True).strip('“”') #

        # 3. Vision Strategy / Detailed Content (ID: d9ec6f2)
        # This contains the long-form text about high moral standards and the future of Nigeria
        strategy_el = soup.select_one('.elementor-element-d9ec6f2 .elementor-widget-container')
        if strategy_el:
            paragraphs = strategy_el.find_all('p')
            data["vision_strategy"] = [p.get_text(strip=True) for p in paragraphs if p.get_text(strip=True)] #

        # 4. School Overview Image (ID: 050242d)
        img_el = soup.select_one('.elementor-element-050242d img')
        if img_el and img_el.get('src'):
            data["overview_image"] = urljoin(url, img_el['src']) #

        return data

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    # --- TEST EXECUTION ---
    TARGET_URL = "https://run.edu.ng/vision-mission-strategy/"
    result = scrape_vision_mission_strategy_final(TARGET_URL)

    if "error" not in result:
        print("\n--- SUCCESS ---")
        print(f"Vision: {result['vision'][:50]}...")
        print(f"Mission: {result['mission'][:50]}...")
        print(f"Strategy Paragraphs: {len(result['vision_strategy'])}")
        print(f"Image Captured: {'Yes' if result['overview_image'] else 'No'}")

        with open('campus_vision_mission.json', 'w') as f:
            json.dump(result, f, indent=4)
        print("\nData saved to 'campus_vision_mission.json'")
    else:
        print(f"Error: {result['error']}")