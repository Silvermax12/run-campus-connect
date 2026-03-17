import requests
from bs4 import BeautifulSoup
import json

def scrape_governance_live(url):
    # Set a User-Agent so the website thinks we are a real browser
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        print(f"Connecting to {url}...")
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()  # Check for HTTP errors
        
        soup = BeautifulSoup(response.text, 'html.parser')
        data = {"officers": [], "senate": []}

        # 1. Scrape the High-Level Officers (Cards)
        # These are the clickable profiles with images
        cards = soup.select('.awsm-grid-card')
        for card in cards:
            # Using try-except for individual items so one missing field doesn't break the whole list
            try:
                name_tag = card.select_one('h3')
                role_tag = card.select_one('span')
                img_tag = card.select_one('img')
                
                if name_tag and role_tag:
                    data["officers"].append({
                        "name": name_tag.get_text(strip=True),
                        "role": role_tag.get_text(strip=True),
                        "image_url": img_tag['src'] if img_tag else "No Image"
                    })
            except Exception as e:
                continue

        # 2. Scrape the Senate Table
        # This matches the specific ID in your Governance.html file
        rows = soup.select('#tablepress-14 tr')
        for row in rows:
            cols = row.find_all('td')
            if len(cols) == 2:
                data["senate"].append({
                    "name": cols[0].get_text(strip=True),
                    "designation": cols[1].get_text(strip=True)
                })
        
        return data

    except requests.exceptions.RequestException as e:
        return {"error": f"Failed to fetch data: {str(e)}"}

if __name__ == "__main__":
    # --- TEST EXECUTION ---
    TARGET_URL = "https://run.edu.ng/governance/"
    result = scrape_governance_live(TARGET_URL)

    # Print a nice summary of what we found
    if "error" not in result:
        print(f"\n--- SUCCESS ---")
        print(f"Officers found: {len(result['officers'])}")
        print(f"Senate members found: {len(result['senate'])}")

        # Save to a local file for you to inspect
        with open('campus_governance_data.json', 'w') as f:
            json.dump(result, f, indent=4)
        print("\nData has been saved to 'campus_governance_data.json'")
    else:
        print(result["error"])