import os
import re
from typing import Any, Dict, List, Optional, Tuple

import requests
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/search", tags=["search"])

GOOGLE_CSE_API_KEY = os.getenv("GOOGLE_CSE_API_KEY", "").strip()
GOOGLE_CSE_CX = os.getenv("GOOGLE_CSE_CX", "").strip()

BANNED_DOMAINS = [
    "pinterest.", "pinimg.",
    "tiktok.", "instagram.", "facebook.", "vk.com",
    "wikipedia.", "yandex.", "google.", "youtube.",
    "reddit.",  # часто арты/мусор не как “одежда-товар”
]

BAD_IMG_PATTERNS = [
    r"logo", r"icon", r"favicon", r"sprite",
    r"\.svg", r"data:image",
]

# жёсткий бан по словам (кроме запроса в google ещё и локально режем)
BANNED_KEYWORDS = [
    # оружие
    "пистолет", "оружие", "ружье", "автомат", "винтовка",
    "gun", "pistol", "rifle", "firearm", "weapon",
    # техника/инструменты
    "плуг", "трактор", "станок", "деталь", "механизм",
    "plow", "tractor", "machine", "equipment",
    # прочее “не одежда”
    "logo", "icon", "vector", "drawing", "illustration",
    "иконка", "логотип", "вектор", "рисунок", "иллюстрация",
]

# что добавляем к запросу (чтобы гугл был ближе к одежде)
QUERY_HINT = "одежда fashion outfit lookbook"

# что просим гугл исключать (на его стороне)
EXCLUDE_TERMS = "пистолет оружие gun pistol rifle weapon плуг plow tractor machine equipment"

def _is_banned_domain(s: str) -> bool:
    u = (s or "").lower()
    return any(d in u for d in BANNED_DOMAINS)

def _is_bad_image_url(url: str) -> bool:
    u = (url or "").lower()
    return any(re.search(p, u) for p in BAD_IMG_PATTERNS)

def _has_banned_keyword(*parts: str) -> bool:
    text = " ".join([p or "" for p in parts]).lower()
    return any(k in text for k in BANNED_KEYWORDS)

def _normalize_query(q: str) -> str:
    q = q.strip()
    return f"{q} {QUERY_HINT}".strip()

def _google_call(q: str, start: int, num: int) -> Dict[str, Any]:
    params = {
        "key": GOOGLE_CSE_API_KEY,
        "cx": GOOGLE_CSE_CX,
        "q": q,
        "excludeTerms": EXCLUDE_TERMS,
        "searchType": "image",
        "imgType": "photo",
        "imgSize": "xlarge",
        "safe": "active",
        "start": start,
        "num": num,
    }
    r = requests.get("https://www.googleapis.com/customsearch/v1", params=params, timeout=20)
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=r.text)
    return r.json()

def _get_next_start(data: Dict[str, Any]) -> Optional[int]:
    # Google кладёт nextPage вот так: data["queries"]["nextPage"][0]["startIndex"]
    q = data.get("queries") or {}
    next_page = (q.get("nextPage") or [])
    if not next_page:
        return None
    try:
        return int(next_page[0].get("startIndex"))
    except Exception:
        return None

def _extract_and_filter(raw_items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    cleaned: List[Dict[str, Any]] = []

    for it in raw_items:
        image_url = (it.get("link") or "").strip()
        image_meta = it.get("image") or {}
        page_url = (image_meta.get("contextLink") or "").strip()
        title = (it.get("title") or "").strip()
        site = (it.get("displayLink") or "").strip()

        if not image_url:
            continue

        if _is_banned_domain(site) or _is_banned_domain(page_url):
            continue

        if _is_bad_image_url(image_url):
            continue

        if _has_banned_keyword(title, site, page_url, image_url):
            continue

        cleaned.append({
            "image_url": image_url,
            "page_url": page_url,
            "title": title,
            "site": site,
        })

    return cleaned

@router.get("/images")
def search_images(
    q: str = Query(..., min_length=1),
    start: int = Query(1, ge=1),
    num: int = Query(10, ge=1, le=10),
) -> Dict[str, Any]:
    if not GOOGLE_CSE_API_KEY or not GOOGLE_CSE_CX:
        raise HTTPException(status_code=500, detail="Set GOOGLE_CSE_API_KEY and GOOGLE_CSE_CX in .env")

    # CSE обычно отдаёт до ~100 результатов
    if start > 91:
        return {
            "source": "images",
            "query": q,
            "total": 0,
            "items": [],
            "start": start,
            "num": num,
            "next_start": None,
            "has_more": False,
        }

    qq = _normalize_query(q)

    # Умный сбор: если страница пустая после фильтров — берём следующую
    collected: List[Dict[str, Any]] = []
    total = 0
    cur_start = start
    next_start: Optional[int] = None
    attempts = 0

    while len(collected) < num and attempts < 5 and cur_start <= 91:
        data = _google_call(qq, cur_start, num)
        raw_items = data.get("items") or []
        total = int((data.get("searchInformation") or {}).get("totalResults", 0) or 0)

        cleaned = _extract_and_filter(raw_items)
        collected.extend(cleaned)

        next_start = _get_next_start(data)

        # если есть следующая страница — можно пробовать дальше, если сейчас пусто
        if not next_start:
            break

        # готовим шаг дальше (на случай если нужно добрать после фильтра)
        cur_start = next_start
        attempts += 1

    # обрежем до num, чтобы фронт был стабильный
    collected = collected[:num]

    has_more = next_start is not None and next_start <= 91

    return {
        "source": "images",
        "query": qq,
        "total": total,
        "items": collected,
        "start": start,
        "num": num,
        "next_start": next_start,
        "has_more": has_more,
    }