from typing import Any, Callable, Dict, Awaitable
from aiogram import BaseMiddleware
from aiogram.types import TelegramObject


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
        data["store"] = self.store
        return await handler(event, data)
