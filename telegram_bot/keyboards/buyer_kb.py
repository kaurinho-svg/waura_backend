from aiogram.utils.keyboard import InlineKeyboardBuilder
from aiogram.types import InlineKeyboardMarkup
from typing import Optional


def main_menu_btn(builder: InlineKeyboardBuilder):
    """Adds a 'Main Menu' button to an existing builder."""
    builder.button(text="🏠 Главное меню", callback_data="nav:main_menu")


def categories_kb(categories: list[str]) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for cat in categories:
        builder.button(text=f"🏷 {cat}", callback_data=f"catalog:cat:{cat}")
    builder.button(text="🛍 Все товары", callback_data="catalog:all")
    builder.adjust(2)
    main_menu_btn(builder)
    builder.adjust(2, 2, 1)
    return builder.as_markup()


def products_list_kb(products: list, offset: int = 0, limit: int = 5) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    page = products[offset:offset + limit]
    for p in page:
        store_name = (p.get("bot_stores") or {}).get("name", "")
        builder.button(
            text=f"{p['name']} — {p['price']} ₸ | {store_name}",
            callback_data=f"catalog:product:{p['id']}"
        )
    if offset > 0:
        builder.button(text="⬅️ Назад", callback_data=f"catalog:page:{offset - limit}")
    if offset + limit < len(products):
        builder.button(text="➡️ Далее", callback_data=f"catalog:page:{offset + limit}")
    builder.button(text="🔙 К категориям", callback_data="catalog:start")
    main_menu_btn(builder)
    builder.adjust(1)
    return builder.as_markup()


def product_detail_kb(product_id: str) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="👗 Примерить", callback_data=f"tryon:start:{product_id}")
    builder.button(text="🛒 Заказать", callback_data=f"order:start:{product_id}")
    builder.button(text="🔙 Назад", callback_data="catalog:all")
    main_menu_btn(builder)
    builder.adjust(2, 1, 1)
    return builder.as_markup()


def sizes_kb(sizes: list, product_id: str) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for s in sizes:
        builder.button(
            text=f"{s['size']} (осталось: {s['quantity']})",
            callback_data=f"order:size:{s['id']}"
        )
    builder.button(text="🔙 Назад к товару", callback_data=f"catalog:product:{product_id}")
    main_menu_btn(builder)
    builder.adjust(3, 1, 1)
    return builder.as_markup()


def delivery_choice_kb() -> InlineKeyboardMarkup:
    """Keyboard for choosing delivery or pickup."""
    builder = InlineKeyboardBuilder()
    builder.button(text="🚚 Доставка (укажу адрес)", callback_data="order:delivery:delivery")
    builder.button(text="🏪 Самовывоз", callback_data="order:delivery:pickup")
    builder.button(text="🔙 Назад к каталогу", callback_data="catalog:all")
    main_menu_btn(builder)
    builder.adjust(1)
    return builder.as_markup()


def payment_kb(order_id: str, kaspi_pay_url: Optional[str] = None) -> InlineKeyboardMarkup:
    """
    Payment keyboard shown after order is placed.
    Shows Kaspi Pay button if URL provided, then screenshot confirmation.
    """
    builder = InlineKeyboardBuilder()
    if kaspi_pay_url:
        builder.button(text="💳 Оплатить через Kaspi Pay", url=kaspi_pay_url)
    builder.button(text="✅ Я оплатил — отправить скрин", callback_data=f"order:paid:{order_id}")
    builder.button(text="🔙 Назад к каталогу", callback_data="catalog:all")
    main_menu_btn(builder)
    builder.adjust(1)
    return builder.as_markup()
