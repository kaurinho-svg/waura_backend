import sys, asyncio, os
from dotenv import load_dotenv
load_dotenv('.env')
sys.path.append('.')
from aiogram import Bot
from services.scheduler import check_abandoned_carts
from services.supabase_service import supabase

async def test():
    res = supabase.from_('bot_stores').select('id, bot_token').neq('bot_token', '').execute()
    bots = {s['id']: Bot(s['bot_token']) for s in res.data}
    await check_abandoned_carts(bots)
    print('Job finished')

asyncio.run(test())
