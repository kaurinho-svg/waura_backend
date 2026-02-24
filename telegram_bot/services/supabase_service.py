from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
from typing import Optional

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


# ─── STORES ───────────────────────────────────────────────────────────────────

def get_all_stores_with_tokens() -> list:
    """Returns all stores that have a bot_token set."""
    res = supabase.from_("bot_stores").select("*").neq("bot_token", "").execute()
    return res.data or []


def get_store_by_telegram_id(telegram_id: int) -> Optional[dict]:
    res = supabase.from_("bot_stores").select("*").eq("telegram_id", telegram_id).maybe_single().execute()
    return res.data


def create_store(telegram_id: int, name: str, bot_token: str, kaspi_phone: str = "") -> dict:
    res = supabase.from_("bot_stores").insert({
        "telegram_id": telegram_id,
        "name": name,
        "bot_token": bot_token,
        "kaspi_phone": kaspi_phone,
        "is_subscribed": False,
    }).execute()
    return res.data[0]


def update_store(store_id: str, data: dict) -> dict:
    res = supabase.from_("bot_stores").update(data).eq("id", store_id).execute()
    return res.data[0]


def get_store_admins(store_id: str) -> list[int]:
    """Returns list of extra admin telegram_ids for a store."""
    res = supabase.from_("bot_stores").select("admin_ids").eq("id", store_id).maybe_single().execute()
    return res.data.get("admin_ids") or [] if res.data else []


def add_admin_to_store(store_id: str, telegram_id: int) -> None:
    """Adds telegram_id to the admin_ids array of a store (no duplicates)."""
    admins = get_store_admins(store_id)
    if telegram_id not in admins:
        admins.append(telegram_id)
        supabase.from_("bot_stores").update({"admin_ids": admins}).eq("id", store_id).execute()


def remove_admin_from_store(store_id: str, telegram_id: int) -> None:
    """Removes telegram_id from the admin_ids array of a store."""
    admins = get_store_admins(store_id)
    admins = [a for a in admins if a != telegram_id]
    supabase.from_("bot_stores").update({"admin_ids": admins}).eq("id", store_id).execute()


# ─── PRODUCTS ─────────────────────────────────────────────────────────────────

def get_products_by_store(store_id: str) -> list:
    res = (supabase.from_("bot_products")
           .select("*")
           .eq("store_id", store_id)
           .eq("is_active", True)
           .execute())
    return res.data or []


def get_products_by_store_and_category(store_id: str, category: Optional[str] = None) -> list:
    query = (supabase.from_("bot_products")
             .select("*")
             .eq("store_id", store_id)
             .eq("is_active", True))
    if category:
        query = query.eq("category", category)
    return query.execute().data or []


def get_categories_for_store(store_id: str) -> list[str]:
    res = (supabase.from_("bot_products")
           .select("category")
           .eq("store_id", store_id)
           .eq("is_active", True)
           .execute())
    cats = {row["category"] for row in (res.data or []) if row.get("category")}
    return sorted(cats)


def get_product_by_id(product_id: str) -> Optional[dict]:
    res = (supabase.from_("bot_products")
           .select("*, bot_stores(name, kaspi_phone, telegram_id)")
           .eq("id", product_id)
           .maybe_single()
           .execute())
    return res.data


def create_product(store_id: str, data: dict) -> dict:
    data["store_id"] = store_id
    data["is_active"] = True
    res = supabase.from_("bot_products").insert(data).execute()
    return res.data[0]


def delete_product(product_id: str) -> None:
    supabase.from_("bot_products").update({"is_active": False}).eq("id", product_id).execute()


# ─── SIZES ────────────────────────────────────────────────────────────────────

def get_sizes_by_product(product_id: str) -> list:
    res = (supabase.from_("bot_product_sizes")
           .select("*")
           .eq("product_id", product_id)
           .gt("quantity", 0)
           .execute())
    return res.data or []


def add_size(product_id: str, size: str, quantity: int) -> dict:
    res = supabase.from_("bot_product_sizes").insert({
        "product_id": product_id,
        "size": size,
        "quantity": quantity,
    }).execute()
    return res.data[0]


def decrement_size_quantity(product_id: str, size: str) -> None:
    res = (supabase.from_("bot_product_sizes")
           .select("id, quantity")
           .eq("product_id", product_id)
           .eq("size", size)
           .maybe_single()
           .execute())
    if res.data and res.data["quantity"] > 0:
        supabase.from_("bot_product_sizes").update(
            {"quantity": res.data["quantity"] - 1}
        ).eq("id", res.data["id"]).execute()


# ─── ORDERS ───────────────────────────────────────────────────────────────────

def create_order(buyer_telegram_id: int, product_id: str, size: str) -> dict:
    res = supabase.from_("bot_orders").insert({
        "buyer_telegram_id": buyer_telegram_id,
        "product_id": product_id,
        "size": size,
        "status": "pending",
    }).execute()
    return res.data[0]


def update_order_status(order_id: str, status: str) -> None:
    supabase.from_("bot_orders").update({"status": status}).eq("id", order_id).execute()


def update_order_payment_screenshot(order_id: str, file_id: str) -> None:
    supabase.from_("bot_orders").update({
        "status": "awaiting_confirmation",
        "payment_screenshot_id": file_id,
    }).eq("id", order_id).execute()


def get_order_by_id(order_id: str) -> Optional[dict]:
    res = (supabase.from_("bot_orders")
           .select("*, bot_products(name, store_id, bot_stores(telegram_id, name, kaspi_phone))")
           .eq("id", order_id)
           .maybe_single()
           .execute())
    return res.data


# ─── ANALYTICS ────────────────────────────────────────────────────────────────

def get_store_analytics(store_id: str) -> dict:
    """Returns analytics data for a specific store."""
    stats = {
        "total_buyers": 0,
        "active_products": 0,
        "total_orders": 0,
        "confirmed_orders": 0,
    }
    
    # Get buyers count
    res_buyers = supabase.from_("bot_buyers").select("id", count="exact").eq("store_id", store_id).execute()
    if res_buyers.count:
        stats["total_buyers"] = res_buyers.count

    # Get active products count
    res_products = supabase.from_("bot_products").select("id", count="exact").eq("store_id", store_id).eq("is_active", True).execute()
    if res_products.count:
        stats["active_products"] = res_products.count

    # Get orders count (requires joining with products to filter by store_id)
    # Since we can't easily count joined tables directly in standard supabase-py without RPC, 
    # we'll fetch products first, then count orders for those products.
    products = get_products_by_store(store_id)
    product_ids = [p["id"] for p in products]
    
    if product_ids:
        # Total orders
        res_orders = supabase.from_("bot_orders").select("id", count="exact").in_("product_id", product_ids).execute()
        if res_orders.count:
            stats["total_orders"] = res_orders.count
            
        # Confirmed orders
        res_confirmed = supabase.from_("bot_orders").select("id", count="exact").in_("product_id", product_ids).eq("status", "confirmed").execute()
        if res_confirmed.count:
            stats["confirmed_orders"] = res_confirmed.count

    return stats
