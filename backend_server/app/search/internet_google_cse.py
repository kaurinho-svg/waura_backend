# app/search/internet_google_cse.py

import os
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
import httpx

load_dotenv()

GOOGLE_CSE_API_KEY = os.getenv("GOOGLE_CSE_API_KEY")
GOOGLE_CSE_CX = os.getenv("GOOGLE_CSE_CX")

# Опционально: allowlist доменов (comma-separated)
# Пример: FASHION_SITES=zara.com,hm.com,uniqlo.com,asos.com,farfetch.com
FASHION_SITES_RAW = os.getenv("FASHION_SITES", "") or ""
FASHION_SITES: List[str] = [d.strip() for d in FASHION_SITES_RAW.split(",") if d.strip()]

# Опционально: бан-лист мусора
# Пример: BLOCK_SITES=reddit.com,vk.com
BLOCK_SITES_RAW = os.getenv("BLOCK_SITES", "") or ""
BLOCK_SITES: List[str] = [d.strip() for d in BLOCK_SITES_RAW.split(",") if d.strip()]

GOOGLE_CSE_URL = "https://www.googleapis.com/customsearch/v1"


class GoogleCSEError(RuntimeError):
    pass


def _domain(host_or_url: str) -> str:
    try:
        if "://" not in host_or_url:
            return host_or_url.lower().strip()
        from urllib.parse import urlparse
        return (urlparse(host_or_url).netloc or "").lower().strip()
    except Exception:
        return host_or_url.lower().strip()


def _is_blocked(display_link: str) -> bool:
    dl = _domain(display_link)
    for b in BLOCK_SITES:
        b = _domain(b)
        if dl == b or dl.endswith("." + b):
            return True
    return False


def _maybe_add_sites_filter(q: str) -> str:
    """
    Если задан allowlist доменов — мягко ограничиваем выдачу.
    Важно: слишком много доменов ухудшает/ломает запрос. Держи 10–40.
    """
    base = q.strip()
    if not base:
        return base

    if FASHION_SITES:
        sites = " OR ".join([f"site:{d}" for d in FASHION_SITES[:40]])
        base = f"({base}) ({sites})"
    return base


async def _call_cse(params: Dict[str, Any]) -> Dict[str, Any]:
    if not GOOGLE_CSE_API_KEY or not GOOGLE_CSE_CX:
        raise GoogleCSEError(
            "Google CSE is not configured. Set GOOGLE_CSE_API_KEY and GOOGLE_CSE_CX in .env"
        )

    async with httpx.AsyncClient(timeout=25) as client:
        r = await client.get(GOOGLE_CSE_URL, params=params)
        if r.status_code != 200:
            raise GoogleCSEError(f"Google CSE error: {r.status_code} {r.text}")
        return r.json()


def _next_start(data: Dict[str, Any]) -> Optional[int]:
    try:
        np = (data.get("queries") or {}).get("nextPage")
        if np and isinstance(np, list) and np[0].get("startIndex"):
            return int(np[0]["startIndex"])
    except Exception:
        pass
    return None


def _parse_total(data: Dict[str, Any], fallback: int) -> int:
    total_str = (((data.get("searchInformation") or {}).get("totalResults")) or "0")
    try:
        return int(total_str)
    except Exception:
        return fallback


async def google_cse_search(q: str, start: int = 1, num: int = 10) -> Dict[str, Any]:
    """
    Обычный веб-поиск (страницы). Оставил, чтобы твой импорт не ломался.
    """
    num = max(1, min(10, int(num)))
    start = max(1, int(start))

    q2 = _maybe_add_sites_filter(q)

    params = {
        "key": GOOGLE_CSE_API_KEY,
        "cx": GOOGLE_CSE_CX,
        "q": q2,
        "num": num,
        "start": start,
        "safe": "active",
        "hl": "ru",
        "gl": "ru",
        "lr": "lang_ru",
    }

    data = await _call_cse(params)
    items_out: List[Dict[str, Any]] = []

    for it in (data.get("items") or []):
        display_link = (it.get("displayLink") or "").strip()
        if display_link and _is_blocked(display_link):
            continue

        items_out.append(
            {
                "title": it.get("title"),
                "snippet": it.get("snippet"),
                "link": it.get("link"),
                "displayLink": display_link,
            }
        )

    total = _parse_total(data, len(items_out))
    ns = _next_start(data)
    return {
        "source": "internet",
        "mode": "web",
        "q": q,
        "q_effective": q2,
        "total": total,
        "start": start,
        "num": num,
        "items": items_out,
        "next_start": ns,
        "has_more": ns is not None and len(data.get("items") or []) > 0,
    }


async def google_cse_image_search(q: str, start: int = 1, num: int = 10) -> Dict[str, Any]:
    """
    ВАЖНО: это должен быть тот же режим, что вкладка “Изображения” в CSE.
    Тут мы НЕ добавляем "product photo" (оно тебе и ломало RU выдачу).
    """
    num = max(1, min(10, int(num)))
    start = max(1, int(start))

    q2 = _maybe_add_sites_filter(q)

    params = {
        "key": GOOGLE_CSE_API_KEY,
        "cx": GOOGLE_CSE_CX,
        "q": q2,
        "num": num,
        "start": start,

        "searchType": "image",
        "safe": "active",
        "imgType": "photo",

        # локаль/язык как у тебя в браузере
        "hl": "ru",
        "gl": "ru",
        "lr": "lang_ru",

        # берём width/height чтобы выкидывать мелкие логотипы/иконки
        "fields": "queries/nextPage,searchInformation(totalResults),items(link,displayLink,image/thumbnailLink,image/contextLink,image/width,image/height)",
    }

    data = await _call_cse(params)

    raw_items = data.get("items", []) or []
    items: List[Dict[str, Any]] = []

    for it in raw_items:
        display_link = (it.get("displayLink") or "").strip()
        if not display_link:
            continue
        if _is_blocked(display_link):
            continue

        img_url = (it.get("link") or "").strip()
        image_info = it.get("image") or {}
        thumb = (image_info.get("thumbnailLink") or "").strip()
        context = (image_info.get("contextLink") or "").strip()

        w = image_info.get("width")
        h = image_info.get("height")

        # фильтр против иконок/логотипов
        try:
            wi = int(w) if w is not None else 0
            hi = int(h) if h is not None else 0
            if wi and hi:
                if wi < 250 or hi < 250:
                    continue
        except Exception:
            pass

        if not img_url:
            continue

        items.append(
            {
                "image_url": img_url,
                "thumbnail_url": thumb or img_url,
                "page_url": context or img_url,
                "site": display_link,
            }
        )

    total = _parse_total(data, len(items))
    ns = _next_start(data)

    return {
        "source": "internet",
        "mode": "image",
        "q": q,
        "q_effective": q2,
        "total": total,
        "start": start,
        "num": num,
        "items": items,
        "next_start": ns,
        "has_more": ns is not None and len(raw_items) > 0,
    }