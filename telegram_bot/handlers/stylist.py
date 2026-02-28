import asyncio
from aiogram import Router, F, Bot
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import buyer_cancel_kb, product_detail_kb
from keyboards.shop_kb import cancel_kb as admin_cancel_kb
from services.supabase_service import get_products_by_store, get_product_by_id
from services.gemini_service import suggest_outfit
from services.buyer_service import get_buyer
from locales import t, get_lang

router = Router()


class StylistState(StatesGroup):
    waiting_photo = State()


@router.message(Command("stylist"))
@router.message(F.text == "✨ AI-Стилист 💎")
@router.callback_query(F.data == "stylist:start")
async def stylist_start(event: Message | CallbackQuery, state: FSMContext, store: dict):
    is_callback = isinstance(event, CallbackQuery)
    message = event.message if is_callback else event

    buyer = get_buyer(store["id"], event.from_user.id)
    lang = get_lang(buyer)

    feature_val = store.get("feature_stylist")
    tier_allows = store.get("is_premium") or store.get("is_vip")
    if not (tier_allows if feature_val is None else bool(feature_val)):
        text = t("stylist_premium_only", lang)
        if is_callback:
            await event.answer(text, show_alert=True)
        else:
            await message.answer(text, parse_mode="HTML")
        return

    products = get_products_by_store(store["id"])
    if not products:
        text = t("stylist_no_products", lang)
        if is_callback:
            await event.answer(text, show_alert=True)
        else:
            await message.answer(text)
        return

    await state.set_state(StylistState.waiting_photo)

    if is_callback:
        await event.answer()

    await message.answer(
        t("stylist_greeting", lang),
        parse_mode="HTML",
        reply_markup=buyer_cancel_kb(lang)
    )


@router.message(StylistState.waiting_photo, F.photo)
async def stylist_process_photo(message: Message, state: FSMContext, store: dict, bot: Bot):
    await state.clear()

    buyer = get_buyer(store["id"], message.from_user.id)
    lang = get_lang(buyer)

    products = get_products_by_store(store["id"])
    if not products:
        await message.answer(t("stylist_no_products", lang))
        return

    status_msg = await message.answer(t("stylist_analyzing", lang), parse_mode="HTML")

    try:
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        file_bytes = await bot.download_file(file.file_path)

        advice_text, recommended_ids = await suggest_outfit(file_bytes.read(), products)

        await status_msg.delete()
        await message.answer(advice_text)

        if recommended_ids:
            await message.answer(t("stylist_results_header", lang), parse_mode="HTML")
            await asyncio.sleep(1)

            for pid in recommended_ids:
                p = get_product_by_id(pid)
                if p:
                    text = f"🏷 <b>{p['name']}</b>\n💰 {p['price']} ₸\n\n{p.get('description', '')}"
                    if p.get("photo_url"):
                        await message.answer_photo(
                            photo=p["photo_url"],
                            caption=text,
                            parse_mode="HTML",
                            reply_markup=product_detail_kb(p["id"], lang=lang)
                        )
                    else:
                        await message.answer(
                            text=text,
                            parse_mode="HTML",
                            reply_markup=product_detail_kb(p["id"], lang=lang)
                        )
                await asyncio.sleep(0.5)
        else:
            await message.answer(t("stylist_no_match", lang))

    except Exception as e:
        await status_msg.delete()
        await message.answer(t("stylist_error", lang))
