from aiogram.utils.keyboard import InlineKeyboardBuilder
from aiogram.types import InlineKeyboardMarkup
from typing import Optional

from locales import t


def main_menu_btn(builder: InlineKeyboardBuilder, lang: str = "ru"):
    """Adds a 'Main Menu' button to an existing builder."""
    builder.button(text=t("btn_main_menu", lang), callback_data="nav:main_menu")


def buyer_cancel_kb(lang: str = "ru") -> InlineKeyboardMarkup:
    """Cancel button for buyers — goes to main buyer menu."""
    builder = InlineKeyboardBuilder()
    builder.button(text=t("btn_cancel", lang), callback_data="nav:main_menu")
    return builder.as_markup()


def language_kb() -> InlineKeyboardMarkup:
    """Language selection keyboard."""
    builder = InlineKeyboardBuilder()
    builder.button(text="🇷🇺 Русский", callback_data="lang:ru")
    builder.button(text="🇰🇿 Қазақша", callback_data="lang:kk")
    builder.button(text="🇬🇧 English", callback_data="lang:en")
    builder.adjust(3)
    return builder.as_markup()


def categories_kb(categories: list[str], lang: str = "ru") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for cat in categories:
        builder.button(text=f"🏷 {cat}", callback_data=f"catalog:cat:{cat}")
    builder.button(text=t("catalog_all_btn", lang), callback_data="catalog:all")
    builder.adjust(2)
    main_menu_btn(builder, lang)
    builder.adjust(2, 2, 1)
    return builder.as_markup()


def products_list_kb(products: list, lang: str = "ru", offset: int = 0, limit: int = 5) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    page = products[offset:offset + limit]
    for p in page:
        store_name = (p.get("bot_stores") or {}).get("name", "")
        builder.button(
            text=f"{p['name']} — {p['price']} ₸ | {store_name}",
            callback_data=f"catalog:product:{p['id']}"
        )
    if offset > 0:
        builder.button(text=t("catalog_prev", lang), callback_data=f"catalog:page:{offset - limit}")
    if offset + limit < len(products):
        builder.button(text=t("catalog_next", lang), callback_data=f"catalog:page:{offset + limit}")
    builder.button(text=t("catalog_to_categories", lang), callback_data="catalog:start")
    main_menu_btn(builder, lang)
    builder.adjust(1)
    return builder.as_markup()


def product_card_kb(product_id: str, lang: str = "ru") -> InlineKeyboardMarkup:
    """Compact keyboard shown under each photo card in the catalog listing."""
    builder = InlineKeyboardBuilder()
    builder.button(text=t("btn_tryon", lang), callback_data=f"tryon:start:{product_id}")
    builder.button(text=t("btn_order", lang), callback_data=f"order:start:{product_id}")
    builder.button(text="🔍 Подробнее", callback_data=f"catalog:product:{product_id}")
    builder.adjust(2, 1)
    return builder.as_markup()


def load_more_kb(offset: int, lang: str = "ru") -> InlineKeyboardMarkup:
    """'Load more' navigation button after showing a page of product cards."""
    builder = InlineKeyboardBuilder()
    builder.button(text=f"📦 {t('catalog_next', lang)}", callback_data=f"catalog:page:{offset}")
    builder.button(text=t("catalog_to_categories", lang), callback_data="catalog:start")
    main_menu_btn(builder, lang)
    builder.adjust(1)
    return builder.as_markup()


def product_detail_kb(product_id: str, lang: str = "ru", profile_filled: bool = False) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text=t("btn_tryon", lang), callback_data=f"tryon:start:{product_id}")
    builder.button(text=t("btn_order", lang), callback_data=f"order:start:{product_id}")
    if profile_filled:
        builder.button(text="🪄 Подобрать размер (AI)", callback_data=f"ai:size:{product_id}")
    builder.button(text=t("btn_back", lang), callback_data="catalog:all")
    main_menu_btn(builder, lang)
    if profile_filled:
        builder.adjust(2, 1, 1, 1)
    else:
        builder.adjust(2, 1, 1)
    return builder.as_markup()


def sizes_kb(sizes: list, product_id: str, lang: str = "ru") -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for s in sizes:
        builder.button(
            text=f"{s['size']} (осталось: {s['quantity']})",
            callback_data=f"order:size:{s['id']}"
        )
    builder.button(text=t("btn_back_to_product", lang), callback_data=f"catalog:product:{product_id}")
    main_menu_btn(builder, lang)
    builder.adjust(3, 1, 1)
    return builder.as_markup()


def delivery_choice_kb(lang: str = "ru") -> InlineKeyboardMarkup:
    """Keyboard for choosing delivery or pickup."""
    builder = InlineKeyboardBuilder()
    builder.button(text=t("btn_delivery", lang), callback_data="order:delivery:delivery")
    builder.button(text=t("btn_pickup", lang), callback_data="order:delivery:pickup")
    builder.button(text=t("btn_back_to_catalog", lang), callback_data="catalog:all")
    main_menu_btn(builder, lang)
    builder.adjust(1)
    return builder.as_markup()


def payment_kb(order_id: str, lang: str = "ru", kaspi_pay_url: Optional[str] = None,
               store: Optional[dict] = None) -> InlineKeyboardMarkup:
    """Payment keyboard shown after order is placed."""
    builder = InlineKeyboardBuilder()
    s = store or {}

    if kaspi_pay_url:
        builder.button(text=t("payment_kaspi_btn", lang), url=kaspi_pay_url)

    # Cash on delivery button — show if store explicitly allows it
    allow_cash_val = s.get("allow_cash_payment")
    allow_cash = bool(allow_cash_val) if allow_cash_val is not None else False
    if allow_cash:
        builder.button(text="💵 Наличными при получении", callback_data=f"order:cash:{order_id}")

    builder.button(text=t("payment_send_screenshot", lang), callback_data=f"order:paid:{order_id}")
    builder.button(text=t("btn_back_to_catalog", lang), callback_data="catalog:all")
    main_menu_btn(builder, lang)
    builder.adjust(1)
    return builder.as_markup()
