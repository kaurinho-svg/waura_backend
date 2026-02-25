from aiogram import Router, F, Bot
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery

from keyboards.shop_kb import (
    shop_main_menu, shop_products_menu, shop_product_actions,
    cancel_kb, confirm_delete_kb, order_action_kb
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
    await callback.message.edit_text(
        f"📦 Товары ({len(products)}):",
        reply_markup=shop_products_menu(products),
    )


@router.callback_query(F.data.startswith("shop:product:"))
async def product_detail(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return
    await callback.message.edit_text(
        f"🏷 <b>{p['name']}</b>\n💰 {p['price']} ₸\n📂 {p.get('category', '—')}",
        parse_mode="HTML",
        reply_markup=shop_product_actions(product_id),
    )


@router.callback_query(F.data.startswith("shop:delete_product:"))
async def delete_confirm(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    await callback.message.edit_text("⚠️ Удалить товар?", reply_markup=confirm_delete_kb(product_id))


@router.callback_query(F.data.startswith("shop:confirm_delete:"))
async def delete_do(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    product_id = callback.data.split(":")[2]
    delete_product(product_id)
    await callback.message.edit_text("✅ Товар удалён.", reply_markup=shop_main_menu())


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
                except Exception:
                    pass

    await message.answer(f"✅ Товар <b>{product['name']}</b> добавлен!", parse_mode="HTML", reply_markup=shop_main_menu())


# ─── Settings ─────────────────────────────────────────────────────────────────

@router.callback_query(F.data == "shop:settings")
async def shop_settings(callback: CallbackQuery, store: dict):
    if not is_owner(callback.from_user.id, store):
        await callback.answer("⛔️ Нет доступа", show_alert=True)
        return
    from keyboards.shop_kb import shop_settings_menu
    await callback.message.edit_text(
        f"⚙️ <b>Настройки</b>\n🏪 {store['name']}\n📱 Kaspi: {store.get('kaspi_phone') or 'не указан'}",
        parse_mode="HTML",
        reply_markup=shop_settings_menu(store["id"]),
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


# ─── Order confirmation (shop owner) ──────────────────────────────────────────

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
