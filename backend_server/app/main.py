"""Main FastAPI application entry point."""
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routes import nano_banana, remove_bg, ai_consultant, styles, visual_search, video_generation
from app.search.router import router as search_router
from app.search.suggest_router import router as suggest_router
from app.search.internet_images import router as internet_images_router

# ... (rest of imports)


BASE_DIR = Path(__file__).resolve().parent.parent  # backend_server/
load_dotenv(BASE_DIR / ".env", override=True)  # <-- важно

os.makedirs(settings.STATIC_DIR, exist_ok=True)
os.makedirs(os.path.join(settings.STATIC_DIR, "temp"), exist_ok=True)

logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Outfit Assistant Backend Server...")
    logger.info(f"API Version: {settings.API_VERSION}")
    logger.info(f"Debug Mode: {settings.DEBUG}")

    # Покажем факт наличия ключа (сам ключ НЕ логируем)
    fal_key = os.getenv("FAL_KEY")
    fal_id = os.getenv("FAL_KEY_ID")
    fal_secret = os.getenv("FAL_KEY_SECRET")
    logger.info(f"FAL_KEY loaded: {'YES' if fal_key else 'NO'}; "
                f"FAL_KEY_ID/SECRET loaded: {'YES' if (fal_id and fal_secret) else 'NO'}")

    Path(settings.TEMP_DIR).mkdir(parents=True, exist_ok=True)
    yield
    logger.info("Shutting down Outfit Assistant Backend Server...")


app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    debug=settings.DEBUG,
    lifespan=lifespan,
)

app.include_router(search_router)
app.include_router(suggest_router)
app.include_router(internet_images_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

app.include_router(nano_banana.router, prefix=settings.API_PREFIX, tags=["Nano Banana"])
app.include_router(remove_bg.router, prefix=settings.API_PREFIX)
app.include_router(ai_consultant.router, prefix=settings.API_PREFIX, tags=["AI Consultant"])
app.include_router(styles.router, prefix=settings.API_PREFIX, tags=["Styles"])
app.include_router(visual_search.router, prefix=settings.API_PREFIX, tags=["Visual Search"])
app.include_router(video_generation.router, prefix=settings.API_PREFIX, tags=["Video Generation"])

@app.get("/")
async def root():
    return {
        "message": "Outfit Assistant Backend API",
        "version": settings.API_VERSION,
        "status": "running",
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
    )
