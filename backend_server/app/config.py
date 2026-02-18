from pydantic_settings import BaseSettings
from pydantic import Field
from typing import List
from pathlib import Path


class Settings(BaseSettings):
    API_TITLE: str = "Outfit Assistant Backend API"
    API_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    HOST: str = "0.0.0.0"  # Listen on all interfaces
    PORT: int = 8000
    DEBUG: bool = False

    LOG_LEVEL: str = "INFO"
    CORS_ORIGINS: List[str] = ["*"]

    # fal.ai
    FAL_KEY: str = Field(default="", alias="FAL_KEY")

    REMOVEBG_API_KEY: str | None = None

    # Local static/temp (for local debug)
    BASE_DIR: str = str(Path(__file__).resolve().parents[1])
    STATIC_DIR: str = str(Path(BASE_DIR) / "static")
    TEMP_DIR: str = str(Path(STATIC_DIR) / "temp")

    # Optional: if you expose backend publicly (ngrok/domain), set this to that URL
    # Example: https://xxxxx.ngrok-free.app
    PUBLIC_BASE_URL: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()