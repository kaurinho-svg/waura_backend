import sys
import os

# Add app to path
sys.path.append(os.path.join(os.getcwd(), 'app'))

from app.services.style_search_service import StyleSearchService

def test_search():
    service = StyleSearchService()
    
    print("--- Test 1: Standard Category (Business) ---")
    results = service.search_styles(gender="Male", category="Business")
    print(f"Results: {len(results)}")
    if not results:
        print("FAILED")
    else:
        print(f"First result: {results[0]['title']}")

    print("\n--- Test 2: Specific Item (сумка armani) ---")
    results = service.search_styles(gender="Male", category="сумка armani")
    print(f"Results: {len(results)}")
    if not results:
        print("FAILED")
    else:
        print(f"First result: {results[0]['title']}")

if __name__ == "__main__":
    test_search()
