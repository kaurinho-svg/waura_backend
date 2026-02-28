"""
Tracks which buyers have interacted with each bot (store).
Used for broadcast messages and buyer profiles.
"""
from services.supabase_service import supabase
from typing import Optional


def register_buyer(store_id: str, telegram_id: int, username: Optional[str] = None, referred_by: Optional[int] = None) -> None:
    """Register buyer interaction, linking referral if new buyer."""
    try:
        # Check if buyer exists
        res = supabase.from_("bot_buyers").select("id").eq("store_id", store_id).eq("telegram_id", telegram_id).execute()
        if res.data:
            supabase.from_("bot_buyers").update({"username": username or ""}).eq("store_id", store_id).eq("telegram_id", telegram_id).execute()
        else:
            data = {
                "store_id": store_id,
                "telegram_id": telegram_id,
                "username": username or "",
            }
            if referred_by and referred_by != telegram_id:
                data["referred_by"] = referred_by
            supabase.from_("bot_buyers").insert(data).execute()
    except Exception as e:
        print(f"register_buyer error: {e}")


def get_buyer(store_id: str, telegram_id: int) -> Optional[dict]:
    """Returns buyer record for this store, or None if not found."""
    try:
        res = supabase.from_("bot_buyers").select("*").eq("store_id", store_id).eq("telegram_id", telegram_id).maybe_single().execute()
        return res.data
    except Exception as e:
        print(f"get_buyer error: {e}")
        return None


def save_buyer_name(store_id: str, telegram_id: int, name: str) -> None:
    """Saves buyer's real name to their bot_buyers record."""
    try:
        supabase.from_("bot_buyers").update({"name": name}).eq("store_id", store_id).eq("telegram_id", telegram_id).execute()
    except Exception as e:
        print(f"save_buyer_name error: {e}")


def save_buyer_language(store_id: str, telegram_id: int, language: str) -> None:
    """Saves buyer's preferred language ('ru', 'kk', 'en') to their bot_buyers record."""
    try:
        supabase.from_("bot_buyers").update({"language": language}).eq("store_id", store_id).eq("telegram_id", telegram_id).execute()
    except Exception as e:
        print(f"save_buyer_language error: {e}")


def get_buyers_for_store(store_id: str) -> list:
    """Returns all buyer telegram IDs for a given store."""
    res = supabase.from_("bot_buyers").select("telegram_id").eq("store_id", store_id).execute()
    return [row["telegram_id"] for row in (res.data or [])]
