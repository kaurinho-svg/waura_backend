import re
from typing import Dict, List, Tuple

STYLE_SYNONYMS = {
    "old money": "old_money",
    "олд мани": "old_money",
    "тихая роскошь": "old_money",
    "quiet luxury": "old_money",

    "streetwear": "streetwear",
    "стритвир": "streetwear",
    "стрит": "streetwear",

    "y2k": "y2k",
    "гранж": "grunge",
    "gorpcore": "gorpcore",
}

STYLE_TO_TAGS: Dict[str, List[str]] = {
    "old_money": ["wool", "cashmere", "blazer", "trench", "loafers", "minimal", "neutral"],
    "streetwear": ["hoodie", "sneakers", "oversize", "logo", "cargo", "denim"],
    "y2k": ["low-rise", "baggy", "glossy", "cropped", "denim", "metallic"],
    "grunge": ["flannel", "distressed", "boots", "dark", "oversize"],
    "gorpcore": ["shell", "outdoor", "gore-tex", "hiking", "technical"],
}

def normalize_query(q: str) -> str:
    q = q.strip().lower()
    q = re.sub(r"\s+", " ", q)
    return q

def detect_style(q: str) -> Tuple[str | None, List[str]]:
    nq = normalize_query(q)

    style_key = None
    for syn, key in STYLE_SYNONYMS.items():
        if syn in nq:
            style_key = key
            break

    boosted = STYLE_TO_TAGS.get(style_key, []) if style_key else []
    return style_key, boosted