import asyncio
import logging
import sys

from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage
from aiohttp import web

from config import TELEGRAM_BOT_TOKEN
from handlers import start, shop, catalog, tryon, orders, broadcast, admins, stylist, owner_stats
from middleware.store_context import StoreContextMiddleware
from services.supabase_service import get_all_stores_with_tokens
from services.scheduler import run_scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


def build_dispatcher(store: dict) -> Dispatcher:
    """Creates a Dispatcher for a single shop bot."""
    dp = Dispatcher(storage=MemoryStorage())

    # Inject store into every update
    dp.update.middleware(StoreContextMiddleware(store))

    # Register routers
    dp.include_router(start.router)
    dp.include_router(shop.router)
    dp.include_router(admins.router)
    dp.include_router(broadcast.router)
    dp.include_router(tryon.router)
    dp.include_router(orders.router)
    dp.include_router(catalog.router)
    dp.include_router(stylist.router)
    dp.include_router(owner_stats.router)

    return dp


async def run_bot(token: str, store: dict):
    """Runs one shop bot."""
    bot = Bot(token=token)
    dp = build_dispatcher(store)
    logger.info(f"🤖 Starting bot for store: {store['name']}")
    try:
        await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())
    except Exception as e:
        logger.error(f"Bot for {store['name']} crashed: {e}")
    finally:
        await bot.session.close()


async def main():
    stores = get_all_stores_with_tokens()

    if not stores:
        logger.warning("⚠️  No stores with bot_token found. Add stores to bot_stores table first.")
        if TELEGRAM_BOT_TOKEN:
            placeholder_store = {
                "id": "demo",
                "name": "Waura Demo",
                "telegram_id": None,
                "kaspi_phone": "",
                "kaspi_pay_url": "",
            }
            # Instead of await run_bot(TELEGRAM_BOT_TOKEN, placeholder_store),
            # we will run it as a task so the web server can also run.
            asyncio.create_task(run_bot(TELEGRAM_BOT_TOKEN, placeholder_store))
        else:
            return

    if stores:
        # Build {store_id: Bot} map for the scheduler
        bots_map = {
            store["id"]: Bot(token=store["bot_token"])
            for store in stores
            if store.get("bot_token")
        }

        # Run all bots + scheduler concurrently
        for store in stores:
            if store.get("bot_token"):
                asyncio.create_task(run_bot(store["bot_token"], store))
        
        asyncio.create_task(run_scheduler(bots_map))
        logger.info(f"🚀 Started shop bot(s) + scheduler")

    # Define a simple health check handler for Render
    async def health_check(request):
        return web.Response(text="Bot is running!")

    # Start the aiohttp web server
    app = web.Application()
    app.router.add_get('/', health_check)
    app.router.add_get('/health', health_check)

    runner = web.AppRunner(app)
    await runner.setup()
    
    import os
    port = int(os.environ.get("PORT", 8080))
    site = web.TCPSite(runner, '0.0.0.0', port)
    await site.start()
    
    logger.info(f"🌐 Web server started on port {port} (for Render health checks)")

    # Keep the main coroutine running indefinitely
    await asyncio.Event().wait()


if __name__ == "__main__":
    asyncio.run(main())
