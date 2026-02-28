from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.shop_kb import (
    shop_main_menu, shop_products_menu, shop_product_actions,
    shop_settings_menu, cancel_kb, confirm_delete_kb, order_action_kb
)
from services.supabase_service import (
    get_store_by_telegram_id, update_store,
    get_products_by_store, create_product, get_product_by_id,
    delete_product, add_size, get_order_by_id, update_order_status,
)

router = Router()

ADMIN_CMD = "/admin"


# ─── FSM States ───────────────────────────────────────────────────────────────

class AddProduct(StatesGroup):
    photo = State()
    name = State()
    price = State()
    category = State()
    sizes = State()


class EditPayment(StatesGroup):
    kaspi = State()
    kaspi_pay = State()

class EditChannel(StatesGroup):
    channel_id = State()


# ─── Admin guard ──────────────────────────────────────────────────────────────

def is_owner(telegram_id: int, store: dict) -> bool:
    """Returns True if the user is the store owner, extra admin, or superadmin."""
    from config import SUPER_ADMIN_IDS
    if telegram_id in SUPER_ADMIN_IDS:
        return True
    if store.get("telegram_id") == telegram_id:
        return True
    extra_admins = store.get("admin_ids") or []
    return telegram_id in extra_admins


# ─── Admin menu ───────────────────────────────────────────────────────────────

@router.message(F.text == ADMIN_CMD)
async def admin_menu(message: Message, store: dict):
    if not is_owner(message.from_user.id, store):
        await message.answer("⛔️ У вас нет доступа к панели администратора.")
        return
    await message.answer(
        f"🔐 <b>Панель магазина {store['name']}</b>",
        parse_mode="HTML",
        reply_markup=shop_main_menu(),
    )


