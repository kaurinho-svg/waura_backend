import os
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import HTTPException
from supabase import create_client, Client

PHOTO_COST = 2
VIDEO_COST = 10
FREE_CREDITS = 10
PREMIUM_CREDITS = 100


class CreditsService:
    def __init__(self):
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if url and key:
            self.supabase: Optional[Client] = create_client(url, key)
        else:
            self.supabase = None

    def _get_client(self) -> Client:
        if not self.supabase:
            raise HTTPException(status_code=500, detail="Supabase not configured")
        return self.supabase

    def get_credits(self, user_id: str) -> dict:
        """Returns current credit balance and resets monthly if needed."""
        db = self._get_client()
        row = db.from_("profiles").select("try_on_credits, credits_reset_at, is_premium").eq("id", user_id).single().execute()
        data = row.data
        if not data:
            raise HTTPException(status_code=404, detail="User not found")

        # Monthly reset check
        reset_at = data.get("credits_reset_at")
        if reset_at:
            reset_dt = datetime.fromisoformat(reset_at.replace("Z", "+00:00"))
            now = datetime.now(timezone.utc)
            if now - reset_dt > timedelta(days=30):
                new_credits = PREMIUM_CREDITS if data.get("is_premium") else FREE_CREDITS
                db.from_("profiles").update({
                    "try_on_credits": new_credits,
                    "credits_reset_at": now.isoformat()
                }).eq("id", user_id).execute()
                data["try_on_credits"] = new_credits

        return {
            "credits": data.get("try_on_credits", FREE_CREDITS),
            "is_premium": data.get("is_premium", False),
            "photo_cost": PHOTO_COST,
            "video_cost": VIDEO_COST,
        }

    def deduct_credits(self, user_id: str, amount: int) -> int:
        """
        Deducts credits. Returns new balance.
        Raises HTTP 402 if insufficient credits.
        """
        db = self._get_client()
        result = db.rpc("deduct_try_on_credits", {"user_id": user_id, "amount": amount}).execute()
        new_balance = result.data

        if new_balance == -1:
            raise HTTPException(
                status_code=402,
                detail={
                    "error": "insufficient_credits",
                    "message": "Недостаточно кредитов. Купите премиум или пополните баланс.",
                    "photo_cost": PHOTO_COST,
                    "video_cost": VIDEO_COST,
                }
            )
        return new_balance


credits_service = CreditsService()
