from aiogram import Router, F
from aiogram.types import CallbackQuery, Message

from keyboards.buyer_kb import (
    categories_kb, product_card_kb, load_more_kb, product_detail_kb
)
from services.supabase_service import (
    get_products_by_store_and_category,
    get_categories_for_store,
    get_product_by_id,
    get_sizes_by_product,
)
from services.buyer_service import get_buyer
from locales import t, get_lang

router = Router()

PAGE_SIZE = 5

# Per-user product list cache for pagination
_cache: dict = {}


def _get_lang(user_id: int, store: dict) -> str:
    buyer = get_buyer(store["id"], user_id)
    return get_lang(buyer)


async def _send_product_cards(message: Message, products: list, lang: str, offset: int = 0, store: dict = None):
    """Sends a page of product photo cards. Each card = photo + caption + buttons."""
    page = products[offset: offset + PAGE_SIZE]
    
    buyer = None
    profile_filled = False
    
    # We need the user id to check the profile. 
    # For callback queries, message is the bot's message. We should ideally pass user_id, 
    # but since message.chat.id is the user's chat, we can use that.
    user_id = message.chat.id
    if store:
        buyer = get_buyer(store["id"], user_id)
        profile_filled = bool(buyer and (buyer.get("height") or buyer.get("top_size") or buyer.get("bottom_size")))

    for p in page:
        sizes = get_sizes_by_product(p['id'])
        sizes_text = ", ".join(f"{s['size']} ({s['quantity']} шт)" for s in sizes) if sizes else "—"
        caption = (
            f"🏷 <b>{p['name']}</b>\n"
            f"💰 <b>{p['price']:,.0f} ₸</b>\n"
            f"📂 {p.get('category', '—')}\n"
            f"📏 Размеры: {sizes_text}"
        )
        
        if not profile_filled:
            caption += "\n\n<i>💡 Для более точного подбора размера — заполните Мой профиль</i>"
            
        if p.get("photo_url"):
            await message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_card_kb(p["id"], lang=lang, profile_filled=profile_filled),
            )
        else:
            await message.answer(
                caption,
                parse_mode="HTML",
                reply_markup=product_card_kb(p["id"], lang=lang, profile_filled=profile_filled),
            )

    # Navigation row at the end
    next_offset = offset + PAGE_SIZE
    if next_offset < len(products):
        await message.answer(
            f"📦 {offset + len(page)}/{len(products)}",
            reply_markup=load_more_kb(next_offset, lang=lang),
        )


@router.callback_query(F.data.in_({"catalog:start", "catalog:categories"}))
async def catalog_categories(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    cats = get_categories_for_store(store["id"])
    await callback.message.answer(
        t("catalog_title", lang, store=store["name"]),
        parse_mode="HTML",
        reply_markup=categories_kb(cats, lang=lang),
    )
    await callback.answer()


@router.callback_query(F.data == "catalog:all")
async def catalog_all(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    products = get_products_by_store_and_category(store["id"])
    if not products:
        await callback.message.answer(t("catalog_empty", lang))
        await callback.answer()
        return

    key = (callback.from_user.id, store["id"])
    _cache[key] = products

    await callback.message.answer(
        t("catalog_all_title", lang, store=store["name"], count=len(products)),
        parse_mode="HTML",
    )
    await _send_product_cards(callback.message, products, lang, offset=0, store=store)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:cat:"))
async def catalog_by_category(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    category = callback.data.split("catalog:cat:", 1)[1]
    products = get_products_by_store_and_category(store["id"], category=category)
    if not products:
        cats = get_categories_for_store(store["id"])
        await callback.message.answer(
            t("catalog_empty_cat", lang, category=category),
            reply_markup=categories_kb(cats, lang=lang),
        )
        await callback.answer()
        return

    key = (callback.from_user.id, store["id"])
    _cache[key] = products

    await callback.message.answer(
        f"🏷 <b>{category}</b> — {len(products)}:",
        parse_mode="HTML",
    )
    await _send_product_cards(callback.message, products, lang, offset=0, store=store)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:page:"))
async def catalog_page(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    offset = int(callback.data.split(":")[2])
    key = (callback.from_user.id, store["id"])
    products = _cache.get(key) or get_products_by_store_and_category(store["id"])
    _cache[key] = products
    await _send_product_cards(callback.message, products, lang, offset=offset, store=store)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:product:"))
async def product_detail(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    sizes = get_sizes_by_product(product_id)
    sizes_text = ", ".join(
        f"{s['size']} ({s['quantity']} шт)" for s in sizes
    ) if sizes else "—"

    buyer = get_buyer(store["id"], callback.from_user.id)
    profile_filled = bool(buyer and (buyer.get("height") or buyer.get("top_size") or buyer.get("bottom_size")))
    
    caption = (
        f"🏷 <b>{p['name']}</b>\n"
        f"💰 {p['price']:,.0f} ₸\n"
        f"📂 {p.get('category', '—')}\n"
        f"📏 Размеры: {sizes_text}\n\n"
        f"📝 {p.get('description', '')}"
    )
    
    if not profile_filled:
        caption += "\n\n<i>💡 Для более точного подбора размера — заполните Мой профиль</i>"
    try:
        if p.get("photo_url"):
            await callback.message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(product_id, lang=lang, profile_filled=profile_filled),
            )
        else:
            await callback.message.answer(
                caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(product_id, lang=lang, profile_filled=profile_filled),
            )
    except Exception:
        await callback.message.answer(
            caption,
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id, lang=lang, profile_filled=profile_filled),
        )
    await callback.answer()


@router.callback_query(F.data.startswith("ai:size:"))
async def ai_size_recommendation(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    product_id = callback.data.split(":")[2]
    
    buyer = get_buyer(store["id"], callback.from_user.id)
    p = get_product_by_id(product_id)
    sizes = get_sizes_by_product(product_id)
    
    if not p or not sizes:
        await callback.answer("❌ Товар или размеры не найдены", show_alert=True)
        return
        
    await callback.answer("⏳ AI анализирует данные...")
    
    # Gather data
    sizes_text = ", ".join(f"{s['size']}" for s in sizes)
    prompt = f"""
    Act as a professional fashion stylist and size recommender.
    The customer is considering buying a product:
    - Item Name: {p['name']}
    - Category: {p.get('category', 'Clothing')}
    - Description: {p.get('description', '')}
    
    The available sizes in stock are: {sizes_text}
    
    The customer's body measurements are:
    - Height: {buyer.get('height', 'Unknown')} cm
    - Weight: {buyer.get('weight', 'Unknown')} kg
    - Typical Top Size: {buyer.get('top_size', 'Unknown')}
    - Typical Bottom Size: {buyer.get('bottom_size', 'Unknown')}
    
    Based on this data, recommend ONE specific size from the available sizes. 
    Explain briefly (1-2 sentences) why this size is best for them based on their weight/height.
    Respond in Russian. Be extremely polite and concise.
    """
    
    try:
        from google import genai
        import os
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.7,
                max_output_tokens=150
            )
        )
        recommendation = response.text.strip()
        
        await callback.message.answer(
            f"🪄 <b>Рекомендация ИИ-Стилиста:</b>\n\n{recommendation}",
            parse_mode="HTML"
        )
    except Exception as e:
        import logging
        logging.error(f"AI Size error: {e}")
        await callback.message.answer("⚠️ Извините, ИИ сейчас недоступен. Выбирайте размер, ориентируясь на свои обычные предпочтения.")
