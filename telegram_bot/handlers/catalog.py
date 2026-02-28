from aiogram import Router, F
from aiogram.types import CallbackQuery, Message

from keyboards.buyer_kb import (
    categories_kb, product_card_kb, load_more_kb, product_detail_kb
)
from services.supabase_service import (
    get_products_by_store_and_category,
    get_categories_for_store,
    get_product_by_id,
    get_sizes_by_product,
)
from services.buyer_service import get_buyer
from locales import t, get_lang

router = Router()

PAGE_SIZE = 5

# Per-user product list cache for pagination
_cache: dict = {}


def _get_lang(user_id: int, store: dict) -> str:
    buyer = get_buyer(store["id"], user_id)
    return get_lang(buyer)


async def _send_product_cards(message, products: list, lang: str, offset: int = 0):
    """Sends a page of product photo cards. Each card = photo + caption + buttons."""
    page = products[offset: offset + PAGE_SIZE]

    for p in page:
        caption = (
            f"🏷 <b>{p['name']}</b>\n"
            f"💰 <b>{p['price']:,.0f} ₸</b>\n"
            f"📂 {p.get('category', '—')}"
        )
        if p.get("photo_url"):
            await message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_card_kb(p["id"], lang=lang),
            )
        else:
            await message.answer(
                caption,
                parse_mode="HTML",
                reply_markup=product_card_kb(p["id"], lang=lang),
            )

    # Navigation row at the end
    next_offset = offset + PAGE_SIZE
    if next_offset < len(products):
        await message.answer(
            f"📦 {offset + len(page)}/{len(products)}",
            reply_markup=load_more_kb(next_offset, lang=lang),
        )


@router.callback_query(F.data.in_({"catalog:start", "catalog:categories"}))
async def catalog_categories(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    cats = get_categories_for_store(store["id"])
    await callback.message.answer(
        t("catalog_title", lang, store=store["name"]),
        parse_mode="HTML",
        reply_markup=categories_kb(cats, lang=lang),
    )
    await callback.answer()


@router.callback_query(F.data == "catalog:all")
async def catalog_all(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    products = get_products_by_store_and_category(store["id"])
    if not products:
        await callback.message.answer(t("catalog_empty", lang))
        await callback.answer()
        return

    key = (callback.from_user.id, store["id"])
    _cache[key] = products

    await callback.message.answer(
        t("catalog_all_title", lang, store=store["name"], count=len(products)),
        parse_mode="HTML",
    )
    await _send_product_cards(callback.message, products, lang, offset=0)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:cat:"))
async def catalog_by_category(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    category = callback.data.split("catalog:cat:", 1)[1]
    products = get_products_by_store_and_category(store["id"], category=category)
    if not products:
        cats = get_categories_for_store(store["id"])
        await callback.message.answer(
            t("catalog_empty_cat", lang, category=category),
            reply_markup=categories_kb(cats, lang=lang),
        )
        await callback.answer()
        return

    key = (callback.from_user.id, store["id"])
    _cache[key] = products

    await callback.message.answer(
        f"🏷 <b>{category}</b> — {len(products)}:",
        parse_mode="HTML",
    )
    await _send_product_cards(callback.message, products, lang, offset=0)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:page:"))
async def catalog_page(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    offset = int(callback.data.split(":")[2])
    key = (callback.from_user.id, store["id"])
    products = _cache.get(key) or get_products_by_store_and_category(store["id"])
    _cache[key] = products
    await _send_product_cards(callback.message, products, lang, offset=offset)
    await callback.answer()


@router.callback_query(F.data.startswith("catalog:product:"))
async def product_detail(callback: CallbackQuery, store: dict):
    lang = _get_lang(callback.from_user.id, store)
    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    sizes = get_sizes_by_product(product_id)
    sizes_text = ", ".join(
        f"{s['size']} ({s['quantity']} шт)" for s in sizes
    ) if sizes else "—"

    caption = (
        f"🏷 <b>{p['name']}</b>\n"
        f"💰 {p['price']:,.0f} ₸\n"
        f"📂 {p.get('category', '—')}\n"
        f"📏 Размеры: {sizes_text}\n\n"
        f"📝 {p.get('description', '')}"
    )

    try:
        if p.get("photo_url"):
            await callback.message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(product_id, lang=lang),
            )
        else:
            await callback.message.answer(
                caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(product_id, lang=lang),
            )
    except Exception:
        await callback.message.answer(
            caption,
            parse_mode="HTML",
            reply_markup=product_detail_kb(product_id, lang=lang),
        )
    await callback.answer()
