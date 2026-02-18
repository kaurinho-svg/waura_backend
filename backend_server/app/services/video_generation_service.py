import os
from typing import Any, Dict, Optional

from fastapi import HTTPException
from dotenv import load_dotenv

import fal_client

load_dotenv()


class VideoGenerationService:
    def __init__(self) -> None:
        self.fal_key = os.getenv("FAL_KEY") or os.getenv("FAL_TOKEN") or ""

    async def generate_from_image(self, image_url: str, prompt: str = None, duration: str = "5") -> Dict[str, Any]:
        """
        Generate a video from a static image using Kling AI via Fal.ai.
        Endpoint: fal-ai/kling-video/v1/standard/image-to-video
        """
        if not self.fal_key:
            raise HTTPException(status_code=500, detail="FAL_KEY is not set in environment")

        if not image_url:
            raise HTTPException(status_code=400, detail="image_url is required")

        # Default prompt if none provided
        final_prompt = prompt or "Fashion model posing, natural movement, looking at camera, high quality, photorealistic, 4k, slow motion"

        try:
            print(f"DEBUG: Calling Kling Video (Standard)... Image={image_url[:50]}...")
            
            handler = fal_client.submit(
                "fal-ai/kling-video/v1/standard/image-to-video",
                arguments={
                    "image_url": image_url,
                    "prompt": final_prompt,
                    "duration": duration, # "5" or "10"
                    "aspect_ratio": "9:16" 
                },
            )
            
            # Request log
            request_id = handler.request_id
            print(f"DEBUG: Kling Request ID: {request_id}")

            # Wait for result
            result = handler.get()
            
            print(f"DEBUG: Kling Result: {result}")
            return result

        except Exception as e:
            print(f"Kling Video Error: {e}")
            raise HTTPException(status_code=500, detail=f"Video generation failed: {e}")

# Singleton instance
video_service = VideoGenerationService()
