from duckduckgo_search import DDGS
import random

class StyleSearchService:
    def __init__(self):
        pass # Removed as DDGS will be used as a context manager per request

    def search_styles(self, gender: str, category: str, limit: int = 20) -> list:
        """
        Search for style images using DuckDuckGo.
        Query format: "{category} fashion" or "{gender} {category} ..."
        """
        # Normalize inputs
        gender_term = "Men's" if gender.lower().startswith('m') else "Women's"
        
        # 1. Primary Query
        # If the category contains multiple words (custom search), rely on it more.
        if len(category.split()) >= 2:
             # E.g. "Armani bag" -> "Armani bag" (maybe add gender if it helps, but simplest is best)
             # Let's try to just append 'fashion' to ensure we get fashion items, but avoid 'outfit'
            query = f"{category} {gender_term} fashion"
        elif any(x in category.lower() for x in ['bag', 'shoes', 'boots', 'sneakers', 'hat', 'watch', 'сумка', 'обувь', 'кроссовки', 'часы']):
             # Single word specific item -> "bag fashion"
            query = f"{category} fashion"
        else:
            # Broad style (e.g. "Business", "Casual") -> needs "outfit" to show full look
            query = f"{gender_term} {category} fashion outfit style"
        
        print(f"Searching styles for: {query}")
        
        results = []
        # RETRY LOGIC (3 attempts)
        for attempt in range(3):
            try:
                # Use detailed exception handling and context manager
                with DDGS() as ddgs:
                    # DDG images search
                    ddg_results = ddgs.images(
                        query,
                        region="wt-wt",
                        safesearch="on",
                        max_results=limit * 2 
                    )
                    
                    for r in ddg_results:
                        image_url = r.get('image')
                        title = r.get('title', category)
                        
                        if image_url:
                            results.append({
                                "imageUrl": image_url,
                                "title": title,
                                "category": category,
                                "tags": [category, gender_term, "Trend"]
                            })
                            
                        if len(results) >= limit:
                            break
                    
                    # FALLBACK: If 0 results, try simpler query (Only on last attempt or immediate?)
                    # Let's try fallback immediately if main query fails to find items
                    if not results:
                        print(f"Zero results for '{query}'. Trying fallback...")
                        fallback_query = f"{category} {gender_term}"
                        fallback_results = ddgs.images(fallback_query, region="wt-wt", safesearch="off", max_results=limit)
                        for r in fallback_results:
                            if r.get('image'):
                                results.append({
                                    "imageUrl": r.get('image'),
                                    "title": r.get('title', category),
                                    "category": category,
                                    "tags": [category, gender_term, "Fallback"]
                                })
                            if len(results) >= limit: break
                
                # If we got results, break retry loop
                if results:
                    break
                else:
                    print(f"Attempt {attempt+1} failed to find results.")
                        
            except Exception as e:
                print(f"DDG Search Error (Attempt {attempt+1}): {e}")
                import time
                time.sleep(1) # Wait 1 sec before retry
            
        # RANDOMIZATION: Shuffle results to keep the feed fresh
        random.shuffle(results)
        return results

    def search_by_query(self, query: str, limit: int = 5) -> list:
        """Raw search by query string."""
        print(f"Raw style search: {query}")
        results = []
        try:
            with DDGS() as ddgs:
                ddg_results = ddgs.images(query, region="wt-wt", safesearch="on", max_results=limit * 2)
                for r in ddg_results:
                    if r.get('image'):
                        results.append({
                            "imageUrl": r.get('image'),
                            "title": r.get('title', 'Style Idea'),
                            "category": "Inspiration",
                            "tags": ["AI Suggested"]
                        })
                    if len(results) >= limit:
                        break
        except Exception as e:
            print(f"DDG Search Error: {e}")
        return results
