from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.services.nano_banana_service import nano_banana_service

router = APIRouter()

DEFAULT_PROMPT = "realistic outfit try-on, high quality, natural lighting"


class NanoBananaEditRequest(BaseModel):
    user_image_url: str
    clothing_image_url: str
    prompt: Optional[str] = None
    category: Optional[str] = None # "upper_body", "lower_body", "dresses"
    is_premium: Optional[bool] = False # [NEW] Premium users get Nano Banana PRO


@router.post("/nano-banana/upload-temp")
async def upload_temp(file: UploadFile = File(...)):
    # грузим в fal CDN и возвращаем публичный url
    try:
        url = await nano_banana_service.upload_to_fal(file)
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"upload-temp failed: {e}")


@router.post("/nano-banana/edit")
async def edit(req: NanoBananaEditRequest):
    if not req.user_image_url or not req.clothing_image_url:
        raise HTTPException(
            status_code=400,
            detail="user_image_url and clothing_image_url are required",
        )

    final_prompt = (req.prompt or "").strip() or DEFAULT_PROMPT

    result = await nano_banana_service.edit(
        user_image_url=req.user_image_url,
        clothing_image_url=req.clothing_image_url,
        prompt=final_prompt,
        category=req.category,
        is_premium=req.is_premium or False
    )
    return result


@router.post("/nano-banana/video-tryon")
async def video_tryon(req: NanoBananaEditRequest):
    """
    Direct video try-on endpoint.
    Takes 2 images (person + clothing) and returns animated video with try-on result.
    """
    if not req.user_image_url or not req.clothing_image_url:
        raise HTTPException(
            status_code=400,
            detail="user_image_url and clothing_image_url are required",
        )

    final_prompt = (req.prompt or "").strip() or DEFAULT_PROMPT

    result = await nano_banana_service.video_tryon(
        user_image_url=req.user_image_url,
        clothing_image_url=req.clothing_image_url,
        prompt=final_prompt,
        category=req.category
    )
    return result

