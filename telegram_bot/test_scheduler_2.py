import sys, asyncio, logging
logging.basicConfig(level=logging.INFO)
sys.path.append('.')
from aiogram import Bot
from services.supabase_service import supabase
from services.scheduler import check_abandoned_carts

async def test():
    res = supabase.from_('bot_stores').select('id, bot_token').neq('bot_token', '').execute()
    bots = {s['id']: Bot(token=s['bot_token']) for s in res.data}
    await check_abandoned_carts(bots)
    print('Job finished')

asyncio.run(test())
