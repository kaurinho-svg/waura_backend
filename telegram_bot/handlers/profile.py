from aiogram import Router, F
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup
from aiogram.utils.keyboard import InlineKeyboardBuilder

from services.buyer_service import get_buyer, update_buyer_profile
from keyboards.buyer_kb import main_menu_btn
from locales import t, get_lang

router = Router()

class BuyerProfile(StatesGroup):
    height = State()
    weight = State()
    top_size = State()
    bottom_size = State()

def skip_kb(lang: str = "ru") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="⏭ Пропустить", callback_data="profile:skip")
    builder.button(text=t("btn_cancel", lang), callback_data="nav:main_menu")
    builder.adjust(1)
    return builder.as_markup()

def sizes_top_kb(lang: str = "ru") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for s in ["XS", "S", "M", "L", "XL", "XXL"]:
        builder.button(text=s, callback_data=f"profile:top:{s}")
    builder.button(text="⏭ Пропустить", callback_data="profile:skip")
    builder.button(text=t("btn_cancel", lang), callback_data="nav:main_menu")
    builder.adjust(3, 3, 1, 1)
    return builder.as_markup()

def finish_kb(lang: str = "ru") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    main_menu_btn(builder, lang)
    return builder.as_markup()


@router.callback_query(F.data == "profile:start")
async def profile_start(callback: CallbackQuery, state: FSMContext, store: dict):
    buyer_uid = callback.from_user.id
    buyer = get_buyer(store["id"], buyer_uid)
    lang = get_lang(buyer)
    
    # Show current profile if exists
    if buyer and (buyer.get("height") or buyer.get("weight") or buyer.get("top_size") or buyer.get("bottom_size")):
        h = buyer.get("height") or "—"
        w = buyer.get("weight") or "—"
        ts = buyer.get("top_size") or "—"
        bs = buyer.get("bottom_size") or "—"
        
        text = (
            "👤 <b>Ваш профиль (Параметры тела)</b>\n\n"
            f"📏 Рост: <b>{h} см</b>\n"
            f"⚖️ Вес: <b>{w} кг</b>\n"
            f"👕 Размер верха: <b>{ts}</b>\n"
            f"👖 Размер низа: <b>{bs}</b>\n\n"
            "<i>Эти данные помогают нашему ИИ подбирать для вас идеальный размер одежды.</i>\n\n"
            "Хотите обновить данные?"
        )
        
        builder = InlineKeyboardBuilder()
        builder.button(text="✏️ Изменить данные", callback_data="profile:edit")
        main_menu_btn(builder, lang)
        builder.adjust(1)
        
        await callback.message.edit_text(text, parse_mode="HTML", reply_markup=builder.as_markup())
    else:
        # Start immediately
        await profile_edit(callback, state, store)
    
    await callback.answer()


@router.callback_query(F.data == "profile:edit")
async def profile_edit(callback: CallbackQuery, state: FSMContext, store: dict):
    buyer = get_buyer(store["id"], callback.from_user.id)
    lang = get_lang(buyer)
    
    await state.set_state(BuyerProfile.height)
    await state.update_data(profile_data={})
    
    await callback.message.edit_text(
        "📐 <b>Шаг 1/4: Рост</b>\n\n"
        "Введите ваш рост в сантиметрах (например, 175).\n\n"
        "<i>Если не хотите указывать, нажмите «Пропустить»</i>",
        parse_mode="HTML",
        reply_markup=skip_kb(lang)
    )
    await callback.answer()

async def step_weight(message: Message, state: FSMContext, lang: str):
    await state.set_state(BuyerProfile.weight)
    await message.answer(
        "⚖️ <b>Шаг 2/4: Вес</b>\n\n"
        "Введите ваш примерный вес в килограммах (например, 65).\n\n"
        "<i>Если не хотите указывать, нажмите «Пропустить»</i>",
        parse_mode="HTML",
        reply_markup=skip_kb(lang)
    )

async def step_top_size(message: Message, state: FSMContext, lang: str):
    await state.set_state(BuyerProfile.top_size)
    await message.answer(
        "👕 <b>Шаг 3/4: Размер верха</b>\n\n"
        "Какой стандартный размер верха вы обычно носите? Выберите из списка или нажмите «Пропустить».",
        parse_mode="HTML",
        reply_markup=sizes_top_kb(lang)
    )

