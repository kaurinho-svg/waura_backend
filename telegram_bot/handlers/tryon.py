from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import product_detail_kb, buyer_cancel_kb
from services.supabase_service import get_product_by_id
from services.tryon_service import upload_image_to_backend, do_tryon
from services.buyer_service import get_buyer
from locales import t, get_lang

router = Router()


class TryOnState(StatesGroup):
    waiting_user_photo = State()


@router.callback_query(F.data.startswith("tryon:start:"))
async def tryon_start(callback: CallbackQuery, state: FSMContext, store: dict):
    buyer = get_buyer(store["id"], callback.from_user.id)
    lang = get_lang(buyer)

    # Check if try-on is enabled for this store (None = use default True, False = disabled)
    feature_tryon = store.get("feature_tryon")
    if feature_tryon is not None and not bool(feature_tryon):
        await callback.answer(t("tryon_no_gens", lang), show_alert=True)
        return

    if store.get("generations_left", 0) <= 0:
        await callback.answer(t("tryon_no_gens", lang), show_alert=True)
        return

    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p or not p.get("photo_url"):
        await callback.answer(t("tryon_no_photo", lang))
        return

    await state.set_state(TryOnState.waiting_user_photo)
    await state.update_data(product_id=product_id, clothing_url=p["photo_url"])

    await callback.message.answer(
        t("tryon_instructions", lang),
        parse_mode="HTML",
        reply_markup=buyer_cancel_kb(lang),
    )
    await callback.answer()


@router.message(TryOnState.waiting_user_photo, F.photo)
async def tryon_process(message: Message, state: FSMContext, bot: Bot, store: dict):
    data = await state.get_data()
    await state.clear()

    product_id = data.get("product_id")
    clothing_url = data.get("clothing_url")

    buyer = get_buyer(store["id"], message.from_user.id)
    lang = get_lang(buyer)

    processing_msg = await message.answer(t("tryon_processing", lang))

    try:
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        file_bytes = await bot.download_file(file.file_path)
        user_url = await upload_image_to_backend(file_bytes.read())

        is_vip = store.get("is_vip", False)
        is_premium = store.get("is_premium", False)
        result_url = await do_tryon(user_image_url=user_url, clothing_image_url=clothing_url,
                                    is_premium=is_premium, is_vip=is_vip)

        current_gens = store.get("generations_left") or 0
        from services.supabase_service import decrement_store_generations, get_store_admins
        decrement_store_generations(store["id"], current_gens)

        new_gens = current_gens - 1
        if new_gens in (10, 5, 0):
            admins_to_notify = [store["telegram_id"]] + get_store_admins(store["id"])
            for adm_id in set(admins_to_notify):
                try:
                    await bot.send_message(
                        adm_id,
                        f"⚠️ <b>Внимание!</b>\n"
                        f"В магазине <b>{store['name']}</b> заканчиваются лимиты примерок.\n\n"
                        f"Осталось: <b>{new_gens}</b>.",
                        parse_mode="HTML"
                    )
                except Exception:
                    pass

        await processing_msg.delete()
        await message.answer_photo(
            photo=result_url,
            caption=t("tryon_result", lang),
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id, lang=lang),
        )
    except Exception as e:
        await processing_msg.delete()
        await message.answer(
            t("tryon_error", lang),
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id, lang=lang),
        )
