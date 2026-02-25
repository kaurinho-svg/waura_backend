import httpx
import base64
import json
import logging
from typing import List, Dict, Any, Tuple
from config import GEMINI_API_KEY

logger = logging.getLogger(__name__)

async def suggest_outfit(photo_bytes: bytes, store_products: List[Dict[str, Any]]) -> Tuple[str, List[str]]:
    """
    Sends the user's photo and the store's products to Gemini.
    Returns: (text_advice, list_of_recommended_product_ids)
    """
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY не настроен. Обратитесь к администратору.")

    # Prepare catalog context
    catalog_text = "Доступные товары в магазине:\n"
    for p in store_products:
        catalog_text += f"- ID: {p['id']}, Название: {p['name']}, Категория: {p.get('category', '—')}, Цена: {p['price']} ₸\n"

    system_prompt = f"""Ты — профессиональный, дружелюбный и современный AI-стилист.
Твоя задача — посмотреть на фотографию пользователя, определить его цветотип, особенности фигуры и предпочитаемый стиль, а затем подобрать 1-2 идеальных товара из каталога магазина.

{catalog_text}

ИНСТРУКЦИЯ:
1. Поприветствуй пользователя и сделай ему искренний, персонализированный комплимент на основе его внешности/стиля на фото.
2. Выбери из каталога выше 1-2 товара, которые лучше всего ему подойдут.
3. Профессионально объясни, ПОЧЕМУ ты выбрал именно эти вещи (например, "этот синий цвет подчеркнет ваши глаза", или "этот крой визуально вытянет силуэт").
4. Пиши тепло, с использованием эмодзи (✨👗👔), структурируй текст абзацами.
5. ТЫ ДОЛЖЕН ВЕРНУТЬ ОТВЕТ СТРОГО В ВИДЕ JSON-ОБЪЕКТА. Не используй Markdown-форматирование ```json ... ```, верни просто сырой JSON.

Формат JSON:
{{
    "text": "Твой подробный и красивый ответ стилиста (со всеми абзацами и эмодзи)",
    "recommended_ids": ["id_товара_1", "id_товара_2"]
}}"""

    b64_image = base64.b64encode(photo_bytes).decode('utf-8')

    payload = {
        "contents": [{
            "parts": [
                {"text": system_prompt},
                {
                    "inline_data": {
                        "mime_type": "image/jpeg",
                        "data": b64_image
                    }
                }
            ]
        }],
        "generationConfig": {
            "temperature": 0.7,
            "responseMimeType": "application/json"
        }
    }

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(url, json=payload)
        
        if response.status_code != 200:
            logger.error(f"Gemini API Error: {response.text}")
            raise Exception("Ошибка при обращении к AI-стилисту.")
            
        data = response.json()
        
        try:
            content_text = data["candidates"][0]["content"]["parts"][0]["text"]
            result = json.loads(content_text)
            
            advice = result.get("text", "Вот что я подобрал для вас!")
            recommended_ids = result.get("recommended_ids", [])
            
            # Filter IDs to ensure they actually exist in the store products
            valid_ids = [str(pid) for pid in recommended_ids if any(str(p['id']) == str(pid) for p in store_products)]
            
            return advice, valid_ids
            
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            logger.error(f"Failed to parse Gemini response: {e}\nRaw text: {data}")
            raise Exception("Не удалось расшифровать ответ от AI-стилиста.")
