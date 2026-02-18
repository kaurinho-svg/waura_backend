from typing import Optional, List
from pydantic import BaseModel, HttpUrl


class NanoBananaImage(BaseModel):
    url: HttpUrl
    content_type: Optional[str] = None
    file_name: Optional[str] = None
    file_size: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None


class NanoBananaResult(BaseModel):
    images: List[NanoBananaImage]
    description: Optional[str] = None


class NanoBananaEditRequest(BaseModel):
    user_image_url: HttpUrl
    clothing_image_url: HttpUrl
    style_prompt: Optional[str] = None
    with_logs: bool = False


class NanoBananaEditResponse(BaseModel):
    success: bool
    message: str
    result: Optional[NanoBananaResult] = None