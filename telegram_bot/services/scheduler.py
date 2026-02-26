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


async def check_abandoned_carts(bots: dict[str, Bot]):
    """Finds orders that are pending for >30 mins and sends a reminder."""
    from services.supabase_service import get_abandoned_pending_orders, mark_order_pending_warned
    
    try:
        abandoned_orders = get_abandoned_pending_orders(minutes=30)
    except Exception as e:
        logger.error(f"Abandoned carts check failed: {e}")
        return

    for order in abandoned_orders:
        product = order.get("bot_products") or {}
        store_info = product.get("bot_stores") or {}
        bot = bots.get(store_info.get("id"))
        if not bot:
            continue
            
        buyer_id = order.get("buyer_telegram_id")
        if not buyer_id:
            continue
            
        try:
            from keyboards.buyer_kb import payment_kb
            kaspi_phone = store_info.get("kaspi_phone", "")
            kaspi_pay_url = store_info.get("kaspi_pay_url", "")
            
            if kaspi_pay_url:
                payment_text = f"💳 Оплата через Kaspi Pay (по кнопке ниже)"
            elif kaspi_phone:
                payment_text = f"📱 Kaspi перевод: <b>{kaspi_phone}</b>"
            else:
                payment_text = "💳 Уточните реквизиты у магазина"

            await bot.send_message(
                chat_id=buyer_id,
                text=(
                    f"⚠️ <b>Вы не завершили покупку!</b>\n\n"
                    f"Товар <b>{product.get('name', 'из корзины')}</b> может быть распродан.\n\n"
                    f"{payment_text}\n"
                    f"<i>Ждем ваш скриншот подтверждения перевода!</i> 👇"
                ),
                parse_mode="HTML",
                reply_markup=payment_kb(order["id"], kaspi_pay_url=kaspi_pay_url)
            )
            mark_order_pending_warned(order["id"])
            logger.info(f"Sent abandoned cart warning for order {order['id']}")
        except Exception as e:
            logger.warning(f"Failed to send abandoned cart warning to {buyer_id}: {e}")


async def run_abandoned_carts_scheduler(bots: dict[str, Bot]):
    """Runs abandoned carts check every 5 minutes."""
    while True:
        await check_abandoned_carts(bots)
        await asyncio.sleep(300)


async def run_scheduler(bots: dict[str, Bot]):
    """Runs periodic tasks every hour."""
    asyncio.create_task(run_abandoned_carts_scheduler(bots))
    logger.info("⏰ Scheduler started")
    while True:
        await check_subscriptions(bots)
        await asyncio.sleep(3600)  # check every hour
