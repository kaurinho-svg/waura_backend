from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.buyer_kb import sizes_kb, payment_kb, delivery_choice_kb
from services.supabase_service import (
    get_product_by_id, get_sizes_by_product, create_order,
    update_order_payment_screenshot, get_order_by_id,
    get_store_admins, get_unused_promocode, mark_promocode_used, get_size_by_id
)
from keyboards.shop_kb import order_action_kb
from services.buyer_service import get_buyer
from locales import t, get_lang

router = Router()


class OrderState(StatesGroup):
    waiting_delivery_choice = State()
    waiting_delivery_address = State()
    waiting_screenshot = State()


def _get_lang(user_id: int, store: dict) -> str:
    buyer = get_buyer(store["id"], user_id)
    return get_lang(buyer)


# ─── Step 1: Select Size ────────────────────────────────────────────────────

@router.callback_query(F.data.startswith("order:start:"))
async def order_start(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    product_id = callback.data.split(":")[2]
    sizes = get_sizes_by_product(product_id)

    if not sizes:
        await callback.message.answer(t("sizes_unavailable", lang))
        return

    await callback.message.answer(
        t("choose_size", lang),
        reply_markup=sizes_kb(sizes, product_id, lang=lang),
    )
    await callback.answer()


# ─── Step 2: Size selected → ask delivery/pickup ────────────────────────────

@router.callback_query(F.data.startswith("order:size:"))
async def order_size_selected(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    parts = callback.data.split(":")
    size_id = parts[2]

    size_obj = get_size_by_id(size_id)
    if not size_obj:
        await callback.answer("Size not found")
        return

    product_id = size_obj["product_id"]
    size = size_obj["size"]

    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Product not found")
        return

    await state.set_state(OrderState.waiting_delivery_choice)
    await state.update_data(product_id=product_id, size_id=size_id, size=size)

    await callback.message.answer(
        t("size_chosen", lang, size=size),
        parse_mode="HTML",
        reply_markup=delivery_choice_kb(lang=lang),
    )
    await callback.answer()


# ─── Step 3a: Pickup selected → create order & show payment ─────────────────

@router.callback_query(F.data == "order:delivery:pickup", OrderState.waiting_delivery_choice)
async def order_pickup_selected(callback: CallbackQuery, state: FSMContext, store: dict):
    data = await state.get_data()
    await state.clear()
    await _finalize_order(callback, state, data, store,
                          delivery_type="pickup", delivery_address=None)


# ─── Step 3b: Delivery selected → ask for address ───────────────────────────

@router.callback_query(F.data == "order:delivery:delivery", OrderState.waiting_delivery_choice)
async def order_delivery_selected(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    await state.set_state(OrderState.waiting_delivery_address)
    await callback.message.answer(
        t("ask_address", lang),
        parse_mode="HTML",
    )
    await callback.answer()


# ─── Step 3c: Address received → create order & show payment ────────────────

@router.message(OrderState.waiting_delivery_address, F.text)
async def order_address_received(message: Message, state: FSMContext, store: dict):
    address = message.text.strip()
    data = await state.get_data()
    await state.clear()
    await _finalize_order_msg(message, state, data, store,
                              delivery_type="delivery", delivery_address=address)


# ─── Helpers ─────────────────────────────────────────────────────────────────

async def _finalize_order(callback: CallbackQuery, state: FSMContext, data: dict,
                          store: dict, delivery_type: str, delivery_address: str | None):
    lang = _get_lang(callback.from_user.id, store)
    try:
        product_id = data.get("product_id")
        size = data.get("size")

        if not product_id or not size:
            await callback.message.answer("❌ Данные заказа потеряны. Начните заново.")
            await callback.answer()
            return

        p = get_product_by_id(product_id)
        if not p:
            await callback.message.answer(t("order_not_found", lang))
            await callback.answer()
            return

        store_info = p.get("bot_stores") or {}
        kaspi_phone = store_info.get("kaspi_phone", "")
        kaspi_pay_url = store_info.get("kaspi_pay_url", "") or None
        store_name = store_info.get("name", "")

        # Try with delivery fields first, fall back without them if columns missing
        try:
            order = create_order(
                buyer_telegram_id=callback.from_user.id,
                product_id=product_id,
                size=size,
                delivery_type=delivery_type,
                delivery_address=delivery_address,
            )
        except Exception as e:
            print(f"create_order error (trying without delivery fields): {e}")
            # Fallback: create without delivery fields (if columns not in DB yet)
            from services.supabase_service import supabase as _sb
            res = _sb.from_("bot_orders").insert({
                "buyer_telegram_id": callback.from_user.id,
                "product_id": product_id,
                "size": size,
                "status": "pending",
            }).execute()
            order = res.data[0]

        order_id = order["id"]
        text = _build_order_text(p, size, store_name, kaspi_phone, kaspi_pay_url,
                                 store_info, callback.from_user.id,
                                 delivery_type, delivery_address, lang)

        await state.set_state(OrderState.waiting_screenshot)
        await state.update_data(order_id=order_id)

        await callback.message.answer(
            text, parse_mode="HTML",
            reply_markup=payment_kb(order_id, lang=lang, kaspi_pay_url=kaspi_pay_url)
        )
    except Exception as e:
        print(f"_finalize_order error: {e}")
        await callback.message.answer(
            "❌ Произошла ошибка при оформлении заказа. Попробуйте ещё раз."
        )
    finally:
        await callback.answer()


async def _finalize_order_msg(message: Message, state: FSMContext, data: dict,
                              store: dict, delivery_type: str, delivery_address: str | None):
    lang = _get_lang(message.from_user.id, store)
    try:
        product_id = data.get("product_id")
        size = data.get("size")

        if not product_id or not size:
            await message.answer("❌ Данные заказа потеряны. Начните заново.")
            return

        p = get_product_by_id(product_id)
        if not p:
            await message.answer(t("order_not_found", lang))
            return

        store_info = p.get("bot_stores") or {}
        kaspi_phone = store_info.get("kaspi_phone", "")
        kaspi_pay_url = store_info.get("kaspi_pay_url", "") or None
        store_name = store_info.get("name", "")

        try:
            order = create_order(
                buyer_telegram_id=message.from_user.id,
                product_id=product_id,
                size=size,
                delivery_type=delivery_type,
                delivery_address=delivery_address,
            )
        except Exception as e:
            print(f"create_order error (trying without delivery fields): {e}")
            from services.supabase_service import supabase as _sb
            res = _sb.from_("bot_orders").insert({
                "buyer_telegram_id": message.from_user.id,
                "product_id": product_id,
                "size": size,
                "status": "pending",
            }).execute()
            order = res.data[0]

        order_id = order["id"]
        text = _build_order_text(p, size, store_name, kaspi_phone, kaspi_pay_url,
                                 store_info, message.from_user.id,
                                 delivery_type, delivery_address, lang)

        await state.set_state(OrderState.waiting_screenshot)
        await state.update_data(order_id=order_id)

        await message.answer(
            text, parse_mode="HTML",
            reply_markup=payment_kb(order_id, lang=lang, kaspi_pay_url=kaspi_pay_url)
        )
    except Exception as e:
        print(f"_finalize_order_msg error: {e}")
        await message.answer(
            "❌ Произошла ошибка при оформлении заказа. Попробуйте ещё раз."
        )


def _build_order_text(p: dict, size: str, store_name: str, kaspi_phone: str,
                      kaspi_pay_url: str | None, store_info: dict,
                      buyer_id: int, delivery_type: str,
                      delivery_address: str | None, lang: str) -> str:
    price = p.get("price", 0)

    # Promo discount — fix arg order: get_unused_promocode(store_id, telegram_id)
    discount_line = ""
    final_price = price
    try:
        store_id_for_promo = store_info.get("id")
        if store_id_for_promo:
            promo = get_unused_promocode(store_id_for_promo, buyer_id)
            if promo:
                pct = promo.get("discount_percent", 0)
                final_price = int(price * (1 - pct / 100))
                discount_line = f"\n{t('discount_applied', lang, pct=pct)}\n"
                mark_promocode_used(promo["id"])
    except Exception as e:
        print(f"Promo check error (non-fatal): {e}")

    delivery_icon = t("order_delivery_label", lang) if delivery_type == "delivery" else t("order_pickup_label", lang)
    delivery_line = f"\n{t('order_delivery', lang)}: <b>{delivery_icon}</b>"
    if delivery_address:
        delivery_line += f"\n{t('order_address', lang)}: <b>{delivery_address}</b>"

    # Payment instructions
    if kaspi_pay_url:
        payment_line = ""
    elif kaspi_phone:
        payment_line = f"\n\n{t('payment_kaspi_phone', lang, phone=kaspi_phone)}"
    else:
        payment_line = f"\n\n{t('payment_ask_shop', lang)}"

    return (
        f"{t('order_placed', lang)}\n\n"
        f"{t('order_product', lang)}: <b>{p['name']}</b>\n"
        f"{t('order_size', lang)}: <b>{size}</b>\n"
        f"{t('order_store', lang)}: <b>{store_name}</b>"
        f"{delivery_line}"
        f"{discount_line}\n"
        f"{t('order_price', lang)}: <b>{final_price:,.0f} ₸</b>"
        f"{payment_line}\n\n"
        f"{t('payment_instructions', lang)}"
    )


# ─── Step 4: Paid → send screenshot ─────────────────────────────────────────

@router.callback_query(F.data.startswith("order:paid:"))
async def order_paid(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    order_id = callback.data.split(":")[2]
    await state.set_state(OrderState.waiting_screenshot)
    await state.update_data(order_id=order_id)
    await callback.message.answer(
        t("send_screenshot", lang),
        parse_mode="HTML",
    )
    await callback.answer()


# ─── Step 5: Screenshot received ────────────────────────────────────────────

@router.message(OrderState.waiting_screenshot, F.photo)
async def order_screenshot_received(message: Message, state: FSMContext, bot: Bot, store: dict):
    lang = _get_lang(message.from_user.id, store)
    data = await state.get_data()
    order_id = data.get("order_id")
    await state.clear()

    if not order_id:
        await message.answer(t("order_not_found", lang))
        return

    file_id = message.photo[-1].file_id
    update_order_payment_screenshot(order_id, file_id)

    order = get_order_by_id(order_id)
    if not order:
        await message.answer(t("order_not_found", lang))
        return

    # Confirm to buyer
    await message.answer(t("screenshot_received", lang), parse_mode="HTML")

    # Notify shop owner and admins (always in Russian - it's the seller's language)
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
            buyer_tg = f"@{buyer_username}" if buyer_username else str(message.from_user.id)

            from services.buyer_service import get_buyer as _get_buyer
            buyer_record = _get_buyer(store_id, message.from_user.id)
            buyer_name = (buyer_record or {}).get("name", "")
            buyer_info = f"{buyer_name} ({buyer_tg})" if buyer_name else buyer_tg

            caption = (
                f"🛒 <b>Новый заказ!</b>\n\n"
                f"🏷 Товар: {product_name}\n"
                f"📏 Размер: {order.get('size', '—')}\n"
                f"👤 Покупатель: {buyer_info}"
                f"{delivery_line}\n\n"
                f"Скриншот оплаты выше 👆"
            )

            is_vip = store_info.get("is_vip", False)
            for admin_id in admins_to_notify:
                try:
                    await bot.send_photo(
                        chat_id=admin_id,
                        photo=file_id,
                        caption=caption,
                        parse_mode="HTML",
                        reply_markup=order_action_kb(order_id, is_vip=is_vip),
                    )
                except Exception as e:
                    print(f"Failed to notify admin {admin_id}: {e}")

    except Exception as e:
        print(f"Order notification error: {e}")


# ─── Shop confirms / rejects order ──────────────────────────────────────────

@router.callback_query(F.data.startswith("order:confirm:"))
async def order_confirm(callback: CallbackQuery, bot: Bot):
    order_id = callback.data.split(":")[2]
    order = get_order_by_id(order_id)

    # Mark order as confirmed in DB
    update_order_status(order_id, "confirmed")

    # Notify buyer
    if order:
        buyer_id = order.get("buyer_telegram_id")
        product = (order.get("bot_products") or {})
        try:
            await bot.send_message(
                buyer_id,
                f"✅ <b>Ваш заказ подтверждён!</b>\n\n"
                f"🏷 Товар: <b>{product.get('name', '—')}</b>\n"
                f"📏 Размер: <b>{order.get('size', '—')}</b>\n\n"
                f"Спасибо за покупку! 🎉",
                parse_mode="HTML",
            )
        except Exception:
            pass

    # Remove action buttons and show status (answer() is safer than edit_caption)
    try:
        await callback.message.edit_reply_markup(reply_markup=None)
    except Exception:
        pass
    await callback.answer("✅ Заказ подтверждён", show_alert=True)
    await callback.message.answer("✅ <b>Заказ подтверждён</b>", parse_mode="HTML")


@router.callback_query(F.data.startswith("order:reject:"))
async def order_reject(callback: CallbackQuery, bot: Bot):
    order_id = callback.data.split(":")[2]
    order = get_order_by_id(order_id)

    # Mark order as rejected in DB
    update_order_status(order_id, "rejected")

    # Notify buyer
    if order:
        buyer_id = order.get("buyer_telegram_id")
        try:
            await bot.send_message(
                buyer_id,
                "❌ <b>Ваш заказ отклонён магазином.</b>\n\n"
                "Если у вас есть вопросы, свяжитесь с магазином напрямую.",
                parse_mode="HTML",
            )
        except Exception:
            pass

    # Remove action buttons
    try:
        await callback.message.edit_reply_markup(reply_markup=None)
    except Exception:
        pass
    await callback.answer("❌ Заказ отклонён", show_alert=True)
    await callback.message.answer("❌ <b>Заказ отклонён</b>", parse_mode="HTML")
