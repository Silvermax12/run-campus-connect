import requests
from bs4 import BeautifulSoup
import json
from urllib.parse import urljoin

def scrape_campus_history_precise(url):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    try:
        print(f"Connecting to {url}...")
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # The history content is contained within this specific Elementor ID/Class
        # Based on your file, we'll look for the entry-content area
        content_area = soup.select_one('.entry-content')
        
        history_blocks = []

        if content_area:
            # We look for text editor widgets and image widgets in order
            # These are the standard wrappers used in your uploaded file
            sections = content_area.select('.elementor-widget-text-editor, .elementor-widget-image')
            
            for section in sections:
                if 'elementor-widget-text-editor' in section['class']:
                    # Extract text paragraphs
                    paragraphs = [p.get_text(strip=True) for p in section.find_all('p') if p.get_text(strip=True)]
                    if paragraphs:
                        history_blocks.append({
                            "type": "text",
                            "content": paragraphs
                        })
                
                elif 'elementor-widget-image' in section['class']:
                    # Extract image URLs and handle relative paths
                    img_tag = section.find('img')
                    if img_tag and img_tag.get('src'):
                        img_url = urljoin(url, img_tag['src'])
                        history_blocks.append({
                            "type": "image",
                            "url": img_url,
                            "alt": img_tag.get('alt', '')
                        })

        return {
            "title": "Our History",
            "blocks": history_blocks,
            "last_updated": "2026-03-17"
        }

    except Exception as e:
        return {"error": f"Scrape failed: {str(e)}"}

if __name__ == "__main__":
    # --- TEST EXECUTION ---
    URL = "https://run.edu.ng/our-history/"
    history_data = scrape_campus_history_precise(URL)

    if "error" not in history_data:
        print(f"\n--- SUCCESS ---")
        print(f"Total content blocks found: {len(history_data['blocks'])}")

        # Save for inspection
        with open('campus_history_detailed.json', 'w') as f:
            json.dump(history_data, f, indent=4)
        print("Detailed history data saved to 'campus_history_detailed.json'")
    else:
        print(history_data["error"])