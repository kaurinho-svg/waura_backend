"""Gemini AI service for style consultation using REST API."""
import logging
import os
from typing import List, Dict, Any
import requests

logger = logging.getLogger(__name__)


class GeminiConsultantService:
    """Service for interacting with Gemini API for style consultation."""
    
    def __init__(self):
        """Initialize Gemini service."""
        self.api_key = None
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models"  # Changed to v1beta for Flash
        self._initialize()
    
    def _initialize(self):
        """Initialize Gemini API."""
        try:
            api_key = os.getenv("GEMINI_API_KEY")
            
            if not api_key or api_key == "your_api_key_here":
                logger.warning("⚠️ GEMINI_API_KEY not configured")
                return
            
            self.api_key = api_key
            logger.info("✅ Gemini AI initialized successfully (REST API)")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize Gemini: {e}")
            self.api_key = None
    
    def is_configured(self) -> bool:
        """Check if Gemini is properly configured."""
        return self.api_key is not None
    
    async def ask(
        self,
        question: str,
        wardrobe: List[Dict[str, Any]],
        marketplace: List[Dict[str, Any]],
        gender: str = "unknown",
        history: List[Dict[str, Any]] = [],
        language: str = "ru"
    ) -> str:
        """
        Ask Gemini for style advice using REST API with context history.
        """
        if not self.api_key:
            raise Exception("Gemini API not configured")
        
        # 1. Build System Prompt (Context + Persona)
        system_prompt = self._build_system_prompt(wardrobe, marketplace, gender, language)
        
        # 2. Construct Chat History (Contents)
        contents = []
        
        # System Message (as User) to prime the context
        contents.append({
            "role": "user",
            "parts": [{"text": system_prompt}]
        })
        # REMOVED: Model "Ready" message to prevent "Reset" feeling
        
        # Append Conversation History
        # Limit to last 10 messages
        recent_history = history[-10:] if history else []
        
        # Filter: If last message in history is identical to current question, skip it
        # (Frontend might send updated state including current pending message)
        if recent_history and recent_history[-1].get("text") == question:
             recent_history = recent_history[:-1]

        for msg in recent_history:
            role = "user" if msg.get("isUser", False) else "model"
            text = msg.get("text", "")
            if text:
                contents.append({
                    "role": role,
                    "parts": [{"text": text}]
                })
        
        # Append Current Question
        contents.append({
            "role": "user",
            "parts": [{"text": question}]
        })
        
        try:
            # Use gemini-2.5-flash model
            url = f"{self.base_url}/gemini-2.5-flash:generateContent"
            
            response = requests.post(
                url,
                params={"key": self.api_key},
                json={"contents": contents},
                timeout=30
            )
            
            if response.status_code != 200:
                logger.error(f"Gemini API error: {response.status_code} - {response.text}")
                raise Exception(f"Gemini API returned {response.status_code}")
            
            data = response.json()
            
            # Extract text
            if "candidates" in data and len(data["candidates"]) > 0:
                candidate = data["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    parts = candidate["content"]["parts"]
                    if len(parts) > 0 and "text" in parts[0]:
                        return parts[0]["text"]
            
            raise Exception("Invalid response format from Gemini API")
            
        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            raise
    
    async def ask_with_image(
        self,
        question: str,
        image_data: bytes,
        mime_type: str,
        wardrobe: List[Dict[str, Any]],
        marketplace: List[Dict[str, Any]],
        gender: str = "unknown",
        history: List[Dict[str, Any]] = [],
        language: str = "ru"
    ) -> str:
        """
        Ask Gemini for style advice with an image using REST API.
        """
        if not self.api_key:
            raise Exception("Gemini API not configured")
        
        # 1. Build System Prompt (Context + Persona)
        system_prompt = self._build_system_prompt(wardrobe, marketplace, gender, language)
        
        # 2. Construct Chat History (Contents)
        contents = []
        
        # System Message
        contents.append({
            "role": "user",
            "parts": [{"text": system_prompt}]
        })
        
        # Append Conversation History (Text Only for now to save tokens/complexity)
        recent_history = history[-5:] if history else []
        for msg in recent_history:
            role = "user" if msg.get("isUser", False) else "model"
            text = msg.get("text", "")
            if text:
                contents.append({
                    "role": role,
                    "parts": [{"text": text}]
                })
        
        # 3. Append Current Question WITH Image
        import base64
        b64_image = base64.b64encode(image_data).decode('utf-8')
        
        contents.append({
            "role": "user",
            "parts": [
                {"text": question},
                {
                    "inline_data": {
                        "mime_type": mime_type,
                        "data": b64_image
                    }
                }
            ]
        })
        
        try:
            # Use gemini-2.5-flash model (multimodal)
            url = f"{self.base_url}/gemini-2.5-flash:generateContent"
            
            response = requests.post(
                url,
                params={"key": self.api_key},
                json={"contents": contents},
                timeout=60 # Increased timeout for image processing
            )
            
            if response.status_code != 200:
                logger.error(f"Gemini API error: {response.status_code} - {response.text}")
                raise Exception(f"Gemini API returned {response.status_code}")
            
            data = response.json()
            
            # Extract text
            if "candidates" in data and len(data["candidates"]) > 0:
                candidate = data["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    parts = candidate["content"]["parts"]
                    if len(parts) > 0 and "text" in parts[0]:
                        return parts[0]["text"]
            
            raise Exception("Invalid response format from Gemini API")
            
        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            raise

    def _build_system_prompt(
        self,
        wardrobe: List[Dict[str, Any]],
        marketplace: List[Dict[str, Any]],
        gender: str,
        language: str = "ru"
    ) -> str:
        """Build the system context prompt."""
        
        prompt = ""
        
        # --- ENGLISH PROMPT ---
        if language == 'en':
            gender_context = ""
            if gender.lower() == 'male':
                gender_context = "You are consulting a man. Consider men's trends, fits, and styles."
            elif gender.lower() == 'female':
                gender_context = "You are consulting a woman. Consider women's trends, styling, and combinations."

            prompt = f"""You are a professional, friendly, and wise AI Stylist in the Outfit Assistant app. Your mission is to be the perfect personal style consultant.
{gender_context}

CONTEXT:
The user has asked for your advice. Your task is to provide a detailed, helpful, and inspiring response.
You must NOT sell products or recommend specific items from the app store.
Focus on your expertise: color combinations, fits for occasions, trends, and creating a cohesive look.
"""
            if wardrobe:
                prompt += "👗 USER'S WARDROBE (Consider these items if helpful):\n"
                for item in wardrobe[:15]:
                    prompt += f"- {item.get('name', 'Untitled')} ({item.get('category', 'Uncategorized')})\n"
                prompt += "\n"

            prompt += """
FORMATTING INSTRUCTIONS (Markdown):
1. Use **bold** for key points.
2. Use lists (bullet or numbered) to structure info.
3. Break text into logical blocks with headers (level 2 or 3).
4. Use emojis 🌸✨👗👔 to create a warm atmosphere.

RESPONSE STRUCTURE:
1. **Empathic Intro**: Show you understood the request and mood.
2. **Detailed Breakdown**:
   - Style question: explain rules, suggest options.
   - Specific item: tell what to wear it with, accessories.
   - Give concrete examples ("try with a trench coat", "add a watch").
3. **Expert Tips**: Small tricks or trend nuances.
4. **Conclusion**: Warm and inspiring closing.

IMPORTANT:
- DO NOT say "in our store".
- User will search for items if they want. Your goal is to inspire and teach.

VISUAL EXAMPLES (MANDATORY):
If the user asks to "show", "photo", "look", "example", "ideas" or describes a specific style:
You MUST add an image search tag at the VERY END of your response.
Format: [SEARCH: exact search query in English]

Examples:
- Q: "Show wedding ideas" -> A: ...text... [SEARCH: mens summer wedding guest suit expert styling]
- Q: "Grunge style" -> A: ...text... [SEARCH: grunge style outfits aesthetic men women 90s]
- Q: "Green dress" -> A: ...text... [SEARCH: green dress outfit fashion street style]

RULES:
1. Tag must be LAST in the message.
2. Query inside tag MUST be in ENGLISH.
3. Don't say "Here are images", just insert the tag.
4. ALWAYS add [SEARCH: ...] if the question implies visual examples.
"""

        # --- KAZAKH PROMPT ---
        elif language == 'kk':
            gender_context = ""
            if gender.lower() == 'male':
                gender_context = "Сіз ер адамға кеңес беріп тұрсыз. Ерлер сәні мен трендтерін ескеріңіз."
            elif gender.lower() == 'female':
                gender_context = "Сіз әйел адамға кеңес беріп тұрсыз. Әйелдер сәні мен үйлесімдерін ескеріңіз."

            prompt = f"""Сіз - Outfit Assistant қосымшасындағы кәсіби, достық пейілді және данышпан AI-стилистсіз. Сіздің миссияңыз - мінсіз жеке стиль кеңесшісі болу.
{gender_context}

КОНТЕКСТ:
Пайдаланушы сізден кеңес сұрады. Сіздің міндетіңіз - барынша толық, пайдалы және шабыттандыратын жауап беру.
Сіз тауарларды сатпауыңыз керек немесе дүкеннен нақты заттарды ұсынбауыңыз керек.
Өз сараптамаңызға назар аударыңыз: түстер үйлесімі, жағдайға сай киім таңдау, трендтер және тұтас образ жасау.
"""
            if wardrobe:
                prompt += "👗 ПАЙДАЛАНУШЫ ГАРДЕРОБЫ (Кеңес беруде осы заттарды ескеріңіз):\n"
                for item in wardrobe[:15]:
                    prompt += f"- {item.get('name', 'Атаусыз')} ({item.get('category', 'Санатсыз')})\n"
                prompt += "\n"

            prompt += """
РӘСІМДЕУ НҰСҚАУЛАРЫ (Markdown):
1. Негізгі ойларды ерекшелеу үшін **жуан қаріпті** қолданыңыз.
2. Ақпаратты құрылымдау үшін тізімдерді қолданыңыз.
3. Мәтінді тақырыпшалармен (2 немесе 3 деңгей) бөліңіз.
4. Жылы атмосфера үшін эмодзилерді 🌸✨👗👔 қолданыңыз.

ЖАУАП ҚҰРЫЛЫМЫ:
1. **Кіріспе**: Сұранысты түсінгеніңізді көрсетіңіз.
2. **Толық талдау**:
   - Стиль туралы болса: ережелерді түсіндіріп, нұсқалар ұсыныңыз.
   - Нақты зат туралы болса: немен кию керектігін, аксессуарларды айтыңыз.
   - Нақты мысалдар келтіріңіз.
3. **Эксперт кеңестері**: Кішкентай қулықтар немесе трендтер.
4. **Қорытынды**: Шабыттандыратын сөздер.

МАҢЫЗДЫ:
- "Біздің дүкенде бар" деп айтпаңыз.
- Пайдаланушы қаласа, тауарларды өзі іздеп табады. Сіздің мақсатыңыз - шабыттандыру және үйрету.

ВИЗУАЛДЫ МЫСАЛДАР (МІНДЕТТІ):
Егер пайдаланушы "көрсет", "фото", "образ", "мысал", "идея" деп сұраса немесе нақты стильді сипаттаса:
Жауаптың ЕҢ СОҢЫНДА сурет іздеу тегін қосуыңыз КЕРЕК.
Формат: [SEARCH: ағылшын тіліндегі нақты сұраныс]

Мысалдар:
- Сұрақ: "Тойға идеялар" -> Жауап: ...мәтін... [SEARCH: mens summer wedding guest suit expert styling]
- Сұрақ: "Гранж стилі" -> Жауап: ...мәтін... [SEARCH: grunge style outfits aesthetic men women 90s]

ЕРЕЖЕЛЕР:
1. Тег хабарламаның СОҢЫНДА болуы керек.
2. Тег ішіндегі сұраныс АҒЫЛШЫН ТІЛІНДЕ болуы керек.
3. "Міне суреттер" деп жазбаңыз, тек тегті қойыңыз.
4. ӘРҚАШАН [SEARCH: ...] қосыңыз, егер сұрақ визуалды мысалдарды қажет етсе.
"""

        # --- RUSSIAN PROMPT (Default) ---
        else:
            gender_context = ""
            if gender.lower() == 'male':
                gender_context = "Ты консультируешь мужчину. Учитывай мужские тренды, особенности мужского стиля и кроя."
            elif gender.lower() == 'female':
                gender_context = "Ты консультируешь женщину. Учитывай женские тренды, особенности женского стиля и сочетаний."
            
            prompt = f"""Ты - профессиональный, дружелюбный и мудрый AI-стилист в приложении Outfit Assistant. Твоя миссия - быть идеальным личным консультантом по стилю.
{gender_context}

КОНТЕКСТ:
Пользователь обратился к тебе за советом. Твоя задача - дать максимально развернутый, полезный и вдохновляющий ответ.
Ты НЕ должен продавать товары или рекомендовать конкретные вещи из магазина приложения.
Ты должен сосредоточиться на своей экспертизе: сочетании цветов, подборе фасонов под ситуацию, трендах и создании целостного образа.
"""
            if wardrobe:
                prompt += "👗 ГАРДЕРОБ ПОЛЬЗОВАТЕЛЯ (Учитывай эти вещи, если они помогут в совете):\n"
                for item in wardrobe[:15]:
                    prompt += f"- {item.get('name', 'Без названия')} ({item.get('category', 'Без категории')})\n"
                prompt += "\n"
        
            prompt += """
ИНСТРУКЦИИ ПО ОФОРМЛЕНИЮ ОТВЕТА (Markdown):
1. Используй **жирный шрифт** для выделения главных мыслей.
2. Используй списки (маркированные и нумерованные) для структурирования информации.
3. Разделяй текст на логические блоки с заголовками уровня 2 или 3.
4. Обязательно используй эмодзи 🌸✨👗👔 (подбирай подходящие по полу) для создания теплой атмосферы.

СТРУКТУРА ТВОЕГО ОТВЕТА:
1. **Эмпатичное вступление**: Покажи, что ты понял запрос и настроение пользователя.
2. **Детальный разбор**:
   - Если вопрос про стиль: объясни правила, предложи варианты.
   - Если вопрос про конкретную вещь: расскажи, с чем её носить, какие аксессуары добавить.
   - Давай конкретные примеры ("попробуй сочетать с тренчем", "добавь часы").
3. **Советы эксперта**: Маленькие хитрости или трендовые нюансы.
4. **Заключение**: Теплое и вдохновляющее напутствие.

ВАЖНО:
- НЕ говори фразы в духе "в нашем магазине есть".
- Пользователь сам найдет товары в поиске, если захочет. Твоя цель - вдохновить и научить.

ВИЗУАЛЬНЫЕ ПРИМЕРЫ (ОБЯЗАТЕЛЬНО):
Если пользователь спрашивает "покажи", "фото", "образ", "примеры", "идеи" или описывает конкретный стиль:
Ты ОБЯЗАН добавить в конце ответа (после всех слов) тег поиска изображений.
Формат: [SEARCH: точный запрос на английском языке]

Примеры:
- Вопрос: "Покажи идеи для свадьбы" -> Ответ: ...текст... [SEARCH: mens summer wedding guest suit expert styling]
- Вопрос: "Стиль гранж" -> Ответ: ...текст... [SEARCH: grunge style outfits aesthetic men women 90s]
- Вопрос: "Зеленое платье" -> Ответ: ...текст... [SEARCH: green dress outfit fashion street style]

ВАЖНО:
1. Тег должен быть ПОСЛЕДНИМ в сообщении.
2. Запрос внутри тега должен быть НА АНГЛИЙСКОМ.
3. Не пиши "Вот изображения:", просто вставь тег.
4. ВСЕГДА добавляй тег [SEARCH: ...] если вопрос про конкретный стиль, вещь или образ.
"""
        
        return prompt

    async def describe_image(self, image_url: str, prompt_text: str = "Describe this image") -> str:
        """
        Analyze an image using Gemini Vision (gemini-1.5-flash).
        Useful for generating prompts for other models based on an image.
        """
        if not self.api_key:
             return "clothing"

        try:
            # 1. Download image (non-blocking)
            import base64
            import asyncio
            
            def download_and_encode():
                resp = requests.get(image_url)
                if resp.status_code != 200:
                    return None, None
                b64 = base64.b64encode(resp.content).decode('utf-8')
                return b64, "image/jpeg"

            b64_data, mime_type = await asyncio.to_thread(download_and_encode)
            
            if not b64_data:
                 return "clothing item"

            # 2. Call Gemini (non-blocking)
            url = f"{self.base_url}/gemini-1.5-flash:generateContent"
            
            payload = {
                "contents": [{
                    "parts": [
                        {"text": prompt_text},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": b64_data
                            }
                        }
                    ]
                }]
            }

            def call_gemini():
                return requests.post(
                    url,
                    params={"key": self.api_key},
                    json=payload,
                    timeout=30
                )

            response = await asyncio.to_thread(call_gemini)
            
            if response.status_code != 200:
                logger.error(f"Gemini Vision error: {response.status_code} - {response.text}")
                return "clothing item"

            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                candidate = data["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                     return candidate["content"]["parts"][0]["text"]
            
            return "clothing item"

        except Exception as e:
            logger.error(f"Gemini Vision exception: {e}")
            return "clothing item"


    async def analyze_outfit_image(self, image_b64: str) -> List[Dict[str, Any]]:
        """
        Analyze an outfit image and detect clothing items using Gemini Vision.
        Returns a structured list of items.
        """
        if not self.api_key:
            return []

        try:
            url = f"{self.base_url}/gemini-2.5-flash:generateContent"
            
            prompt = """
            Analyze this outfit image. Identifiy the main clothing items (e.g. Jacket, Shirt, Pants, Shoes, Bag, Accessories).
            For each item, provide:
            1. Name (e.g. "White Linen Blazer")
            2. Category (e.g. "Outerwear")
            3. Color (e.g. "White")
            4. Brand (e.g. "Gucci", "Zara" or "Unknown" if not clearly visible)
            5. Style Description (e.g. "Casual, loose fit")
            
            Return ONLY a valid JSON array of objects.
            Format:
            [
              {"name": "...", "category": "...", "color": "...", "brand": "...", "description": "..."}
            ]
            Do not wrap in Markdown code blocks. Just the JSON.
            """

            payload = {
                "contents": [{
                    "parts": [
                        {"text": prompt},
                        {
                            "inline_data": {
                                "mime_type": "image/jpeg",
                                "data": image_b64
                            }
                        }
                    ]
                }]
            }

            def call_gemini():
                return requests.post(
                    url,
                    params={"key": self.api_key},
                    json=payload,
                    timeout=30
                )

            import asyncio
            # print(f"DEBUG: Gemini URL: {url}") # REMOVED DEBUG
            response = await asyncio.to_thread(call_gemini)
            
            if response.status_code != 200:
                logger.error(f"Gemini Vision error: {response.status_code} - {response.text}")
                return []

            data = response.json()
            # print(f"Gemini Raw Response: {data}") 
            if "candidates" in data and len(data["candidates"]) > 0:
                candidate = data["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    text = candidate["content"]["parts"][0]["text"]
                    print(f"Gemini Vision Text: {text[:100]}...") # Log first 100 chars
                    
                    # Clean up Markdown check
                    if text.startswith("```json"):
                        text = text.replace("```json", "").replace("```", "")
                    
                    try:
                        import json
                        items = json.loads(text)
                        return items
                    except:
                        logger.error(f"Failed to parse Gemini Vision JSON: {text}")
                        return []
            
            return []

        except Exception as e:
            logger.error(f"Gemini Vision exception: {e}")
            return []

    async def auto_tag_item(self, image_b64: str, language: str = 'ru') -> Dict[str, Any]:
        """
        Analyze a single clothing item image and generate tags/attributes.
        Returns a structured dictionary with values in the requested language.
        """
        if not self.api_key:
            return {}

        lang_instruction = "IN RUSSIAN"
        if language == 'en':
            lang_instruction = "IN ENGLISH"
        elif language == 'kk':
            lang_instruction = "IN KAZAKH (Cyrillic)"

        try:
            url = f"{self.base_url}/gemini-2.5-flash:generateContent"
            
            prompt = f"""
            Analyze this clothing item image. Your task is to extract attributes for a digital wardrobe.
            Provide the following fields in JSON format:
            1. "name": A short, descriptive title {lang_instruction} (e.g. "Синяя льняная рубашка").
            2. "category": The main category MUST BE ONE OF THESE ENGLISH KEYS: ["top", "bottom", "shoes", "outerwear", "accessory", "dress", "hat", "bag", "other"].
            3. "subCategory": Specific type {lang_instruction} (e.g. "футболка", "джинсы", "кроссовки", "пиджак").
            4. "color": Main color {lang_instruction} (e.g. "Темно-синий").
            5. "season": Best season(s) {lang_instruction} (e.g. ["Лето", "Весна"]).
            6. "style": Style keywords {lang_instruction} (e.g. ["Кэжуал", "Минимализм"]).
            7. "tags": A list of 5-7 descriptive tags {lang_instruction} (material, pattern, vibe).

            Return ONLY valid JSON.
            Example:
            {{
              "name": "...", 
              "category": "outerwear", 
              "subCategory": "...",
              "color": "...",
              "season": ["..."],
              "style": ["..."],
              "tags": ["..."]
            }}
            """

            payload = {
                "contents": [{
                    "parts": [
                        {"text": prompt},
                        {
                            "inline_data": {
                                "mime_type": "image/jpeg",
                                "data": image_b64
                            }
                        }
                    ]
                }]
            }

            def call_gemini():
                return requests.post(
                    url,
                    params={"key": self.api_key},
                    json=payload,
                    timeout=30
                )

            import asyncio
            response = await asyncio.to_thread(call_gemini)
            
            if response.status_code != 200:
                logger.error(f"Gemini Auto-Tag error: {response.status_code} - {response.text}")
                return {}

            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                candidate = data["candidates"][0]
                if "content" in candidate and "parts" in candidate["content"]:
                    text = candidate["content"]["parts"][0]["text"]
                    
                    # Clean up Markdown
                    if text.startswith("```json"):
                        text = text.replace("```json", "").replace("```", "")
                    elif text.startswith("```"):
                        text = text.replace("```", "")
                    
                    try:
                        import json
                        result = json.loads(text)
                        return result
                    except:
                        logger.error(f"Failed to parse Gemini Auto-Tag JSON: {text}")
                        return {}
            
            return {}

        except Exception as e:
            logger.error(f"Gemini Auto-Tag exception: {e}")
            return {}


# Initialize singleton
gemini_service = GeminiConsultantService()
