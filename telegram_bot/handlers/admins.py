"""
Admin management handler.
Commands (owner-only):
  /addadmin <telegram_id>    — grant admin rights
  /removeadmin <telegram_id> — revoke admin rights
  /listadmins                — show current admins
"""
from aiogram import Router
from aiogram.filters import Command
from aiogram.types import Message

from services.supabase_service import (
    add_admin_to_store,
    remove_admin_from_store,
    get_store_admins,
    get_store_analytics,
)

router = Router()


def is_primary_owner(telegram_id: int, store: dict) -> bool:
    """Only the primary owner (telegram_id in store row) can manage admins."""
    return store.get("telegram_id") == telegram_id


# ─── /addadmin <id> ───────────────────────────────────────────────────────────

@router.message(Command("addadmin"))
async def add_admin(message: Message, store: dict):
    if not is_primary_owner(message.from_user.id, store):
        await message.answer("⛔️ Только главный владелец магазина может добавлять администраторов.")
        return

    args = message.text.split(maxsplit=1)
    if len(args) < 2 or not args[1].strip().lstrip("-").isdigit():
        await message.answer(
            "❌ Укажите Telegram ID пользователя.\n\n"
            "Пример: <code>/addadmin 123456789</code>\n\n"
            "💡 Попросите пользователя написать боту @userinfobot — он покажет ID.",
            parse_mode="HTML",
        )
        return

    new_admin_id = int(args[1].strip())

    if new_admin_id == store.get("telegram_id"):
        await message.answer("ℹ️ Этот пользователь уже является главным владельцем магазина.")
        return

    admins = get_store_admins(store["id"])
    if new_admin_id in admins:
        await message.answer(f"ℹ️ Пользователь <code>{new_admin_id}</code> уже является администратором.", parse_mode="HTML")
        return

    add_admin_to_store(store["id"], new_admin_id)
    await message.answer(
        f"✅ Пользователь <code>{new_admin_id}</code> добавлен как администратор магазина <b>{store['name']}</b>.\n\n"
        f"Он теперь имеет доступ к /admin и /broadcast.",
        parse_mode="HTML",
    )


# ─── /removeadmin <id> ────────────────────────────────────────────────────────

@router.message(Command("removeadmin"))
async def remove_admin(message: Message, store: dict):
    if not is_primary_owner(message.from_user.id, store):
        await message.answer("⛔️ Только главный владелец магазина может удалять администраторов.")
        return

    args = message.text.split(maxsplit=1)
    if len(args) < 2 or not args[1].strip().lstrip("-").isdigit():
        await message.answer(
            "❌ Укажите Telegram ID пользователя.\n\n"
            "Пример: <code>/removeadmin 123456789</code>",
            parse_mode="HTML",
        )
        return

    admin_id = int(args[1].strip())
    admins = get_store_admins(store["id"])

    if admin_id not in admins:
        await message.answer(f"ℹ️ Пользователь <code>{admin_id}</code> не является администратором.", parse_mode="HTML")
        return

    remove_admin_from_store(store["id"], admin_id)
    await message.answer(
        f"✅ Права администратора у пользователя <code>{admin_id}</code> удалены.",
        parse_mode="HTML",
    )


# ─── /listadmins ──────────────────────────────────────────────────────────────

@router.message(Command("listadmins"))
async def list_admins(message: Message, store: dict):
    if not is_primary_owner(message.from_user.id, store):
        await message.answer("⛔️ Только главный владелец магазина может просматривать список администраторов.")
        return

    admins = get_store_admins(store["id"])

    if not admins:
        await message.answer(
            f"👥 <b>Администраторы магазина {store['name']}</b>\n\n"
            f"👑 Владелец: <code>{store['telegram_id']}</code>\n\n"
            f"Дополнительных администраторов нет.\n"
            f"Добавьте командой /addadmin",
            parse_mode="HTML",
        )
        return

    admin_list = "\n".join(f"  • <code>{a}</code>" for a in admins)
    await message.answer(
        f"👥 <b>Администраторы магазина {store['name']}</b>\n\n"
        f"👑 Владелец: <code>{store['telegram_id']}</code>\n\n"
        f"🔑 Дополнительные администраторы ({len(admins)}):\n{admin_list}",
        parse_mode="HTML",
    )


# ─── /stats ───────────────────────────────────────────────────────────────────

@router.message(Command("stats"))
async def show_stats(message: Message, store: dict):
    from handlers.shop import is_owner
    if not is_owner(message.from_user.id, store):
        await message.answer("⛔️ У вас нет доступа к статистике магазина.")
        return

    await message.answer("📊 Сбор статистики, подождите...")
    stats = get_store_analytics(store["id"])

    await message.answer(
        f"📊 <b>Аналитика магазина {store['name']}</b>\n\n"
        f"👥 Уникальных покупателей: <b>{stats['total_buyers']}</b>\n"
        f"📦 Активных товаров: <b>{stats['active_products']}</b>\n\n"
        f"🛒 Всего заказов: <b>{stats['total_orders']}</b>\n"
        f"✅ Подтвержденных заказов: <b>{stats['confirmed_orders']}</b>\n\n"
        f"💰 <b>Выручка: {stats['total_revenue']:,.0f} ₸</b>",
        parse_mode="HTML",
    )
