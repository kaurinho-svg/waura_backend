from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
import os
import logging

logger = logging.getLogger(__name__)

class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Allow health checks and docs without key
        if request.url.path in ["/", "/docs", "/openapi.json", "/redoc"]:
            return await call_next(request)
            
        # Check for API Key
        client_key = request.headers.get("X-App-Secret")
        server_key = os.getenv("AUTH_SECRET_KEY")
        
        # If server key is not set, we might be in dev mode or unconfigured. 
        # But for security, if it IS set, we must enforce it.
        if server_key:
            if client_key != server_key:
                logger.warning(f"⛔ Unauthorized access attempt from {request.client.host}")
                # Return 401 directly
                # Note: Raising HTTPException here is tricky in middleware, creating response is safer
                from fastapi.responses import JSONResponse
                return JSONResponse(status_code=401, content={"detail": "Invalid or missing API Key"})
        
        return await call_next(request)
