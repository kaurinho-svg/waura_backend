from typing import Any, Callable, Dict, Awaitable
from aiogram import BaseMiddleware
from aiogram.types import TelegramObject, Message, CallbackQuery

from services.supabase_service import get_store_by_telegram_id, is_store_subscribed


SHOP_CALLBACKS = {"shop:add_product"}  # callbacks requiring subscription


class SubscriptionMiddleware(BaseMiddleware):
    """
    Checks subscription for shop owners trying to use premium features.
    Currently only applies to 'add_product' action.
    """

    async def __call__(
        self,
        handler: Callable[[TelegramObject, Dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: Dict[str, Any],
    ) -> Any:
        if isinstance(event, CallbackQuery):
            if event.data in SHOP_CALLBACKS:
                subscribed = is_store_subscribed(event.from_user.id)
                if not subscribed:
                    store = get_store_by_telegram_id(event.from_user.id)
                    if store:  # Only show message if they are a registered shop
                        await event.answer(
                            "⭐️ Эта функция доступна по подписке.\n"
                            "Напишите @waura_support для подключения.",
                            show_alert=True,
                        )
                        return
        return await handler(event, data)
