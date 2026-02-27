from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import sizes_kb, payment_kb, delivery_choice_kb
from services.supabase_service import (
    get_product_by_id, get_sizes_by_product, get_store_by_telegram_id,
    create_order, update_order_payment_screenshot, get_order_by_id,
    decrement_size_quantity, get_store_admins,
    get_unused_promocode, mark_promocode_used, get_size_by_id
)
from keyboards.shop_kb import order_action_kb

router = Router()


class OrderState(StatesGroup):
    waiting_delivery_choice = State()
    waiting_delivery_address = State()
    waiting_screenshot = State()


# ─── Step 1: Select Size ────────────────────────────────────────────────────

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
    await callback.answer()


# ─── Step 2: Size selected → ask delivery/pickup ────────────────────────────

@router.callback_query(F.data.startswith("order:size:"))
async def order_size_selected(callback: CallbackQuery, state: FSMContext):
    parts = callback.data.split(":")
    size_id = parts[2]

    size_obj = get_size_by_id(size_id)
    if not size_obj:
        await callback.answer("Размер не найден")
        return

    product_id = size_obj["product_id"]
    size = size_obj["size"]

    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    # Save product info into FSM state for next steps
    await state.set_state(OrderState.waiting_delivery_choice)
    await state.update_data(
        product_id=product_id,
        size_id=size_id,
        size=size,
    )

    await callback.message.answer(
        f"✅ Размер <b>{size}</b> выбран!\n\n"
        "🚚 <b>Как вы хотите получить товар?</b>",
        parse_mode="HTML",
        reply_markup=delivery_choice_kb(),
    )
    await callback.answer()


# ─── Step 3a: Pickup selected → create order & show payment ─────────────────

@router.callback_query(F.data == "order:delivery:pickup", OrderState.waiting_delivery_choice)
async def order_pickup_selected(callback: CallbackQuery, state: FSMContext):
    data = await state.get_data()
    await state.clear()
    await _finalize_order(callback, state, data, delivery_type="pickup", delivery_address=None)


# ─── Step 3b: Delivery selected → ask for address ───────────────────────────

@router.callback_query(F.data == "order:delivery:delivery", OrderState.waiting_delivery_choice)
async def order_delivery_selected(callback: CallbackQuery, state: FSMContext):
    await state.set_state(OrderState.waiting_delivery_address)
    await callback.message.answer(
        "📍 Пожалуйста, укажите ваш <b>адрес доставки</b>:\n"
        "<i>(Город, улица, дом, квартира)</i>",
        parse_mode="HTML",
    )
    await callback.answer()


# ─── Step 3c: Address received → create order & show payment ────────────────

@router.message(OrderState.waiting_delivery_address, F.text)
async def order_address_received(message: Message, state: FSMContext):
    address = message.text.strip()
    data = await state.get_data()
    await state.clear()

    # Wrap state so we can pass bot through a helper
    await _finalize_order_msg(message, state, data, delivery_type="delivery", delivery_address=address)


# ─── Helpers ─────────────────────────────────────────────────────────────────

async def _finalize_order(callback: CallbackQuery, state: FSMContext, data: dict,
                          delivery_type: str, delivery_address: str | None):
    """Called when delivery choice is made via a callback (pickup)."""
    product_id = data["product_id"]
    size = data["size"]

    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    store_info = p.get("bot_stores") or {}
    kaspi_phone = store_info.get("kaspi_phone", "")
    kaspi_pay_url = store_info.get("kaspi_pay_url", "") or None
    store_name = store_info.get("name", "Магазин")

    order = create_order(
        buyer_telegram_id=callback.from_user.id,
        product_id=product_id,
        size=size,
        delivery_type=delivery_type,
        delivery_address=delivery_address,
    )
    order_id = order["id"]

    text = _build_order_text(p, size, store_name, kaspi_phone, kaspi_pay_url,
                             store_info, callback.from_user.id,
                             delivery_type, delivery_address)

    await state.set_state(OrderState.waiting_screenshot)
    await state.update_data(order_id=order_id)

    await callback.message.answer(text, parse_mode="HTML",
                                  reply_markup=payment_kb(order_id, kaspi_pay_url=kaspi_pay_url))
    await callback.answer()


async def _finalize_order_msg(message: Message, state: FSMContext, data: dict,
                              delivery_type: str, delivery_address: str | None):
    """Called when delivery choice is made via a text message (address given)."""
    product_id = data["product_id"]
    size = data["size"]

    p = get_product_by_id(product_id)
    if not p:
        await message.answer("😔 Товар не найден. Попробуйте ещё раз.")
        return

    store_info = p.get("bot_stores") or {}
    kaspi_phone = store_info.get("kaspi_phone", "")
    kaspi_pay_url = store_info.get("kaspi_pay_url", "") or None
    store_name = store_info.get("name", "Магазин")

    order = create_order(
        buyer_telegram_id=message.from_user.id,
        product_id=product_id,
        size=size,
        delivery_type=delivery_type,
        delivery_address=delivery_address,
    )
    order_id = order["id"]

    text = _build_order_text(p, size, store_name, kaspi_phone, kaspi_pay_url,
                             store_info, message.from_user.id,
                             delivery_type, delivery_address)

    await state.set_state(OrderState.waiting_screenshot)
    await state.update_data(order_id=order_id)

    await message.answer(text, parse_mode="HTML",
                         reply_markup=payment_kb(order_id, kaspi_pay_url=kaspi_pay_url))


