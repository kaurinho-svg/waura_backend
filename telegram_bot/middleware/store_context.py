from typing import Any, Callable, Dict, Awaitable
from aiogram import BaseMiddleware
from aiogram.types import TelegramObject
from services.supabase_service import supabase


class StoreContextMiddleware(BaseMiddleware):
    """
    Injects 'store' dict into handler data based on which bot token
    received the update. Each bot instance has a unique token → store mapping.
    """

    def __init__(self, store: dict):
        """
        :param store: The bot_stores row for this bot instance.
        """
        self.store = store
        super().__init__()

    async def __call__(
        self,
        handler: Callable[[TelegramObject, Dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: Dict[str, Any],
    ) -> Any:
        # Fetch fresh store data from Supabase to ensure flags like `is_premium` are up-to-date
        # We can query by the known store ID. This is a fast query.
        try:
            res = supabase.from_("bot_stores").select("*").eq("id", self.store["id"]).maybe_single().execute()
            fresh_store = res.data if res.data else self.store
        except Exception as e:
            fresh_store = self.store
            
        data["store"] = fresh_store
        return await handler(event, data)
