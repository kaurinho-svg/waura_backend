import os
import random
import logging
import requests
from duckduckgo_search import DDGS

logger = logging.getLogger(__name__)

class StyleSearchService:
    def __init__(self):
        self.google_api_key = os.getenv("GOOGLE_CSE_API_KEY")
        self.google_cx = os.getenv("GOOGLE_CSE_CX")
        
        if self.google_api_key and self.google_cx:
            logger.info("✅ Google Custom Search configured")
        else:
            logger.warning("⚠️ Google Custom Search NOT configured. Using DuckDuckGo fallback.")

    def _search_google(self, query: str, limit: int = 10) -> list:
        """Search using Google Custom Search API (Reliable on Server)."""
        if not self.google_api_key or not self.google_cx:
            return []
            
        results = []
        try:
            # Google allows max 10 results per page. 
            # We'll make just 1 request to save quota, or 2 if limit > 10.
            check_limit = min(limit, 10) 
            
            url = "https://www.googleapis.com/customsearch/v1"
            params = {
                "key": self.google_api_key,
                "cx": self.google_cx,
                "q": query,
                "searchType": "image",
                "num": check_limit,
                "safe": "active",
                "imgSize": "large" # Prefer quality
            }
            
            resp = requests.get(url, params=params, timeout=10)
            
            if resp.status_code == 200:
                data = resp.json()
                items = data.get("items", [])
                for item in items:
                    link = item.get("link")
                    if link:
                        results.append({
                            "imageUrl": link,
                            "title": item.get("title", query),
                            "category": "Inspiration",
                            "tags": ["Google Search"]
                        })
                logger.info(f"Google Search found {len(results)} images for '{query}'")
            else:
                logger.error(f"Google Search API error: {resp.status_code} - {resp.text}")
                
        except Exception as e:
            logger.error(f"Google Search exception: {e}")
            
        return results

    def search_styles(self, gender: str, category: str, limit: int = 20) -> list:
        """
        Search for style images. Tries Google first, then falls back to DuckDuckGo.
        Query format: "{category} fashion" or "{gender} {category} ..."
        """
        # Normalize inputs
        gender_term = "Men's" if gender.lower().startswith('m') else "Women's"
        
        # Construct Query
        if len(category.split()) >= 2:
            query = f"{category} {gender_term} fashion"
        elif any(x in category.lower() for x in ['bag', 'shoes', 'boots', 'sneakers', 'hat', 'watch', 'сумка', 'обувь', 'кроссовки', 'часы']):
            query = f"{category} fashion"
        else:
            query = f"{gender_term} {category} fashion outfit style"
        
        logger.info(f"Searching styles for: {query}")
        
        # 1. Try Google First (Reliable)
        results = self._search_google(query, limit=limit)
        
        # 2. Fallback to DuckDuckGo if Google failed or returned 0
        if not results:
            logger.info("Google search yielded 0 results. Falling back to DuckDuckGo...")
            results = self._search_ddg(query, limit)
            
        # RANDOMIZATION: Shuffle results to keep the feed fresh
        random.shuffle(results)
        return results

    def search_by_query(self, query: str, limit: int = 5) -> list:
        """Raw search by query string."""
        logger.info(f"Raw style search: {query}")
        
        # 1. Try Google First
        results = self._search_google(query, limit=limit)
        
        # 2. Fallback
        if not results:
             results = self._search_ddg(query, limit)
             
        return results

    def _search_ddg(self, query: str, limit: int) -> list:
        """DuckDuckGo Search (Fallback)."""
        results = []
        # RETRY LOGIC (2 attempts)
        for attempt in range(2):
            try:
                with DDGS() as ddgs:
                    ddg_results = ddgs.images(
                        query,
                        region="wt-wt",
                        safesearch="on",
                        max_results=limit * 2 
                    )
                    
                    for r in ddg_results:
                        image_url = r.get('image')
                        title = r.get('title', 'Style Idea')
                        
                        if image_url:
                            results.append({
                                "imageUrl": image_url,
                                "title": title,
                                "category": "Inspiration",
                                "tags": ["AI Suggested"]
                            })
                            
                        if len(results) >= limit:
                            break
                
                if results: break
                
            except Exception as e:
                logger.warning(f"DDG Search Error (Attempt {attempt+1}): {e}")
                import time
                time.sleep(1)
        
        return results
