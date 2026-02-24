"""
Tracks which buyers have interacted with each bot (store).
Used for broadcast messages.
"""
from services.supabase_service import supabase
from typing import Optional


def register_buyer(store_id: str, telegram_id: int, username: Optional[str] = None) -> None:
    """Upsert buyer interaction record."""
    try:
        supabase.from_("bot_buyers").upsert({
            "store_id": store_id,
            "telegram_id": telegram_id,
            "username": username or "",
        }, on_conflict="store_id,telegram_id").execute()
    except Exception as e:
        print(f"register_buyer error: {e}")


def get_buyers_for_store(store_id: str) -> list:
    """Returns all buyer telegram IDs for a given store."""
    res = supabase.from_("bot_buyers").select("telegram_id").eq("store_id", store_id).execute()
    return [row["telegram_id"] for row in (res.data or [])]
