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
        Virtual Try-On using Nano Banana.
        is_premium=True uses Nano Banana PRO for higher quality results.
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        if not user_image_url or not clothing_image_url:
            raise HTTPException(status_code=400, detail="Both image urls are required")

        # Определяем категорию и переводим промпт на английский (модель лучше понимает его)
        # Если категория передана явно (из frontend), используем её
        # Иначе пытаемся определить по промпту
        target_category = category or "upper_body" 
        final_prompt = prompt or "cloth"
        p_lower = prompt.lower()
        
        # Словарь маппинга: Русское слово -> (Категория, Английское описание)
        # IDM-VTON лучше работает с английским описанием
        keywords_map = {
            # Full Body
            "dress": ("dresses", "dress"),
            "платье": ("dresses", "dress"),
            "suit": ("dresses", "mens suit full body"),
            "костюм": ("dresses", "mens suit full body"),
            "set": ("dresses", "full body outfit"),
            "комплект": ("dresses", "full body outfit"),
            "full": ("dresses", "full body outfit"),
            "clothes": ("dresses", "full body outfit"),
            "look": ("dresses", "full body outfit"),
            "образ": ("dresses", "full body outfit"),
            "стиль": ("dresses", "full body outfit"),
            
            # Layering hints
            "layer": ("upper_body", "layered outfit"),
            "под": ("upper_body", "layered outfit"),
            "футболка под": ("upper_body", "open shirt with t-shirt underneath"),
            
            # Lower Body
            "jeans": ("lower_body", "jeans"),
            "джинсы": ("lower_body", "jeans"),
            "pants": ("lower_body", "pants"),
            "брюки": ("lower_body", "pants"),
            "skirt": ("lower_body", "skirt"),
            "юбка": ("lower_body", "skirt"),
            "shorts": ("lower_body", "shorts"),
            "шорты": ("lower_body", "shorts"),
            
            # Upper Body
            "t-shirt": ("upper_body", "t-shirt"),
            "футболка": ("upper_body", "t-shirt"),
            "shirt": ("upper_body", "shirt"),
            "рубашка": ("upper_body", "shirt"),
            "hoodie": ("upper_body", "hoodie"),
            "худи": ("upper_body", "hoodie"),
            "jacket": ("upper_body", "jacket"),
            "куртка": ("upper_body", "jacket"),
        }

        # Проверяем наличие ключевых слов
        for k, (cat, eng_desc) in keywords_map.items():
            if k in p_lower:
                # Если категория НЕ задана явно, берем из ключевого слова
                if not category:
                    target_category = cat
                
                # Если промпт очень короткий (одно слово), заменяем его на хороший английский
                if len(prompt.split()) <= 2:
                    final_prompt = eng_desc
                else:
                    # Иначе просто добавляем английский контекст
                    final_prompt = f"{eng_desc}, {prompt}"
                break
        
        # Итоговая категория (если так и не определили, то upper_body)
        final_category_param = target_category
        
        # 🔥 УСИЛЕНИЕ: Если режим "Full Body", принудительно добавляем описание
        if final_category_param == "dresses":
             if "suit" not in final_prompt.lower() and "dress" not in final_prompt.lower():
                 final_prompt = f"full body outfit, {final_prompt}"

        print(f"DEBUG: VTON Prompt='{prompt}' -> Detect='{final_prompt}' Category='{final_category_param}' (Explicit='{category}')")

        # 🔥 PRE-PROCESS: CLEAN CLOTHING IMAGE (DISABLED by User Request)
        # User explicitly asked to remove BiRefNet and use the raw image.
        clean_clothing_url = clothing_image_url
        
        try:
            # Choose model based on premium status
            model_id = "fal-ai/nano-banana-pro" if is_premium else "fal-ai/nano-banana/edit"
            print(f"DEBUG: MagicMirror calling {model_id} (Premium={is_premium})...")

            # Determine specific instruction based on category
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
                f"Preserve all body proportions. Photorealistic clothing fit, natural draping. "
                f"Extra: {final_prompt}."
            )

            # Nano Banana payload
            nano_payload = {
                "image_urls": [user_image_url, clean_clothing_url],
                "prompt": prompt_instruction,
                "image_guidance_scale": 3.5,  # Increased: forces model to follow input images (prevents hallucinating a new person)
                "prompt_guidance_scale": 7.5
            }
            
            print(f"DEBUG: Nano Banana PRO Payload: prompt={prompt_instruction[:50]}...")
            
            try:
                result = fal_client.run(model_id, arguments=nano_payload)
                return result
            except Exception as e:
                if is_premium:
                    print(f"WARNING: Nano Banana PRO failed ({e}). Falling back to standard...")
                    # Retry with standard if PRO fails
                    nano_payload_fallback = nano_payload.copy()
                    result = fal_client.run("fal-ai/nano-banana/edit", arguments=nano_payload_fallback)
                    return result
                else:
                    raise

        except Exception as e:
            print(f"Seedream Engine Error: {e}")
            # Fallback advice if 4.5 doesn't exist
            if "not found" in str(e).lower() or "permission" in str(e).lower():
                 print("WARNING: Seedream 4.5 might be private or typo. Falling back to Nano Banana?")
            raise HTTPException(status_code=500, detail=f"Generation failed: {e}")

    async def video_tryon(self, user_image_url: str, clothing_image_url: str, prompt: str, category: str = None) -> Dict[str, Any]:
        """
        Video try-on: Seedream (static try-on) + Kling (animation).
        Returns animated video with try-on result.
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        if not user_image_url or not clothing_image_url:
            raise HTTPException(status_code=400, detail="Both image urls are required")

        # Determine category-specific instruction
        target_category = category or "upper_body"
        final_prompt = prompt or "cloth"
        
        category_instruction = ""
        if target_category == "upper_body":
            category_instruction = "Replace ONLY the upper body clothing (tops, shirts, jackets). Keep the lower body (pants/skirt) unchanged."
        elif target_category == "lower_body":
            category_instruction = "Replace ONLY the lower body clothing (pants, skirts, shorts). Keep the upper body unchanged."
        else:
            category_instruction = "Replace the entire outfit (full body)."

        print(f"DEBUG: Video VTON Category='{target_category}' Prompt='{final_prompt}'")

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
