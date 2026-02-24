import httpx
from config import BACKEND_URL


async def do_tryon(user_image_url: str, clothing_image_url: str) -> str:
    """
    Calls the existing FastAPI endpoint /api/v1/nano-banana/edit
    and returns the result image URL.
    Raises ValueError if result has no image URL.
    """
    payload = {
        "user_image_url": user_image_url,
        "clothing_image_url": clothing_image_url,
        "style_prompt": "",
        "is_premium": False,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(f"{BACKEND_URL}/api/v1/nano-banana/edit", json=payload)
        resp.raise_for_status()
        data = resp.json()

    # Extract result URL (same logic as Flutter app)
    url = (
        (data.get("image") or {}).get("url")
        or (data.get("images") or [{}])[0].get("url")
        or data.get("url")
    )
    if not url:
        raise ValueError(f"No image URL in response: {data}")
    return url


async def upload_image_to_backend(image_bytes: bytes, content_type: str = "image/jpeg") -> str:
    """
    Uploads image bytes to the existing FastAPI upload-temp endpoint
    and returns the fal.ai CDN URL.
    """
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            f"{BACKEND_URL}/api/v1/nano-banana/upload-temp",
            files={"file": ("image.jpg", image_bytes, content_type)},
        )
        resp.raise_for_status()
        return resp.json()["url"]
