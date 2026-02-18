from fastapi import APIRouter, File, UploadFile, HTTPException, Form
from typing import Optional, List
from pydantic import BaseModel
import base64
from app.services.gemini_consultant_service import gemini_service

router = APIRouter(tags=["Visual Search"])

class AnalysisResponse(BaseModel):
    items: List[dict]

@router.post("/visual-search/analyze", response_model=AnalysisResponse)
async def analyze_image(
    file: Optional[UploadFile] = File(None),
    image_b64: Optional[str] = Form(None)
):
    """
    Analyze an image (outfit) and return detected clothing items.
    Accepts meaningful file upload OR base64 string.
    """
    try:
        final_b64 = None
        
        if file:
            content = await file.read()
            final_b64 = base64.b64encode(content).decode('utf-8')
        elif image_b64:
            final_b64 = image_b64
            # Strip header if present
            if "," in final_b64:
                final_b64 = final_b64.split(",")[1]
        
        if not final_b64:
             raise HTTPException(status_code=400, detail="Image required (file or image_b64)")

        items = await gemini_service.analyze_outfit_image(final_b64)
        
        return {"items": items}
        
    except HTTPException:
        raise # Re-raise HTTP exceptions as is
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"Visual Search Error: {error_details}")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}\n\nTraceback: {error_details}")

@router.post("/visual-search/auto-tag")
async def auto_tag_clothing(
    file: Optional[UploadFile] = File(None),
    image_b64: Optional[str] = Form(None),
    language: Optional[str] = Form('ru') # Default to RU if not provided
):
    """
    Auto-tag a single clothing item.
    Returns tags, category, color, etc.
    """
    try:
        final_b64 = None
        
        if file:
            content = await file.read()
            final_b64 = base64.b64encode(content).decode('utf-8')
        elif image_b64:
            final_b64 = image_b64
            if "," in final_b64:
                final_b64 = final_b64.split(",")[1]
        
        if not final_b64:
             raise HTTPException(status_code=400, detail="Image required")

        tags_data = await gemini_service.auto_tag_item(final_b64, language=language)
        
        return tags_data
        
    except Exception as e:
        import traceback
        print(f"Auto-Tag Error: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
