from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import sizes_kb, payment_kb
from services.supabase_service import (
    get_product_by_id, get_sizes_by_product, get_store_by_telegram_id,
    create_order, update_order_payment_screenshot, get_order_by_id,
    decrement_size_quantity
)
from keyboards.shop_kb import order_action_kb

router = Router()


class OrderState(StatesGroup):
    waiting_screenshot = State()


@router.callback_query(F.data.startswith("order:start:"))
async def order_start(callback: CallbackQuery):
    product_id = callback.data.split(":")[2]
    sizes = get_sizes_by_product(product_id)

    if not sizes:
        await callback.message.answer("😔 К сожалению, все размеры распроданы.")
        return

    await callback.message.answer(
        "📏 Выберите ваш размер:",
        reply_markup=sizes_kb(sizes, product_id),
    )


@router.callback_query(F.data.startswith("order:size:"))
async def order_size_selected(callback: CallbackQuery, state: FSMContext):
    parts = callback.data.split(":")
    product_id = parts[2]
    size = parts[3]

    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    store_info = p.get("bot_stores") or {}
    kaspi_phone = store_info.get("kaspi_phone", "")
    kaspi_pay_url = store_info.get("kaspi_pay_url", "") or None
    store_name = store_info.get("name", "Магазин")

    # Create the order
    order = create_order(
        buyer_telegram_id=callback.from_user.id,
        product_id=product_id,
        size=size,
    )
    order_id = order["id"]

    if kaspi_pay_url:
        payment_text = f"💳 Нажмите кнопку ниже — оплата через Kaspi Pay"
    elif kaspi_phone:
        payment_text = f"📱 Kaspi: <b>{kaspi_phone}</b> — переведите сумму"
    else:
        payment_text = "💳 Уточните реквизиты у магазина"

    await state.set_state(OrderState.waiting_screenshot)
    await state.update_data(order_id=order_id)

    await callback.message.answer(
        f"🛒 <b>Ваш заказ оформлен!</b>\n\n"
        f"🏷 Товар: {p['name']}\n"
        f"📏 Размер: {size}\n"
        f"💰 Сумма: <b>{p['price']} ₸</b>\n\n"
        f"📦 Магазин: {store_name}\n"
        f"{payment_text}\n\n"
        f"После оплаты отправьте <b>скриншот подтверждения</b>.",
        parse_mode="HTML",
        reply_markup=payment_kb(order_id, kaspi_pay_url=kaspi_pay_url),
    )


@router.callback_query(F.data.startswith("order:paid:"))
async def order_paid_button(callback: CallbackQuery, state: FSMContext):
    await callback.message.answer(
        "📸 Пожалуйста, отправьте <b>скриншот</b> подтверждения оплаты:",
        parse_mode="HTML",
    )


@router.message(OrderState.waiting_screenshot, F.photo)
async def order_screenshot_received(message: Message, state: FSMContext, bot: Bot):
    data = await state.get_data()
    order_id = data.get("order_id")
    await state.clear()

    if not order_id:
        await message.answer("❌ Заказ не найден. Начните заново.")
        return

    file_id = message.photo[-1].file_id
    update_order_payment_screenshot(order_id, file_id)

    order = get_order_by_id(order_id)
    if not order:
        await message.answer("❌ Заказ не найден")
        return

    # Notify the shop owner
    try:
        product = order.get("bot_products") or {}
        store_info = (product.get("bot_stores") or {})
        shop_telegram_id = store_info.get("telegram_id")
        product_name = product.get("name", "—")

        if shop_telegram_id:
            buyer_username = message.from_user.username
            buyer_info = f"@{buyer_username}" if buyer_username else str(message.from_user.id)

            await bot.send_photo(
                chat_id=shop_telegram_id,
                photo=file_id,
                caption=(
                    f"🛒 <b>Новый заказ!</b>\n\n"
                    f"🏷 Товар: {product_name}\n"
                    f"📏 Размер: {order.get('size', '—')}\n"
                    f"👤 Покупатель: {buyer_info}\n\n"
                    f"Скриншот оплаты выше 👆"
                ),
                parse_mode="HTML",
                reply_markup=order_action_kb(order_id),
            )
    except Exception as e:
        print(f"Failed to notify shop: {e}")

    await message.answer(
        "✅ Ваш скриншот получен! Магазин скоро подтвердит заказ.\n\n"
        "Мы уведомим вас о статусе."
    )
