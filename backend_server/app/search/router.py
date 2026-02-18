from fastapi import APIRouter, Query, HTTPException
from typing import Optional, Any

from .meili import get_index, build_filter
from .style_map import detect_style, normalize_query

# было:
# from .internet_google_cse import google_cse_search, GoogleCSEError
# стало:
from .internet_google_cse import (
    google_cse_search,
    google_cse_image_search,
    GoogleCSEError,
)

router = APIRouter(prefix="", tags=["search"])


def catalog_search_sync(
    q: str,
    limit: int,
    offset: int,
    gender: Optional[str],
    category: Optional[str],
    brand: Optional[str],
    color: Optional[str],
    price_min: Optional[float],
    price_max: Optional[float],
) -> dict[str, Any]:
    nq = normalize_query(q)
    style_key, boosted_terms = detect_style(nq)

    expanded_query = nq
    if boosted_terms:
        expanded_query = nq + " " + " ".join(boosted_terms)

    filters = {
        "gender": gender,
        "category": category,
        "brand": brand,
        "color": color,
        "price_min": price_min,
        "price_max": price_max,
    }
    meili_filter = build_filter(filters)

    index = get_index()

    res = index.search(
        expanded_query,
        {
            "limit": limit,
            "offset": offset,
            "filter": meili_filter,
            "attributesToRetrieve": [
                "id",
                "title",
                "brand",
                "category",
                "gender",
                "color",
                "material",
                "price",
                "currency",
                "sizes",
                "image_url",
                "product_url",
                "store",
                "tags",
                "style_tags",
            ],
            "showRankingScore": True,
        },
    )

    hits = res.get("hits", [])
    total = res.get("estimatedTotalHits", len(hits))

    for item in hits:
        item["_meta"] = {"detected_style": style_key, "expanded_query": expanded_query}

    return {"source": "catalog", "q": nq, "total": total, "items": hits}


@router.get("/search/catalog")
def search_catalog(
    q: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    gender: Optional[str] = None,
    category: Optional[str] = None,
    brand: Optional[str] = None,
    color: Optional[str] = None,
    price_min: Optional[float] = None,
    price_max: Optional[float] = None,
) -> dict[str, Any]:
    return catalog_search_sync(q, limit, offset, gender, category, brand, color, price_min, price_max)


# ✅ НОВОЕ: именно “картинки”, как вкладка Images в CSE-сайте
@router.get("/search/images")
async def search_images(
    q: str = Query(..., min_length=1),
    start: int = Query(1, ge=1),
    num: int = Query(10, ge=1, le=10),
) -> dict[str, Any]:
    nq = normalize_query(q)
    try:
        return await google_cse_image_search(nq, start=start, num=num)
    except GoogleCSEError as e:
        raise HTTPException(status_code=500, detail=str(e))


# оставляем твой старый интернет-поиск (ссылки/страницы), вдруг нужен
@router.get("/search/internet")
async def search_internet(
    q: str = Query(..., min_length=1),
    start: int = Query(1, ge=1),
    num: int = Query(10, ge=1, le=10),
) -> dict[str, Any]:
    nq = normalize_query(q)
    try:
        return await google_cse_search(nq, start=start, num=num)
    except GoogleCSEError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search")
async def search_both(
    q: str = Query(..., min_length=1),
    # catalog params
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    gender: Optional[str] = None,
    category: Optional[str] = None,
    brand: Optional[str] = None,
    color: Optional[str] = None,
    price_min: Optional[float] = None,
    price_max: Optional[float] = None,
    # internet params
    start: int = Query(1, ge=1),
    num: int = Query(10, ge=1, le=10),
) -> dict[str, Any]:
    catalog = catalog_search_sync(q, limit, offset, gender, category, brand, color, price_min, price_max)

    try:
        # можешь поменять на google_cse_image_search, если хочешь чтобы /search тоже был “картинками”
        internet = await google_cse_search(normalize_query(q), start=start, num=num)
    except GoogleCSEError as e:
        internet = {"source": "internet", "q": q, "total": 0, "items": [], "error": str(e)}

    return {"q": normalize_query(q), "catalog": catalog, "internet": internet}