import sys, asyncio
sys.path.append('.')
from services.supabase_service import supabase

res = supabase.from_('bot_orders').update({'pending_warned': False}).eq('status', 'pending').execute()
print(f'Reset {len(res.data)} orders')