async def step_bottom_size(message: Message, state: FSMContext, lang: str):
    await state.set_state(BuyerProfile.bottom_size)
    await message.answer(
        "👖 <b>Шаг 4/4: Размер низа</b>\n\n"
        "Какой размер джинс или брюк вы обычно покупаете? (Например: 38, 40, или 28, M).\n"
        "Напишите текстом или нажмите «Пропустить».",
        parse_mode="HTML",
        reply_markup=skip_kb(lang)
    )

async def step_finish(message: Message, state: FSMContext, store: dict, lang: str, user_id: int):
    data = await state.get_data()
    profile_data = data.get("profile_data", {})
    
    update_data = {}
    if "height" in profile_data: update_data["height"] = profile_data["height"]
    if "weight" in profile_data: update_data["weight"] = profile_data["weight"]
    if "top_size" in profile_data: update_data["top_size"] = profile_data["top_size"]
    if "bottom_size" in profile_data: update_data["bottom_size"] = profile_data["bottom_size"]
    
    if update_data:
        update_buyer_profile(store["id"], user_id, update_data)
        
    await state.clear()
    await message.answer(
        "✅ <b>Профиль сохранён!</b>\n\n"
        "Теперь при просмотре товаров вы сможете пользоваться умной ИИ-подсказкой для подбора идеального размера.",
        parse_mode="HTML",
        reply_markup=finish_kb(lang)
    )


@router.message(BuyerProfile.height)
async def process_height(message: Message, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], message.from_user.id))
    try:
        val = int(message.text.strip())
        if val < 100 or val > 250:
            raise ValueError
        
        data = await state.get_data()
        p = data.get("profile_data", {})
        p["height"] = val
        await state.update_data(profile_data=p)
        await step_weight(message, state, lang)
    except ValueError:
        await message.answer("⚠️ Пожалуйста, введите корректный рост числом (например: 175) или нажмите «Пропустить».", reply_markup=skip_kb(lang))


@router.message(BuyerProfile.weight)
async def process_weight(message: Message, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], message.from_user.id))
    try:
        val = int(message.text.strip())
        if val < 30 or val > 200:
            raise ValueError
        
        data = await state.get_data()
        p = data.get("profile_data", {})
        p["weight"] = val
        await state.update_data(profile_data=p)
        await step_top_size(message, state, lang)
    except ValueError:
        await message.answer("⚠️ Пожалуйста, введите корректный вес числом (например: 65) или нажмите «Пропустить».", reply_markup=skip_kb(lang))

@router.callback_query(BuyerProfile.top_size, F.data.startswith("profile:top:"))
async def process_top_callback(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], callback.from_user.id))
    size = callback.data.split(":")[-1]
    
    data = await state.get_data()
    p = data.get("profile_data", {})
    p["top_size"] = size
    await state.update_data(profile_data=p)
    
    await callback.answer()
    
    # We need a message object to send the next step
    # Creating a dummy message behavior 
    # but the correct way is using message
    await callback.message.delete()
    await step_bottom_size(callback.message, state, lang)


@router.message(BuyerProfile.top_size)
async def process_top_message(message: Message, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], message.from_user.id))
    val = message.text.strip()[:10] # limit length
    
    data = await state.get_data()
    p = data.get("profile_data", {})
    p["top_size"] = val
    await state.update_data(profile_data=p)
    
    await step_bottom_size(message, state, lang)


@router.message(BuyerProfile.bottom_size)
async def process_bottom_message(message: Message, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], message.from_user.id))
    val = message.text.strip()[:10] # limit length
    
    data = await state.get_data()
    p = data.get("profile_data", {})
    p["bottom_size"] = val
    await state.update_data(profile_data=p)
    
    await step_finish(message, state, store, lang, message.from_user.id)


@router.callback_query(F.data == "profile:skip")
async def process_skip(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = get_lang(get_buyer(store["id"], callback.from_user.id))
    current_state = await state.get_state()
    await callback.answer()
    await callback.message.delete()
    
    if current_state == BuyerProfile.height.state:
        await step_weight(callback.message, state, lang)
    elif current_state == BuyerProfile.weight.state:
        await step_top_size(callback.message, state, lang)
    elif current_state == BuyerProfile.top_size.state:
        await step_bottom_size(callback.message, state, lang)
    elif current_state == BuyerProfile.bottom_size.state:
        await step_finish(callback.message, state, store, lang, callback.from_user.id)
