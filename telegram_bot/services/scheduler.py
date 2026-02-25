"""
Scheduler: runs background tasks for all shop bots.
- Subscription expiry warnings (3 days and 1 day before)
- Checks run every hour
"""
import asyncio
import logging
from datetime import datetime, timezone, timedelta

from aiogram import Bot

from services.supabase_service import supabase

logger = logging.getLogger(__name__)


async def check_subscriptions(bots: dict[str, Bot]):
    """
    Checks all subscribed stores and sends warnings when subscription
    is expiring in 3 days or 1 day.
    bots: {store_id: Bot instance}
    """
    now = datetime.now(timezone.utc)
    warn_thresholds = [
        (timedelta(days=3), "через 3 дня"),
        (timedelta(days=1), "завтра"),
    ]

    try:
        res = supabase.from_("bot_stores").select("id, telegram_id, name, subscription_until, is_subscribed").eq("is_subscribed", True).execute()
        stores = res.data or []
    except Exception as e:
        logger.error(f"Subscription check failed: {e}")
        return

    for store in stores:
        until_str = store.get("subscription_until")
        if not until_str:
            continue
        try:
            until = datetime.fromisoformat(until_str.replace("Z", "+00:00"))
        except ValueError:
            continue

        time_left = until - now
        bot = bots.get(store["id"])
        if not bot:
            continue

        for threshold, label in warn_thresholds:
            # Send warning if within a 1-hour window around the threshold
            if threshold <= time_left < threshold + timedelta(hours=1):
                try:
                    await bot.send_message(
                        chat_id=store["telegram_id"],
                        text=(
                            f"⚠️ <b>Подписка истекает {label}!</b>\n\n"
                            f"Магазин <b>{store['name']}</b> потеряет доступ к боту.\n"
                            f"Напишите администратору для продления."
                        ),
                        parse_mode="HTML",
                    )
                    logger.info(f"Sent subscription warning to store {store['name']}")
                except Exception as e:
                    logger.warning(f"Failed to send warning to {store['name']}: {e}")
                break


async def run_scheduler(bots: dict[str, Bot]):
    """Runs periodic tasks every hour."""
    logger.info("⏰ Scheduler started")
    while True:
        await check_subscriptions(bots)
        await asyncio.sleep(3600)  # check every hour
