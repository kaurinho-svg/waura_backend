from fastapi import APIRouter, UploadFile, File, HTTPException, Header
from pydantic import BaseModel
from typing import Optional

from app.services.nano_banana_service import nano_banana_service
from app.services.credits_service import credits_service, PHOTO_COST, VIDEO_COST

router = APIRouter()

DEFAULT_PROMPT = "realistic outfit try-on, high quality, natural lighting"


class NanaBananaEditRequest(BaseModel):
    user_image_url: str
    clothing_image_url: str
    prompt: Optional[str] = None
    style_prompt: Optional[str] = None  # Flutter sends this field
    category: Optional[str] = None
    is_premium: Optional[bool] = False
    user_id: Optional[str] = None  # Supabase user ID for credit tracking


@router.post("/nano-banana/upload-temp")
async def upload_temp(file: UploadFile = File(...)):
    try:
        url = await nano_banana_service.upload_to_fal(file)
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"upload-temp failed: {e}")


@router.get("/nano-banana/credits")
async def get_credits(user_id: str):
    """Get current credit balance for a user."""
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id is required")
    return credits_service.get_credits(user_id)


@router.post("/nano-banana/edit")
async def edit(req: NanaBananaEditRequest):
    if not req.user_image_url or not req.clothing_image_url:
        raise HTTPException(
            status_code=400,
            detail="user_image_url and clothing_image_url are required",
        )

    # Deduct 2 credits if user_id provided
    new_balance = None
    if req.user_id:
        new_balance = credits_service.deduct_credits(req.user_id, PHOTO_COST)

    result = await nano_banana_service.edit(
        user_image_url=req.user_image_url,
        clothing_image_url=req.clothing_image_url,
        prompt="",
        is_premium=req.is_premium or False
    )

    # Attach remaining credits to response
    if new_balance is not None:
        result["remaining_credits"] = new_balance

    return result


@router.post("/nano-banana/video-tryon")
async def video_tryon(req: NanaBananaEditRequest):
    """
    Direct video try-on endpoint.
    Takes 2 images (person + clothing) and returns animated video.
    Costs 10 credits.
    """
    if not req.user_image_url or not req.clothing_image_url:
        raise HTTPException(
            status_code=400,
            detail="user_image_url and clothing_image_url are required",
        )

    # Deduct 10 credits if user_id provided
    new_balance = None
    if req.user_id:
        new_balance = credits_service.deduct_credits(req.user_id, VIDEO_COST)

    result = await nano_banana_service.video_tryon(
        user_image_url=req.user_image_url,
        clothing_image_url=req.clothing_image_url,
        prompt=""
    )

    if new_balance is not None:
        result["remaining_credits"] = new_balance

    return result
