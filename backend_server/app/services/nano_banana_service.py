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
            # Step 1: Use standard edit() method for static try-on (better proportion handling)
            print("DEBUG: Step 1 - Using Nano Banana PRO for video base (Premium)...")
            
            # Using Nano Banana PRO model explicitly for video generation base
            # to ensure higher quality input for Kling
            model_id_pro = "fal-ai/nano-banana-pro" 
            
            # Reconstruct payload for Pro model
            # Note: Pro model might have slightly different params, but generally compatible
            
            category_instruction = ""
            if target_category == "upper_body":
                category_instruction = "Replace ONLY the upper body clothing (tops, shirts, jackets). Keep the lower body (pants/skirt) unchanged."
            elif target_category == "lower_body":
                category_instruction = "Replace ONLY the lower body clothing (pants, skirts, shorts). Keep the upper body unchanged."
            else:
                category_instruction = "Replace the entire outfit (full body)."

            prompt_instruction = (
                f"VIRTUAL TRY-ON: Keep the EXACT same person from image 1 — same face, body shape, skin, hair, pose, and background. DO NOT replace the person. "
                f"TASK: Dress this exact person in the garment from image 2. {category_instruction} "
                f"Preserve all body proportions. Photorealistic clothing fit, natural draping, 4K quality. "
                f"Extra: {final_prompt}."
            )

            nano_payload = {
                "image_urls": [user_image_url, clothing_image_url],
                "prompt": prompt_instruction,
                "image_guidance_scale": 3.5,  # Increased: forces model to follow input images
                "prompt_guidance_scale": 7.5
            }
            
            print(f"DEBUG: Calling {model_id_pro}...")
            try:
                edit_result = fal_client.run(model_id_pro, arguments=nano_payload)
            except Exception as pro_error:
                print(f"WARNING: Pro model failed ({pro_error}), falling back to standard...")
                # Fallback to standard edit if Pro fails (e.g. invalid ID or access)
                edit_result = await self.edit(
                    user_image_url=user_image_url,
                    clothing_image_url=clothing_image_url,
                    prompt=final_prompt,
                    category=target_category
                )
            
            # Extract static image URL from edit result
            static_url = None
            if edit_result.get("image") and edit_result["image"].get("url"):
                static_url = edit_result["image"]["url"]
            elif edit_result.get("images") and len(edit_result["images"]) > 0:
                static_url = edit_result["images"][0].get("url")
            
            if not static_url:
                raise Exception("Edit method did not return image URL")
            
            print(f"DEBUG: Pro/Base result: {static_url[:50]}...")
            
            # Step 2: Animate with Kling
            print("DEBUG: Step 2 - Kling animation...")
            
            # Runway model animation prompt - showcase full outfit
            animation_prompt = (
                f"Professional fashion runway model showcasing outfit. "
                f"MOVEMENTS: "
                f"- Confident runway walk or elegant pose "
                f"- Slow 360-degree turn to show full outfit from all angles "
                f"- Natural model posture and gestures "
                f"- Fabric flowing naturally with movement "
                f"- Professional fashion show atmosphere "
                f"CRITICAL: Keep the person's face and identity EXACTLY as shown. "
                f"STYLE: High-end fashion editorial, studio lighting, cinematic, 8k quality, photorealistic. "
                f"NEGATIVE: face modification, distorted proportions, unnatural movement, low quality"
            )
            
            # Use Kling v2.5 Turbo Pro (no audio by default, better face preservation)
            kling_payload = {
                "image_url": static_url,
                "prompt": animation_prompt,
                "duration": "5",
                "aspect_ratio": "9:16",
            }
            
            # Correct v2.5-turbo path (with hyphen, not dot)
            kling_result = fal_client.run("fal-ai/kling-video/v2.5-turbo/pro/image-to-video", arguments=kling_payload)
            
            print(f"DEBUG: Kling result: {kling_result}")
            return kling_result

        except Exception as e:
            print(f"Video Try-On Error: {e}")
            raise HTTPException(status_code=500, detail=f"Video generation failed: {e}")


nano_banana_service = NanoBananaService()
