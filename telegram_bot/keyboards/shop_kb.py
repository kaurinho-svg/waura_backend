from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils.keyboard import ReplyKeyboardBuilder, InlineKeyboardBuilder


def shop_main_menu() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="📦 Мои товары", callback_data="shop:my_products")
    builder.button(text="➕ Добавить товар", callback_data="shop:add_product")
    builder.button(text="📊 Заказы", callback_data="shop:orders")
    builder.button(text="📈 Статистика", callback_data="shop:stats")
    builder.button(text="⚙️ Настройки магазина", callback_data="shop:settings")
    builder.adjust(2)
    return builder.as_markup()


def shop_products_menu(products: list) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for p in products:
        builder.button(text=f"🏷 {p['name']} — {p['price']} ₸", callback_data=f"shop:product:{p['id']}")
    builder.button(text="➕ Добавить товар", callback_data="shop:add_product")
    builder.button(text="🔙 Назад", callback_data="shop:main")
    builder.adjust(1)
    return builder.as_markup()


def shop_product_actions(product_id: str) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="🗑 Удалить", callback_data=f"shop:delete_product:{product_id}")
    builder.button(text="🔙 Назад", callback_data="shop:my_products")
    builder.adjust(2)
    return builder.as_markup()


def shop_settings_menu(store_id: str, is_vip: bool = False,
                       allow_cash: bool = False, kaspi_phone: str = "") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="💳 Изменить реквизиты Kaspi", callback_data="shop:edit_payment")
    # Cash on delivery toggle
    cash_icon = "✅" if allow_cash else "⬜"
    builder.button(text=f"{cash_icon} Наличными при получении", callback_data="shop:toggle_cash")
    # Kaspi phone transfer toggle (disabled by clearing phone)
    kaspi_icon = "✅" if kaspi_phone else "⬜"
    builder.button(text=f"{kaspi_icon} Перевод по номеру Kaspi", callback_data="shop:edit_payment")
    if is_vip:
        builder.button(text="📢 Подключить канал", callback_data="shop:edit_channel")
    builder.button(text="🔙 Назад", callback_data="shop:main")
    builder.adjust(1)
    return builder.as_markup()


def cancel_kb() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="❌ Отмена", callback_data="shop:main")
    return builder.as_markup()


def confirm_delete_kb(product_id: str) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="✅ Да, удалить", callback_data=f"shop:confirm_delete:{product_id}")
    builder.button(text="❌ Нет", callback_data=f"shop:product:{product_id}")
    builder.adjust(2)
    return builder.as_markup()


def order_action_kb(order_id: str, is_vip: bool = False) -> InlineKeyboardMarkup:
    """Keyboard for shop owner to confirm or reject an order."""
    builder = InlineKeyboardBuilder()
    if is_vip:
        builder.button(text="👤 Профиль клиента", callback_data=f"order:buyer_profile:{order_id}")
    builder.button(text="✅ Подтвердить", callback_data=f"order:confirm:{order_id}")
    builder.button(text="❌ Отклонить", callback_data=f"order:reject:{order_id}")
    builder.adjust(1 if is_vip else 2, 2)
    return builder.as_markup()
