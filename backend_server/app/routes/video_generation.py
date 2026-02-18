from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.services.video_generation_service import video_service

router = APIRouter()

class VideoGenerationRequest(BaseModel):
    image_url: str
    prompt: Optional[str] = None
    duration: Optional[str] = "5"

@router.post("/video/generate")
async def generate_video(req: VideoGenerationRequest):
    """
    Generate a video from an image using Kling AI.
    """
    if not req.image_url:
        raise HTTPException(status_code=400, detail="image_url is required")

    result = await video_service.generate_from_image(
        image_url=req.image_url,
        prompt=req.prompt,
        duration=req.duration
    )
    return result