@router.callback_query(F.data == "shop:main")
async def shop_main(callback: CallbackQuery, state: FSMContext, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    await state.clear()
    await callback.message.edit_text(
        f"🏪 <b>{store['name']}</b> — управление",
        parse_mode="HTML",
        reply_markup=shop_main_menu(),
    )


# ─── My Products ──────────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:my_products")
async def my_products(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    products = get_products_by_store(store["id"])
    if not products:
        await callback.message.edit_text("📭 У вас пока нет товаров.", reply_markup=shop_main_menu())
        return

    await callback.message.answer(f"📦 <b>Ваши товары ({len(products)}):</b>", parse_mode="HTML")
    for p in products:
        caption = (
            f"🏷 <b>{p['name']}</b>\n"
            f"💰 {p['price']:,.0f} ₸\n"
            f"📂 {p.get('category', '—')}\n"
            f"{'✅ Активен' if p.get('is_active') else '❌ Скрыт'}"
        )
        if p.get("photo_url"):
            await callback.message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=shop_product_actions(p["id"]),
            )
        else:
            await callback.message.answer(
                caption,
                parse_mode="HTML",
                reply_markup=shop_product_actions(p["id"]),
            )
    await callback.answer()


@router.callback_query(F.data.startswith("shop:product:"))
async def product_detail_admin(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return
    caption = (
        f"🏷 <b>{p['name']}</b>\n"
        f"💰 {p['price']:,.0f} ₸\n"
        f"📂 {p.get('category', '—')}\n"
        f"{'✅ Активен' if p.get('is_active') else '❌ Скрыт'}"
    )
    if p.get("photo_url"):
        await callback.message.answer_photo(
            photo=p["photo_url"],
            caption=caption,
            parse_mode="HTML",
            reply_markup=shop_product_actions(product_id),
        )
    else:
        await callback.message.answer(
            caption,
            parse_mode="HTML",
            reply_markup=shop_product_actions(product_id),
        )
    await callback.answer()


@router.callback_query(F.data.startswith("shop:delete_product:"))
async def delete_confirm(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    # Use answer() not edit_text() — the message is now a photo card
    await callback.message.answer("⚠️ Удалить товар?", reply_markup=confirm_delete_kb(product_id))
    await callback.answer()


@router.callback_query(F.data.startswith("shop:confirm_delete:"))
async def delete_do(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    delete_product(product_id)
    await callback.message.answer("✅ Товар удалён.", reply_markup=shop_main_menu())
    await callback.answer()


# ─── Add Product ──────────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:add_product")
async def add_product_start(callback: CallbackQuery, state: FSMContext, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    await state.set_state(AddProduct.photo)
    await callback.message.edit_text("📸 Отправьте <b>фото товара</b>:", parse_mode="HTML", reply_markup=cancel_kb())


@router.message(AddProduct.photo, F.photo)
async def add_photo(message: Message, state: FSMContext):
    await state.update_data(photo_file_id=message.photo[-1].file_id)
    await state.set_state(AddProduct.name)
    await message.answer("✏️ Введите <b>название</b>:", parse_mode="HTML")


@router.message(AddProduct.name)
async def add_name(message: Message, state: FSMContext):
    await state.update_data(name=message.text.strip())
    await state.set_state(AddProduct.price)
    await message.answer("💰 Введите <b>цену</b> (только цифры):", parse_mode="HTML")


@router.message(AddProduct.price)
async def add_price(message: Message, state: FSMContext):
    try:
        price = float(message.text.strip().replace(" ", ""))
    except ValueError:
        await message.answer("❌ Введите число. Например: 12500")
        return
    await state.update_data(price=price)
    await state.set_state(AddProduct.category)
    await message.answer("📂 Введите <b>категорию</b> (Платья, Куртки, ...):", parse_mode="HTML")


@router.message(AddProduct.category)
async def add_category(message: Message, state: FSMContext):
    await state.update_data(category=message.text.strip())
    await state.set_state(AddProduct.sizes)
    await message.answer(
        "📏 Размеры и количество:\n<code>S:10, M:5, L:3</code>\nИли <code>-</code> если нет размеров:",
        parse_mode="HTML",
    )


@router.message(AddProduct.sizes)
async def add_sizes(message: Message, state: FSMContext, store: dict, bot: Bot):
    data = await state.get_data()
    await state.clear()

    from services.tryon_service import upload_image_to_backend
    file = await bot.get_file(data["photo_file_id"])
    file_bytes = await bot.download_file(file.file_path)

    await message.answer("⏳ Загружаю фото...")
    try:
        photo_url = await upload_image_to_backend(file_bytes.read())
    except Exception as e:
        await message.answer(f"❌ Ошибка загрузки фото: {e}")
        return

    product = create_product(store["id"], {
        "name": data["name"],
        "price": data["price"],
        "category": data["category"],
        "photo_url": photo_url,
        "description": "",
    })

    sizes_raw = message.text.strip()
    if sizes_raw != "-":
        for part in sizes_raw.split(","):
            if ":" in part:
                sz, qty = part.strip().split(":", 1)
                try:
                    add_size(product["id"], sz.strip(), int(qty.strip()))
                    add_size(product["id"], sz.strip(), int(qty.strip()))
                except Exception:
                    pass

    # Post to channel if VIP
    channel_id = store.get("channel_id")
    if store.get("is_vip") and channel_id:
        try:
            bot_me = await bot.get_me()
            prod_link = f"https://t.me/{bot_me.username}?start=prod_{product['id']}"
            
            from aiogram.utils.keyboard import InlineKeyboardBuilder
            kb = InlineKeyboardBuilder()
            kb.button(text="🛍 Купить в боте", url=prod_link)
            
            await bot.send_photo(
                chat_id=channel_id,
                photo=photo_url,
                caption=(
                    f"🔥 <b>Новинка в {store['name']}!</b>\n\n"
                    f"🏷 <b>{product['name']}</b>\n"
                    f"💰 {product['price']:,.0f} ₸\n"
                    f"📂 {product['category']}\n\n"
                    f"👇 Оформить заказ и примерить вещь можно в нашем боте:"
                ),
                parse_mode="HTML",
                reply_markup=kb.as_markup()
            )
        except Exception as e:
            await message.answer(f"⚠️ Товар добавлен, но не удалось опубликовать в канал: {e}")

    await message.answer(f"✅ Товар <b>{product['name']}</b> добавлен!", parse_mode="HTML", reply_markup=shop_main_menu())


# ─── Settings ─────────────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:settings")
async def shop_settings(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    from keyboards.shop_kb import shop_settings_menu
    channel_info = f"\n📢 Канал: {store.get('channel_id')}" if store.get("is_vip") and store.get("channel_id") else ""
    await callback.message.edit_text(
        f"⚙️ <b>Настройки</b>\n🏪 {store['name']}\n📱 Kaspi: {store.get('kaspi_phone') or 'не указан'}{channel_info}",
        parse_mode="HTML",
        reply_markup=shop_settings_menu(store["id"], is_vip=store.get("is_vip", False)),
    )


@router.callback_query(F.data == "shop:edit_payment")
async def edit_payment(callback: CallbackQuery, state: FSMContext, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    await state.set_state(EditPayment.kaspi)
    await callback.message.edit_text(
        "📱 Введите <b>номер Kaspi</b> (или '-' чтобы оставить старый):",
        parse_mode="HTML", reply_markup=cancel_kb()
    )


@router.message(EditPayment.kaspi)
async def edit_payment_kaspi(message: Message, state: FSMContext, store: dict):
    val = message.text.strip()
    if val != "-":
        update_store(store["id"], {"kaspi_phone": val})
    await state.set_state(EditPayment.kaspi_pay)
    await message.answer(
        "💳 Теперь введите <b>Kaspi Pay URL</b> вашего магазина\n"
        "(или '-' если нет Kaspi Pay для бизнеса):\n\n"
        "💡 Ссылка находится в приложении Kaspi Business → Приём оплаты",
        parse_mode="HTML",
    )


@router.message(EditPayment.kaspi_pay)
async def edit_payment_kaspi_pay(message: Message, state: FSMContext, store: dict):
    val = message.text.strip()
    if val != "-":
        update_store(store["id"], {"kaspi_pay_url": val})
    await state.clear()
    await message.answer("✅ Настройки обновлены!", reply_markup=shop_main_menu())

# ─── Edit Channel (VIP) ────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:edit_channel")
async def edit_channel(callback: CallbackQuery, state: FSMContext, store: dict):
    if not is_owner(callback.from_user.id, store) or not store.get("is_vip"):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    await state.set_state(EditChannel.channel_id)
    await callback.message.edit_text(
        "📢 Введите <b>ID канала</b> (например, <code>@my_shop_kz</code> или <code>-1001234567890</code>)\n\n"
        "⚠️ <b>Важно:</b> Сначала добавьте бота в этот канал как администратора с правом публиковать сообщения.\n"
        "Отправьте `-`, чтобы отключить публикацию в канал.",
        parse_mode="HTML", reply_markup=cancel_kb()
    )

@router.message(EditChannel.channel_id)
async def edit_channel_id(message: Message, state: FSMContext, store: dict, bot: Bot):
    val = message.text.strip()
    if val != "-":
        # Check permissions
        try:
            await bot.send_chat_action(chat_id=val, action="typing")
        except Exception:
            await message.answer("❌ Бот не имеет доступа к этому каналу. Добавьте его в администраторы и повторите попытку.")
            return
            
        update_store(store["id"], {"channel_id": val})
        await message.answer(f"✅ Канал {val} успешно подключен!", reply_markup=shop_main_menu())
    else:
        update_store(store["id"], {"channel_id": None})
        await message.answer("✅ Авто-публикация в канал отключена.", reply_markup=shop_main_menu())
    
    await state.clear()


# ─── Order confirmation (shop owner) ──────────────────────────────────────────

@router.callback_query(F.data.startswith("order:buyer_profile:"))
async def show_buyer_profile(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
        
    order_id = callback.data.split(":")[2]
    order = get_order_by_id(order_id)
    if not order:
        await callback.answer("Заказ не найден")
        return
        
    buyer_id = order["buyer_telegram_id"]
    from services.supabase_service import get_buyer_order_history
    history = get_buyer_order_history(store["id"], buyer_id)
    
    if history["is_first_time"]:
        text = "👤 <b>Портрет клиента:</b>\n\n🌟 <i>Это новый клиент! Первая покупка.</i>"
    else:
        text = (
            f"👤 <b>Портрет клиента:</b>\n\n"
            f"⭐️ <i>Постоянный клиент!</i>\n"
            f"🛍 Всего покупок: <b>{history['total_orders']}</b>\n"
            f"💰 Общая сумма: <b>{history['total_spent']:,.0f} ₸</b>\n"
        )
        if history["last_order_date"]:
            from datetime import datetime
            dt = datetime.fromisoformat(history["last_order_date"].replace("Z", "+00:00"))
            text += f"📅 Последняя покупка: <b>{dt.strftime('%d.%m.%Y')}</b>"
            
    await callback.answer()
    await callback.message.reply(text, parse_mode="HTML")


# ─── Settings ─────────────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:settings")
async def shop_settings(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    current_phone = store.get("kaspi_phone") or "не указан"
    current_url = store.get("kaspi_pay_url") or "не указана"
    await callback.message.answer(
        f"⚙️ <b>Настройки магазина {store['name']}</b>\n\n"
        f"📱 Kaspi номер: <code>{current_phone}</code>\n"
        f"🔗 Kaspi Pay URL: <code>{current_url}</code>",
        parse_mode="HTML",
        reply_markup=shop_settings_menu(
            store["id"],
            is_vip=store.get("is_vip", False),
            allow_cash=bool(store.get("allow_cash_payment")),
            kaspi_phone=store.get("kaspi_phone", ""),
        ),
    )
    await callback.answer()


@router.callback_query(F.data == "shop:edit_payment")
async def edit_payment_start(callback: CallbackQuery, state: FSMContext, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    await state.set_state(EditPayment.kaspi)
    current = store.get("kaspi_phone") or "не указан"
    await callback.message.answer(
        f"📱 Введите номер <b>Kaspi</b> для переводов:\n"
        f"<i>Текущий: {current}</i>\n\n"
        f"Формат: <code>+7 777 123 45 67</code>\n"
        f"Или напишите <code>-</code> чтобы очистить.",
        parse_mode="HTML",
        reply_markup=cancel_kb(),
    )
    await callback.answer()


@router.message(EditPayment.kaspi, F.text)
async def edit_payment_kaspi(message: Message, state: FSMContext, store: dict):
    phone = message.text.strip()
    if phone == "-":
        phone = ""
    update_store(store["id"], {"kaspi_phone": phone})
    await state.set_state(EditPayment.kaspi_pay)
    await message.answer(
        f"✅ Номер сохранён: <code>{phone or 'очищен'}</code>\n\n"
        f"🔗 Теперь введите <b>Kaspi Pay ссылку</b> (необязательно):\n"
        f"<i>Текущая: {store.get('kaspi_pay_url') or 'не указана'}</i>\n\n"
        f"Формат: <code>https://pay.kaspi.kz/pay/...</code>\n"
        f"Или напишите <code>-</code> чтобы пропустить.",
        parse_mode="HTML",
        reply_markup=cancel_kb(),
    )


@router.message(EditPayment.kaspi_pay, F.text)
async def edit_payment_kaspi_pay(message: Message, state: FSMContext, store: dict):
    url = message.text.strip()
    if url == "-":
        url = ""
    update_store(store["id"], {"kaspi_pay_url": url})
    await state.clear()
    await message.answer(
        f"✅ Реквизиты обновлены!\n\n"
        f"📱 Kaspi номер: <code>{store.get('kaspi_phone') or 'не указан'}</code>\n"
        f"🔗 Kaspi Pay URL: <code>{url or 'не указана'}</code>",
        parse_mode="HTML",
        reply_markup=shop_main_menu(),
    )


@router.callback_query(F.data == "shop:toggle_cash")
async def toggle_cash(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    current = bool(store.get("allow_cash_payment"))
    new_val = not current
    update_store(store["id"], {"allow_cash_payment": new_val})
    status = "включена ✅" if new_val else "выключена ⬜"
    await callback.answer(f"💵 Наличными при получении: {status}", show_alert=True)
    # Refresh settings
    store["allow_cash_payment"] = new_val
    current_phone = store.get("kaspi_phone") or "не указан"
    current_url = store.get("kaspi_pay_url") or "не указана"
    await callback.message.answer(
        f"⚙️ <b>Настройки магазина {store['name']}</b>\n\n"
        f"📱 Kaspi номер: <code>{current_phone}</code>\n"
        f"🔗 Kaspi Pay URL: <code>{current_url}</code>",
        parse_mode="HTML",
        reply_markup=shop_settings_menu(
            store["id"],
            is_vip=store.get("is_vip", False),
            allow_cash=new_val,
            kaspi_phone=store.get("kaspi_phone", ""),
        ),
    )


@router.callback_query(F.data.startswith("order:confirm:"))
async def confirm_order(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    order_id = callback.data.split(":")[2]
    order = get_order_by_id(order_id)
    if not order:
        await callback.answer("Заказ не найден")
        return
    update_order_status(order_id, "confirmed")
    await callback.message.edit_text(f"✅ Заказ #{order_id[:8]} подтверждён!")
    try:
        await callback.bot.send_message(order["buyer_telegram_id"], "🎉 Ваш заказ подтверждён! Ожидайте доставку.")
    except Exception:
        pass

    # Process Referral Reward
    try:
        from services.supabase_service import get_buyer, create_promocode, mark_referral_rewarded
        buyer = get_buyer(store["id"], order["buyer_telegram_id"])
        
        if buyer and buyer.get("referred_by") and not buyer.get("referral_rewarded"):
            referrer_id = buyer["referred_by"]
            create_promocode(store["id"], referrer_id, 50)
            mark_referral_rewarded(buyer["id"])
            
            try:
                await callback.bot.send_message(
                    referrer_id,
                    f"🎉 <b>Отличные новости!</b>\n\n"
                    f"Пользователь, которого вы пригласили, успешно оформил свой первый заказ!\n"
                    f"Вам начислен <b>промокод на скидку 50%</b>.\n"
                    f"Он применится автоматически при вашей следующей покупке в магазине {store['name']}! 🎁",
                    parse_mode="HTML"
                )
            except Exception:
                pass
    except Exception as e:
        print(f"Failed to process referral reward: {e}")


@router.callback_query(F.data.startswith("order:reject:"))
async def reject_order(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    order_id = callback.data.split(":")[2]
    order = get_order_by_id(order_id)
    if not order:
        await callback.answer("Заказ не найден")
        return
    update_order_status(order_id, "cancelled")
    await callback.message.edit_text(f"❌ Заказ #{order_id[:8]} отклонён.")
    try:
        await callback.bot.send_message(order["buyer_telegram_id"], "😔 Магазин отклонил ваш заказ.")
    except Exception:
        pass
