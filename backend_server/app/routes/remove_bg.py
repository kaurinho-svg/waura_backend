from fastapi import APIRouter, UploadFile, File, HTTPException
import httpx
from app.config import settings

router = APIRouter(prefix="/remove-bg", tags=["RemoveBG"])


@router.post("")
async def remove_bg(file: UploadFile = File(...)):
    """
    Принимает файл (jpg/png), возвращает PNG bytes с прозрачным фоном.
    Использует fal-ai/birefnet (через fal_client), так как remove.bg требует отдельный ключ.
    """
    # Используем FAL_KEY из переменных окружения (он уже есть)
    import fal_client
    import os
    import requests

    if not os.getenv("FAL_KEY"):
         # Если ключа нет, попробуем вернуть файл как есть (fallback), 
         # но лучше кинуть ошибку, так как VTON без этого будет плохим.
         raise HTTPException(status_code=500, detail="FAL_KEY not set")

    try:
        # 1. Загружаем файл во временное хранилище fal
        data = await file.read()
        url = fal_client.upload(data, content_type=file.content_type or "image/jpeg")

        # 2. Обрабатываем через BiRefNet (SOTA background removal)
        result = fal_client.run("fal-ai/birefnet", arguments={"image_url": url})
        
        # Result format: {'image': {'url': '...', ...}}
        out_url = result.get("image", {}).get("url")
        if not out_url:
             raise Exception(f"No result url from BiRefNet: {result}")

        # 3. Скачиваем результат и отдаем байты
        # (Frontend ждет bytes, не URL)
        async with httpx.AsyncClient() as client:
            resp = await client.get(out_url)
            return resp.content

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"fal-ai/birefnet error: {e}")