def _build_order_text(p, size, store_name, kaspi_phone, kaspi_pay_url,
                      store_info, buyer_id, delivery_type, delivery_address):
    """Build the order summary text including promo and delivery info."""
    original_price = float(p["price"])
    final_price = original_price
    discount_text = ""

    promo = get_unused_promocode(store_info.get("id"), buyer_id)
    if promo:
        discount = promo.get("discount_percent", 50)
        final_price = original_price * (100 - discount) / 100
        discount_text = f"🎁 <b>Применена скидка {discount}% (Приведи друга)!</b>\n"
        mark_promocode_used(promo["id"])

    if kaspi_pay_url:
        payment_text = "💳 Нажмите кнопку ниже — оплата через Kaspi Pay"
    elif kaspi_phone:
        payment_text = f"📱 Kaspi: <b>{kaspi_phone}</b> — переведите сумму"
    else:
        payment_text = "💳 Уточните реквизиты у магазина"

    delivery_icon = "🚚 Доставка" if delivery_type == "delivery" else "🏪 Самовывоз"
    delivery_line = f"📦 Способ получения: <b>{delivery_icon}</b>\n"
    if delivery_address:
        delivery_line += f"📍 Адрес: <b>{delivery_address}</b>\n"

    return (
        f"🛒 <b>Ваш заказ оформлен!</b>\n\n"
        f"🏷 Товар: {p['name']}\n"
        f"📏 Размер: {size}\n"
        f"💰 К оплате: <b>{final_price:,.0f} ₸</b> "
        f"{f'<s>{original_price:,.0f} ₸</s>' if discount_text else ''}\n"
        f"{discount_text}"
        f"🏪 Магазин: {store_name}\n"
        f"{delivery_line}"
        f"{payment_text}\n\n"
        f"После оплаты отправьте <b>скриншот подтверждения</b>."
    )


# ─── Step 4: Screenshot ──────────────────────────────────────────────────────

@router.callback_query(F.data.startswith("order:paid:"))
async def order_paid_button(callback: CallbackQuery, state: FSMContext):
    await callback.message.answer(
        "📸 Пожалуйста, отправьте <b>скриншот</b> подтверждения оплаты:",
        parse_mode="HTML",
    )
    await callback.answer()


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

    # Notify the shop owner and all admins
    try:
        product = order.get("bot_products") or {}
        store_info = (product.get("bot_stores") or {})
        store_id = store_info.get("id")
        shop_telegram_id = store_info.get("telegram_id")
        product_name = product.get("name", "—")

        delivery_type = order.get("delivery_type", "pickup")
        delivery_address = order.get("delivery_address", "")
        delivery_icon = "🚚 Доставка" if delivery_type == "delivery" else "🏪 Самовывоз"
        delivery_line = f"\n📦 Получение: <b>{delivery_icon}</b>"
        if delivery_address:
            delivery_line += f"\n📍 Адрес: <b>{delivery_address}</b>"

        admins_to_notify = []
        if shop_telegram_id:
            admins_to_notify.append(shop_telegram_id)
        if store_id:
            extra_admins = get_store_admins(store_id)
            admins_to_notify.extend(extra_admins)
        admins_to_notify = list(set(admins_to_notify))

        if admins_to_notify:
            buyer_username = message.from_user.username
            buyer_info = f"@{buyer_username}" if buyer_username else str(message.from_user.id)

            caption = (
                f"🛒 <b>Новый заказ!</b>\n\n"
                f"🏷 Товар: {product_name}\n"
                f"📏 Размер: {order.get('size', '—')}\n"
                f"👤 Покупатель: {buyer_info}"
                f"{delivery_line}\n\n"
                f"Скриншот оплаты выше 👆"
            )

            for admin_id in admins_to_notify:
                try:
                    await bot.send_photo(
                        chat_id=admin_id,
                        photo=file_id,
                        caption=caption,
                        parse_mode="HTML",
                        reply_markup=order_action_kb(order_id, is_vip=store_info.get("is_vip", False)),
                    )
                except Exception as inner_e:
                    print(f"Failed to notify admin {admin_id}: {inner_e}")

    except Exception as e:
        print(f"Failed to notify shop admins: {e}")

    await message.answer(
        "✅ Ваш скриншот получен! Магазин скоро подтвердит заказ.\n\n"
        "Мы уведомим вас о статусе."
    )
