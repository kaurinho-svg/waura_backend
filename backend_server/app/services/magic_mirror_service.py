import os
from typing import Any, Dict
from fastapi import HTTPException
from dotenv import load_dotenv
import fal_client

load_dotenv()

class MagicMirrorService:
    def __init__(self) -> None:
        self.fal_key = os.getenv("FAL_KEY") or os.getenv("FAL_TOKEN") or ""

    async def generate(self, user_image_url: str, prompt: str, clothing_image_url: str = None, aspect_ratio: str = "portrait_4_3") -> Dict[str, Any]:
        """
        Generates a new image using fal-ai/idm-vton (Virtual Try-on) with Auto-Prompting.
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set")
        
        if not clothing_image_url:
             raise HTTPException(status_code=400, detail="clothing_image_url is required for Try-On")

        final_prompt = prompt

        # 🔥 AUTO-PROMPT LOGIC (Gemini)
        if not final_prompt:
             try:
                 from app.services.gemini_consultant_service import gemini_consultant_service
                 print(f"DEBUG: Auto-captioning clothing from {clothing_image_url}...")
                 
                 # Ask Gemini to describe the item + category hint
                 caption = await gemini_consultant_service.describe_image(
                     image_url=clothing_image_url, 
                     prompt="Describe this clothing item. Is it a top (shirt/jacket), bottom (pants/skirt), or full body (dress/suit)? format: 'Category: [Top/Bottom/Full]. Description: [Detail]'"
                 )
                 # Simplify for VTON prompt
                 final_prompt = caption or "clothing item"
                 print(f"DEBUG: Gemini Auto-Caption: {final_prompt}")
                 
             except Exception as e:
                 print(f"WARNING: Gemini captioning failed: {e}")
                 final_prompt = "stylish clothing"

        # 🔥 AUTO-CATEGORY & PROMPT REFINEMENT
        # idm-vton requires: 'upper_body', 'lower_body', or 'dresses'
        category = "upper_body" # default
        lower_prompt = final_prompt.lower()
        
        if "dress" in lower_prompt or "gown" in lower_prompt or "suit" in lower_prompt or "full body" in lower_prompt or "coat" in lower_prompt:
            category = "dresses"
        elif "pants" in lower_prompt or "jeans" in lower_prompt or "skirt" in lower_prompt or "shorts" in lower_prompt or "trousers" in lower_prompt:
            category = "lower_body"
            
        print(f"DEBUG: MagicMirror detected category='{category}' from prompt='{final_prompt}'")

        # 🔥 PRE-PROCESS: CLEAN CLOTHING IMAGE
        # IDM-VTON works best if the clothing image is clean (no complex background).
        clean_clothing_url = clothing_image_url
        try:
            print(f"DEBUG: Removing background from clothing image: {clothing_image_url}")
            # Identify the main object (clothing)
            biref_result = fal_client.run("fal-ai/birefnet", arguments={"image_url": clothing_image_url})
            if biref_result and "image" in biref_result and "url" in biref_result["image"]:
                clean_clothing_url = biref_result["image"]["url"]
                print(f"DEBUG: Clean clothing URL: {clean_clothing_url}")
        except Exception as e:
            print(f"WARNING: Background removal failed, using original. Error: {e}")

        # IDM-VTON Payload
        # We append texture details to ensure it doesn't just copy the person.
        detailed_prompt = f"{final_prompt}, high quality, photorealistic, fitting on the person"
        
        payload = {
            "human_image_url": user_image_url,
            "garment_image_url": clean_clothing_url, 
            "description": detailed_prompt,
            "category": category,
            "denoise_steps": 50, # High quality
            "seed": 42
        }

        try:
             # Switching to the proven 'fal-ai/idm-vton'
             print(f"DEBUG: MagicMirror calling fal-ai/idm-vton...")
             result = fal_client.run("fal-ai/idm-vton", arguments=payload)
             return result

        except Exception as e:
            print(f"MagicMirror Error: {e}")
            raise HTTPException(status_code=500, detail=f"Generation failed: {e}")

magic_mirror_service = MagicMirrorService()
