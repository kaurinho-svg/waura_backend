"""Response models for API endpoints."""
from typing import Any, Optional, Dict
from pydantic import BaseModel


class NanoBananaResponse(BaseModel):
    """Response model for Nano Banana edit operation."""
    success: bool
    result: Optional[Dict[str, Any]] = None
    message: str


class ErrorResponse(BaseModel):
    """Error response model."""
    detail: str
    error_code: Optional[str] = None




