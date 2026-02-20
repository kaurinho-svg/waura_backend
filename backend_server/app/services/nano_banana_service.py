import os
import random
from typing import Any, Dict

from fastapi import HTTPException, UploadFile
from dotenv import load_dotenv

import fal_client

load_dotenv()


class NanoBananaService:
    def __init__(self) -> None:
        # fal_client обычно берёт ключ из переменной окружения FAL_KEY
        # но мы явно проверим, чтобы не было “тихо 401”
        self.fal_key = os.getenv("FAL_KEY") or os.getenv("FAL_TOKEN") or ""

        if not self.fal_key:
            # не валим сервер при импорте, но дадим понятную ошибку при первом вызове
            pass

    async def upload_to_fal(self, file: UploadFile) -> str:
        """
        Принимает UploadFile (FastAPI), загружает в fal storage/CDN,
        возвращает публичный URL.
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        try:
            data = await file.read()  # bytes
            if not data:
                raise HTTPException(status_code=400, detail="Empty file")

            # ВАЖНО: для разных версий fal_client сигнатура может отличаться,
            # но самый совместимый вариант — передать bytes и content_type.
            
            # Reverting async wrapper - keeping it simple to rule out threading issues
            url = fal_client.upload(
                data,
                content_type=file.content_type or "application/octet-stream"
            )
            return url

        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"upload_to_fal failed: {e}")

    async def edit(self, user_image_url: str, clothing_image_url: str, prompt: str, category: str = None, is_premium: bool = False) -> Dict[str, Any]:
        """
        Virtual Try-On using Nano Banana PRO.
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        if not user_image_url or not clothing_image_url:
            raise HTTPException(status_code=400, detail="Both image urls are required")

        print(f"DEBUG: VTON starting (is_premium={is_premium})")

        try:
            # Always use Nano Banana PRO for best quality
            model_id = "fal-ai/nano-banana-pro"
            print(f"DEBUG: MagicMirror calling {model_id}...")

            prompt_instruction = (
                "Image 1: person.\n"
                "Image 2: clothing.\n\n"
                "Replace the current clothes on the person in Image 1 with the clothes from Image 2. "
                "Keep the person's face, body shape, pose, background and lighting unchanged. "
                "Preserve fabric details, logos and colors from Image 2. "
                "Make the result realistic and natural."
            )

            nano_payload = {
                "image_urls": [user_image_url, clothing_image_url],
                "prompt": prompt_instruction,
                "image_guidance_scale": 2.0,
                "prompt_guidance_scale": 7.0
            }

            print(f"DEBUG: Payload ready, calling model...")

            try:
                result = fal_client.run(model_id, arguments=nano_payload)
                return result
            except Exception as e:
                print(f"WARNING: Nano Banana PRO failed ({e}). Falling back to standard...")
                nano_payload["image_guidance_scale"] = 2.0
                result = fal_client.run("fal-ai/nano-banana/edit", arguments=nano_payload)
                return result

        except Exception as e:
            print(f"Try-On Error: {e}")
            raise HTTPException(status_code=500, detail=f"Generation failed: {e}")

    async def video_tryon(self, user_image_url: str, clothing_image_url: str, prompt: str, category: str = None) -> Dict[str, Any]:
        """
        Video try-on: Nano Banana PRO (static) + Kling (animation).
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        if not user_image_url or not clothing_image_url:
            raise HTTPException(status_code=400, detail="Both image urls are required")

        print(f"DEBUG: Video VTON starting...")

        try:
            # Step 1: Static try-on with Nano Banana PRO
            print("DEBUG: Step 1 - Nano Banana PRO for video base...")

            prompt_instruction = (
                "Image 1: person.\n"
                "Image 2: clothing.\n\n"
                "Replace the current clothes on the person in Image 1 with the clothes from Image 2. "
                "Keep the person's face, body shape, pose, background and lighting unchanged. "
                "Preserve fabric details, logos and colors from Image 2. "
                "Make the result realistic and natural."
            )

            nano_payload = {
                "image_urls": [user_image_url, clothing_image_url],
                "prompt": prompt_instruction,
                "image_guidance_scale": 2.0,
                "prompt_guidance_scale": 7.0
            }

            try:
                edit_result = fal_client.run("fal-ai/nano-banana-pro", arguments=nano_payload)
            except Exception as pro_error:
                print(f"WARNING: Pro model failed ({pro_error}), falling back to standard...")
                edit_result = fal_client.run("fal-ai/nano-banana/edit", arguments=nano_payload)

            # Extract static image URL from edit result
            static_url = None
            if edit_result.get("image") and edit_result["image"].get("url"):
                static_url = edit_result["image"]["url"]
            elif edit_result.get("images") and len(edit_result["images"]) > 0:
                static_url = edit_result["images"][0].get("url")

            if not static_url:
                raise Exception("Edit method did not return image URL")

            print(f"DEBUG: Static result: {static_url[:50]}...")

            # Step 2: Animate with Kling
            print("DEBUG: Step 2 - Kling animation...")

            animation_prompt = (
                "Fashion model slowly rotating 360 degrees to showcase the outfit from all angles: "
                "front view, side view, back view, side view, front view. "
                "Smooth, natural rotation in place. Confident model posture. "
                "Fabric and clothing details clearly visible from every angle. "
                "CRITICAL: Keep the person's face and identity EXACTLY as shown. "
                "High-end fashion editorial, studio lighting, cinematic, photorealistic."
            )

            kling_payload = {
                "image_url": static_url,
                "prompt": animation_prompt,
                "duration": "5",
                "aspect_ratio": "9:16",
            }

            kling_result = fal_client.run("fal-ai/kling-video/v2.5-turbo/pro/image-to-video", arguments=kling_payload)

            print(f"DEBUG: Kling result: {kling_result}")
            return kling_result

        except Exception as e:
            print(f"Video Try-On Error: {e}")
            raise HTTPException(status_code=500, detail=f"Video generation failed: {e}")


nano_banana_service = NanoBananaService()
