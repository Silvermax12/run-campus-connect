from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto('https://run.edu.ng/our-history/', wait_until='domcontentloaded', timeout=60000)
    
    # Wait for entry content
    entry = page.wait_for_selector('div.entry-content.clear', timeout=30000)
    
    if entry:
        # Check what classes inside have long text
        children = entry.query_selector_all('*')
        
        counts = {}
        for el in children:
            tag = el.evaluate('el => el.tagName').lower()
            cls = el.get_attribute('class') or ''
            txt = el.inner_text().strip()
            if txt:
                key = f"{tag}.{cls.replace(' ', '.')}"
                counts[key] = counts.get(key, 0) + len(txt)
                
        # Print elements that contain lots of text, these might be the sidebars
        sorted_counts = sorted(counts.items(), key=lambda x: x[1], reverse=True)
        print("--- Elements with most text ---")
        for k, v in sorted_counts[:20]:
            print(f"{k}: {v} chars")
            
        print("\n--- Let's look at the raw paragraphs (p tags) ---")
        paras = entry.query_selector_all('p')
        for i, p in enumerate(paras):
            text = p.inner_text().strip()
            if text:
                print(f"P {i}: {text[:100]}...")
            
    browser.close()
