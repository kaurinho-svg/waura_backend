"""AI Style Consultant API routes."""
import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.gemini_consultant_service import GeminiConsultantService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/consultant", tags=["AI Consultant"])

# Initialize Gemini service
gemini_service = GeminiConsultantService()


class WardrobeItem(BaseModel):
    """Wardrobe item model."""
    id: str
    name: str
    category: str
    color: str


class MarketplaceItem(BaseModel):
    """Marketplace item model."""
    id: str
    name: str
    category: str
    price: float


class ConsultantRequest(BaseModel):
    """AI Consultant request model."""
    question: str
    context: dict
    history: List[dict] = [] # Chat history
    language: str = "ru" # Language code (ru, en, kk)


class ProductRecommendation(BaseModel):
    """Product recommendation model."""
    id: str
    name: str
    reason: Optional[str] = None


class ConsultantResponse(BaseModel):
    """AI Consultant response model."""
    success: bool
    answer: Optional[str] = None
    source: str = "gemini"
    products: List[ProductRecommendation] = []
    images: List[dict] = [] # Visual suggestions
    error: Optional[str] = None
    fallback: Optional[str] = None


# Helper function for word extraction
import re

def extract_words(text: str) -> set:
    """Extract words from text using regex, ignoring punctuation."""
    if not text:
        return set()
    return set(re.findall(r'\b\w+\b', text.lower()))


@router.get("/status")
async def get_status():
    """Check AI consultant service status."""
    is_configured = gemini_service.is_configured()
    
    return {
        "status": "configured" if is_configured else "not_configured",
        "message": "AI Consultant is ready" if is_configured else "Gemini API key not configured",
        "service": "gemini-2.5-flash (REST API v1)"
    }


@router.post("/ask", response_model=ConsultantResponse)
async def ask_consultant(request: ConsultantRequest):
    """
    Ask the AI style consultant a question.
    
    The consultant will analyze the user's wardrobe and available marketplace items
    to provide personalized style advice.
    """
    try:
        logger.info(f"Received consultant question: {request.question[:50]}...")
        
        # Extract context
        wardrobe = request.context.get('wardrobe', [])
        marketplace = request.context.get('marketplace', [])
        gender = request.context.get('gender', 'unknown') # Default to unknown if not provided
        
        logger.info(f"Context: {len(wardrobe)} wardrobe items, {len(marketplace)} marketplace items, gender: {gender}")
        
        # NOTE: Marketplace context and product recommendation logic REMOVED as per user request.
        # We now focus solely on AI advice.
        
        # Get answer from Gemini
        answer = await gemini_service.ask(
            question=request.question,
            wardrobe=wardrobe,
            marketplace=marketplace,
            gender=gender,
            history=request.history,
            language=request.language
        )
        
        # Parse [SEARCH: ...] tag
        images = []
        clean_answer = answer
        
        try:
            import re
            search_match = re.search(r'\[SEARCH: (.*?)\]', answer)
            if search_match:
                query = search_match.group(1)
                # Remove tag from user-facing text
                clean_answer = answer.replace(search_match.group(0), "").strip()
                
                # Execute search
                from app.services.style_search_service import StyleSearchService
                search_service = StyleSearchService()
                # Increase limit to 30 to provide a "feed-like" experience
                images = search_service.search_by_query(query, limit=30)
                logger.info(f"Found {len(images)} images for query '{query}'")
        except Exception as e:
            logger.error(f"Image search failed: {e}")

        logger.info(f"AI Response: {clean_answer[:200]}...")
        
        return ConsultantResponse(
            success=True,
            answer=clean_answer,
            source="gemini",
            products=[], # Legacy field
            images=images # New field
        )
        
    except Exception as e:
        logger.error(f"Error in AI consultant: {str(e)}")
        
        # Return fallback response instead of error
        return ConsultantResponse(
            success=False,
            error=str(e),
            fallback=(
                "Не могу обработать этот вопрос прямо сейчас. 😔\n\n"
                "Попробуйте переформулировать или спросите что-то другое."
            )
        )


import json
from fastapi import UploadFile, File, Form

@router.post("/ask_with_image", response_model=ConsultantResponse)
async def ask_with_image_endpoint(
    question: str = Form(...),
    context: str = Form(...), # JSON string
    history: str = Form(default="[]"), # JSON string
    language: str = Form(default="ru"),
    file: UploadFile = File(...)
):
    """
    Ask the AI style consultant a question WITH an image.
    Uses multipart/form-data.
    """
    try:
        logger.info(f"Received consultant question with image: {question[:50]}...")
        
        # Parse JSON fields
        try:
            context_dict = json.loads(context)
            history_list = json.loads(history)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=400, detail=f"Invalid JSON in form data: {e}")
        
        # Extract context
        wardrobe = context_dict.get('wardrobe', [])
        marketplace = context_dict.get('marketplace', [])
        gender = context_dict.get('gender', 'unknown')
        
        logger.info(f"Context: {len(wardrobe)} wardrobe items, gender: {gender}, image: {file.filename}")
        
        # Read file
        contents = await file.read()
        mime_type = file.content_type or "image/jpeg"
        
        # Get answer from Gemini
        answer = await gemini_service.ask_with_image(
            question=question,
            image_data=contents,
            mime_type=mime_type,
            wardrobe=wardrobe,
            marketplace=marketplace,
            gender=gender,
            history=history_list,
            language=language
        )
        
        # Parse [SEARCH: ...] tag (Same logic as text-only)
        images = []
        clean_answer = answer
        
        try:
            import re
            search_match = re.search(r'\[SEARCH: (.*?)\]', answer)
            if search_match:
                query = search_match.group(1)
                clean_answer = answer.replace(search_match.group(0), "").strip()
                
                from app.services.style_search_service import StyleSearchService
                search_service = StyleSearchService()
                images = search_service.search_by_query(query, limit=30)
        except Exception as e:
            logger.error(f"Image search failed: {e}")

        return ConsultantResponse(
            success=True,
            answer=clean_answer,
            source="gemini",
            products=[],
            images=images
        )
        
    except Exception as e:
        logger.error(f"Error in AI consultant (image): {str(e)}")
        
        return ConsultantResponse(
            success=False,
            error=str(e),
            fallback=(
                "Не могу проанализировать это изображение. 😔\n\n"
                "Попробуйте другое фото или задайте вопрос текстом."
            )
        )


def _extract_recommended_products(ai_response: str, marketplace: list) -> List[ProductRecommendation]:
    """
    DEPRECATED: Product extraction disabled.
    Returns empty list.
    """
    return []
