import asyncio
from aiogram import Router, F, Bot
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.shop_kb import cancel_kb
from keyboards.buyer_kb import product_detail_kb
from services.supabase_service import get_products_by_store, get_product_by_id
from services.gemini_service import suggest_outfit

router = Router()

class StylistState(StatesGroup):
    waiting_photo = State()

@router.message(Command("stylist"))
@router.message(F.text == "✨ AI-Стилист 💎")
@router.callback_query(F.data == "stylist:start")
async def stylist_start(event: Message | CallbackQuery, state: FSMContext, store: dict):
    # Differentiate between message and callback answer
    is_callback = isinstance(event, CallbackQuery)
    message = event.message if is_callback else event

    # Only available in Premium stores
    if not store.get("is_premium"):
        text = (
            "💎 <b>Эта функция доступна только в Premium-магазинах!</b>\n\n"
            "Здесь наш умный AI-Стилист мог бы подобрать вам идеальный образ по вашему фото "
            "из ассортимента магазина."
        )
        if is_callback:
            await event.answer("Доступно только в Premium", show_alert=True)
        else:
            await message.answer(text, parse_mode="HTML")
        return

    # Check if store has any products
    products = get_products_by_store(store["id"])
    if not products:
        text = "😔 В магазине пока нет товаров для подбора."
        if is_callback:
            await event.answer(text, show_alert=True)
        else:
            await message.answer(text)
        return

    await state.set_state(StylistState.waiting_photo)
    
    if is_callback:
        await event.answer()
        
    await message.answer(
        "✨ <b>Привет! Я ваш персональный AI-Стилист.</b>\n\n"
        "Отправьте мне ваше селфи или фото в полный рост (где хорошо видно лицо и фигуру), "
        "и я подберу вам идеальный образ из нашего ассортимента!",
        parse_mode="HTML",
        reply_markup=cancel_kb()
    )

@router.message(StylistState.waiting_photo, F.photo)
async def stylist_process_photo(message: Message, state: FSMContext, store: dict, bot: Bot):
    await state.clear()
    
    products = get_products_by_store(store["id"])
    if not products:
        await message.answer("😔 В магазине не осталось товаров.")
        return

    status_msg = await message.answer("⏳ <i>Анализирую ваш стиль, подбираю лучшие варианты... (это займет около 10-15 секунд)</i>", parse_mode="HTML")

    try:
        # Download photo
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        file_bytes = await bot.download_file(file.file_path)
        
        # Call Gemini
        advice_text, recommended_ids = await suggest_outfit(file_bytes.read(), products)
        
        # Delete "analyzing" message
        await status_msg.delete()
        
        # Send Advice
        await message.answer(advice_text)
        
        # Send Recommended Products
        if recommended_ids:
            await message.answer("👇 <b>Вот товары, которые я подобрал специально для вас:</b>", parse_mode="HTML")
            await asyncio.sleep(1) # Small delay for better UX
            
            for pid in recommended_ids:
                p = get_product_by_id(pid)
                if p:
                    text = f"🏷 <b>{p['name']}</b>\n💰 {p['price']} ₸\n\n{p.get('description', '')}"
                    if p.get("photo_url"):
                        await message.answer_photo(
                            photo=p["photo_url"],
                            caption=text,
                            parse_mode="HTML",
                            reply_markup=product_detail_kb(p["id"])
                        )
                    else:
                        await message.answer(
                            text=text,
                            parse_mode="HTML",
                            reply_markup=product_detail_kb(p["id"])
                        )
                await asyncio.sleep(0.5) # Anti-spam delay
        else:
             await message.answer("К сожалению, я не смог найти идеального совпадения в каталоге, но ваш образ на фото прекрасен! 🌸")

    except Exception as e:
        await status_msg.delete()
        await message.answer(f"😔 Произошла ошибка. Попробуйте другое фото или попробуйте позже.\n({e})")
