import os
from dotenv import load_dotenv

load_dotenv(override=False)

TELEGRAM_BOT_TOKEN: str = os.getenv("TELEGRAM_BOT_TOKEN", "")
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
BACKEND_URL: str = os.getenv("BACKEND_URL", "https://waura-backend.onrender.com")

SUPER_ADMIN_IDS = [
    int(x.strip()) 
    for x in os.getenv("SUPER_ADMIN_IDS", "").split(",") 
    if x.strip().isdigit()
]

GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

if not TELEGRAM_BOT_TOKEN:
    raise ValueError("TELEGRAM_BOT_TOKEN is not set")
if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise ValueError("Supabase credentials are not set")
