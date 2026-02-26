import logging, sys, asyncio, os
logging.basicConfig(level=logging.INFO)
from dotenv import load_dotenv
load_dotenv('.env')
sys.path.append('.')
from services.supabase_service import get_abandoned_pending_orders

def test():
    orders = get_abandoned_pending_orders(minutes=20)
    print(f'Found {len(orders)} orders: {orders}')

test()
