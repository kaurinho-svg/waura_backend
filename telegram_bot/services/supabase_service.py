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


def decrement_store_generations(store_id: str, current_generations: int) -> None:
    if current_generations > 0:
        supabase.from_("bot_stores").update({"generations_left": current_generations - 1}).eq("id", store_id).execute()


def add_store_generations(telegram_id: int, amount: int) -> Optional[dict]:
    store = get_store_by_telegram_id(telegram_id)
    if not store:
        return None
    current = store.get("generations_left") or 0
    res = supabase.from_("bot_stores").update({"generations_left": current + amount}).eq("id", store["id"]).execute()
    return res.data[0] if res.data else None


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
        "total_revenue": 0.0,
    }
    
    # Get buyers count
    res_buyers = supabase.from_("bot_buyers").select("id", count="exact").eq("store_id", store_id).execute()
    if res_buyers.count:
        stats["total_buyers"] = res_buyers.count

    # Get active products count
    res_products = supabase.from_("bot_products").select("id", count="exact").eq("store_id", store_id).eq("is_active", True).execute()
    if res_products.count:
        stats["active_products"] = res_products.count

    # Get orders and calculate revenue
    products = get_products_by_store(store_id)
    product_ids = [p["id"] for p in products]
    product_prices = {p["id"]: p["price"] for p in products}
    
    if product_ids:
        # Fetch all orders for these products to count and calculate revenue
        # We need the product_id and status for each order
        res_orders = supabase.from_("bot_orders").select("id, product_id, status").in_("product_id", product_ids).execute()
        orders = res_orders.data or []
        
        stats["total_orders"] = len(orders)
        
        for order in orders:
            if order.get("status") == "confirmed":
                stats["confirmed_orders"] += 1
                stats["total_revenue"] += float(product_prices.get(order["product_id"], 0))

    return stats


# ─── REFERRALS & PROMOCODES ───────────────────────────────────────────────────

def get_buyer(store_id: str, telegram_id: int) -> Optional[dict]:
    res = supabase.from_("bot_buyers").select("*").eq("store_id", store_id).eq("telegram_id", telegram_id).maybe_single().execute()
    return res.data

def mark_referral_rewarded(buyer_id: str) -> None:
    supabase.from_("bot_buyers").update({"referral_rewarded": True}).eq("id", buyer_id).execute()

def create_promocode(store_id: str, telegram_id: int, discount_percent: int = 50) -> dict:
    res = supabase.from_("bot_promocodes").insert({
        "store_id": store_id,
        "buyer_telegram_id": telegram_id,
        "discount_percent": discount_percent
    }).execute()
    return res.data[0]

def get_unused_promocode(store_id: str, telegram_id: int) -> Optional[dict]:
    res = supabase.from_("bot_promocodes").select("*").eq("store_id", store_id).eq("buyer_telegram_id", telegram_id).eq("is_used", False).order("created_at", desc=True).limit(1).execute()
    return res.data[0] if res.data else None

def mark_promocode_used(promocode_id: str) -> None:
    supabase.from_("bot_promocodes").update({"is_used": True}).eq("id", promocode_id).execute()

# ─── ABANDONED CARTS ──────────────────────────────────────────────────────────

def get_abandoned_pending_orders(minutes: int = 30) -> list:
    from datetime import datetime, timezone, timedelta
    threshold = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    res = supabase.from_("bot_orders").select("*, bot_products(name, store_id, bot_stores(telegram_id, bot_token, name))").eq("status", "pending").eq("pending_warned", False).execute()
    
    abandoned = []
    for order in (res.data or []):
        created_str = order.get("created_at")
        if not created_str:
            continue
        created_at_dt = datetime.fromisoformat(created_str.replace("Z", "+00:00"))
        if created_at_dt < threshold:
            abandoned.append(order)
    return abandoned

def mark_order_pending_warned(order_id: str) -> None:
    supabase.from_("bot_orders").update({"pending_warned": True}).eq("id", order_id).execute()

# ─── CRM ──────────────────────────────────────────────────────────────────────

def get_buyer_order_history(store_id: str, buyer_telegram_id: int) -> dict:
    """Calculates order history for a buyer in a specific store."""
    history = {
        "total_spent": 0.0,
        "total_orders": 0,
        "last_order_date": None,
        "is_first_time": True
    }
    
    products = get_products_by_store(store_id)
    product_ids = [p["id"] for p in products]
    product_prices = {p["id"]: p["price"] for p in products}

    if not product_ids:
        return history

    res = (supabase.from_("bot_orders")
           .select("product_id, created_at")
           .eq("buyer_telegram_id", buyer_telegram_id)
           .eq("status", "confirmed")
           .in_("product_id", product_ids)
           .order("created_at", desc=True)
           .execute())
    
    orders = res.data or []
    if orders:
        history["is_first_time"] = False
        history["total_orders"] = len(orders)
        history["last_order_date"] = orders[0]["created_at"]
        
        for o in orders:
            history["total_spent"] += float(product_prices.get(o["product_id"], 0))
            
    return history
