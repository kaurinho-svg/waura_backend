import os
from dotenv import load_dotenv
import meilisearch

MEILI_URL = os.getenv("MEILI_URL", "http://localhost:7700")
MEILI_MASTER_KEY = os.getenv("MEILI_MASTER_KEY", "12345628")
MEILI_INDEX = os.getenv("MEILI_INDEX", "products")

client = meilisearch.Client(MEILI_URL, MEILI_MASTER_KEY)

def get_index():
    return client.index(MEILI_INDEX)

def build_filter(filters: dict) -> str | None:
    parts = []

    def eq(field: str, value: str):
        safe = value.replace('"', '\\"')
        parts.append(f'{field} = "{safe}"')

    if filters.get("gender"):
        eq("gender", filters["gender"])
    if filters.get("category"):
        eq("category", filters["category"])
    if filters.get("brand"):
        eq("brand", filters["brand"])
    if filters.get("color"):
        eq("color", filters["color"])

    if filters.get("price_min") is not None:
        parts.append(f'price >= {float(filters["price_min"])}')
    if filters.get("price_max") is not None:
        parts.append(f'price <= {float(filters["price_max"])}')

    return " AND ".join(parts) if parts else None