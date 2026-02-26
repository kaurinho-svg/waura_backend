from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import product_detail_kb
from services.supabase_service import get_product_by_id
from services.tryon_service import upload_image_to_backend, do_tryon

router = Router()


class TryOnState(StatesGroup):
    waiting_user_photo = State()


# Store product_id in state data
@router.callback_query(F.data.startswith("tryon:start:"))
async def tryon_start(callback: CallbackQuery, state: FSMContext, store: dict):
    # Check Generation Limits
    if store.get("generations_left", 0) <= 0:
        await callback.answer(
            "В магазине закончились лимиты на примерки.",
            show_alert=True
        )
        return

    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p or not p.get("photo_url"):
        await callback.answer("❌ Нет фото товара для примерки")
        return

    await state.set_state(TryOnState.waiting_user_photo)
    await state.update_data(product_id=product_id, clothing_url=p["photo_url"])

    await callback.message.answer(
        "📸 Отправьте ваше <b>фото в полный рост</b> для примерки.\n\n"
        "💡 <i>Советы для лучшего результата:</i>\n"
        "• Станьте прямо, руки вдоль тела\n"
        "• Нейтральный фон\n"
        "• Хорошее освещение",
        parse_mode="HTML",
    )


@router.message(TryOnState.waiting_user_photo, F.photo)
async def tryon_process(message: Message, state: FSMContext, bot: Bot, store: dict):
    data = await state.get_data()
    await state.clear()

    product_id = data.get("product_id")
    clothing_url = data.get("clothing_url")

    processing_msg = await message.answer("⏳ Обрабатываю... Это займёт ~30 секунд.")

    try:
        # Upload user photo
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        file_bytes = await bot.download_file(file.file_path)
        user_url = await upload_image_to_backend(file_bytes.read())

        # Run try-on (use PRO model for premium/VIP stores, standard for basic)
        is_premium = store.get("is_premium", False) or store.get("is_vip", False)
        result_url = await do_tryon(user_image_url=user_url, clothing_image_url=clothing_url, is_premium=is_premium)

        # Decrement counter and check thresholds
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
                        f"В магазине <b>{store['name']}</b> заканчиваются лимиты виртуальных примерок.\n\n"
                        f"Осталось: <b>{new_gens}</b>.\n"
                        f"Обратитесь к администратору для пополнения баланса.",
                        parse_mode="HTML"
                    )
                except Exception:
                    pass

        await processing_msg.delete()
        await message.answer_photo(
            photo=result_url,
            caption="✨ <b>Вот как это будет выглядеть на вас!</b>\n\nПонравилось? Оформите заказ 👇",
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id),
        )
    except Exception as e:
        await processing_msg.delete()
        await message.answer(
            f"😔 Не удалось выполнить примерку. Попробуйте другое фото.\n\n<code>{e}</code>",
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id),
        )
