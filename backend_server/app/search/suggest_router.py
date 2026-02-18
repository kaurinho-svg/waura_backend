from fastapi import APIRouter, Query
from typing import Any
from .meili import get_index
from .style_map import normalize_query

router = APIRouter(tags=["search"])

@router.get("/suggest")
def suggest(q: str = Query(..., min_length=1), limit: int = Query(8, ge=1, le=20)) -> dict[str, Any]:
    nq = normalize_query(q)
    index = get_index()

    # Просим Meilisearch вернуть только title/id для быстрых подсказок
    res = index.search(nq, {
        "limit": limit,
        "attributesToRetrieve": ["id", "title", "brand", "category"],
    })

    hits = res.get("hits", [])
    # Убираем дубли по title
    seen = set()
    suggestions = []
    for h in hits:
        t = (h.get("title") or "").strip()
        if not t or t in seen:
            continue
        seen.add(t)
        suggestions.append({
            "id": h.get("id"),
            "title": t,
            "brand": h.get("brand"),
            "category": h.get("category"),
        })

    return {"q": nq, "suggestions": suggestions}