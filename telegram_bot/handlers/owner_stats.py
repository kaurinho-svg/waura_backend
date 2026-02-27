"""
Owner-only statistics command.
Works in ANY store bot — only responds to SUPER_ADMIN_IDS.
Commands:
  /owner_stats — full stats table of all stores (tier, generations left, FAL costs)
"""
from aiogram import Router
from aiogram.filters import Command
from aiogram.types import Message

from config import SUPER_ADMIN_IDS
from services.supabase_service import supabase

router = Router()

# Cost per generation per tier (USD)
COST_PER_GEN = {
    "VIP":     0.15,
    "Premium": 0.08,
    "Basic":   0.039,
}

# Generation limit per tier
GEN_LIMIT = {
    "VIP":     150,
    "Premium": 100,
    "Basic":   50,
}


def get_all_stores_stats() -> list[dict]:
    """Fetches all active stores with tier and generation info."""
    res = supabase.from_("bot_stores").select(
        "id, name, is_premium, is_vip, generations_left, is_subscribed, subscription_until"
    ).execute()
    return res.data or []


def build_stats_text(stores: list[dict], period_label: str = "") -> str:
    """Builds a formatted stats message."""
    if not stores:
        return "📭 Нет подключённых магазинов."

    total_cost_usd = 0.0
    lines = []

    for s in stores:
        if s.get("is_vip"):
            tier = "VIP"
        elif s.get("is_premium"):
            tier = "Premium"
        else:
            tier = "Basic"

        limit = GEN_LIMIT[tier]
        left = s.get("generations_left") or 0
        used = max(0, limit - left)
        cost_usd = used * COST_PER_GEN[tier]
        total_cost_usd += cost_usd
        cost_kzt = cost_usd * 500  # approximate KZT rate

        active = "✅" if s.get("is_subscribed") else "❌"
        lines.append(
            f"{active} <b>{s['name']}</b> [{tier}]\n"
            f"   Генерации: {left}/{limit} (использовано {used})\n"
            f"   Трата на FAL: ~${cost_usd:.2f} (~{cost_kzt:,.0f} ₸)"
        )

    total_kzt = total_cost_usd * 500
    header = f"📊 <b>Статистика магазинов{' — ' + period_label if period_label else ''}</b>\n"
    header += f"Всего магазинов: {len(stores)}\n\n"
    footer = f"\n\n💸 <b>Итого трат на FAL: ~${total_cost_usd:.2f} (~{total_kzt:,.0f} ₸)</b>"

    return header + "\n\n".join(lines) + footer


@router.message(Command("owner_stats"))
async def owner_stats(message: Message):
    """Shows all stores stats — only for SUPER_ADMIN_IDS."""
    if message.from_user.id not in SUPER_ADMIN_IDS:
        # Silently ignore — don't reveal the command exists
        return

    stores = get_all_stores_stats()
    text = build_stats_text(stores)
    await message.answer(text, parse_mode="HTML")
