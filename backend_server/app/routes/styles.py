from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
from app.services.style_search_service import StyleSearchService

router = APIRouter(tags=["Styles"])
search_service = StyleSearchService()

@router.get("/styles/search")
async def search_styles(
    gender: str = Query(..., description="Gender (male/female)"),
    category: str = Query(..., description="Style category (e.g. Streetwear, Business)"),
    limit: int = Query(20, description="Max results")
):
    """
    Search for inspiration styles in the internet.
    """
    try:
        results = search_service.search_styles(gender, category, limit)
        return {"items": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
