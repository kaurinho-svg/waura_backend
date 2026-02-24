from aiogram import Router, F
from aiogram.types import CallbackQuery

from keyboards.buyer_kb import categories_kb, products_list_kb, product_detail_kb
from services.supabase_service import (
    get_products_by_store_and_category,
    get_categories_for_store,
    get_product_by_id,
    get_sizes_by_product,
)

router = Router()

# Per-user product list cache for pagination {(user_id, store_id): [products]}
_cache: dict = {}


@router.callback_query(F.data.in_({"catalog:start", "catalog:categories"}))
async def catalog_categories(callback: CallbackQuery, store: dict):
    cats = get_categories_for_store(store["id"])
    await callback.message.edit_text(
        f"📂 Категории <b>{store['name']}</b>:\nВыберите категорию или посмотрите все:",
        parse_mode="HTML",
        reply_markup=categories_kb(cats),
    )


@router.callback_query(F.data == "catalog:all")
async def catalog_all(callback: CallbackQuery, store: dict):
    products = get_products_by_store_and_category(store["id"])
    if not products:
        await callback.message.edit_text(
            "😔 Пока нет товаров. Загляните позже!",
            reply_markup=categories_kb([]),
        )
        return
    key = (callback.from_user.id, store["id"])
    _cache[key] = products
    await callback.message.edit_text(
        f"🛍 Все товары <b>{store['name']}</b> ({len(products)}):",
        parse_mode="HTML",
        reply_markup=products_list_kb(products, offset=0),
    )


@router.callback_query(F.data.startswith("catalog:cat:"))
async def catalog_by_category(callback: CallbackQuery, store: dict):
    category = callback.data.split("catalog:cat:", 1)[1]
    products = get_products_by_store_and_category(store["id"], category=category)
    if not products:
        cats = get_categories_for_store(store["id"])
        await callback.message.edit_text(
            f"😔 В «{category}» пока нет товаров.",
            reply_markup=categories_kb(cats),
        )
        return
    key = (callback.from_user.id, store["id"])
    _cache[key] = products
    await callback.message.edit_text(
        f"🏷 <b>{category}</b> — {len(products)} товаров:",
        parse_mode="HTML",
        reply_markup=products_list_kb(products, offset=0),
    )


@router.callback_query(F.data.startswith("catalog:page:"))
async def catalog_page(callback: CallbackQuery, store: dict):
    offset = int(callback.data.split(":")[2])
    key = (callback.from_user.id, store["id"])
    products = _cache.get(key) or get_products_by_store_and_category(store["id"])
    _cache[key] = products
    await callback.message.edit_reply_markup(
        reply_markup=products_list_kb(products, offset=offset)
    )


@router.callback_query(F.data.startswith("catalog:product:"))
async def product_detail(callback: CallbackQuery, store: dict):
    product_id = callback.data.split(":")[2]
    p = get_product_by_id(product_id)
    if not p:
        await callback.answer("Товар не найден")
        return

    sizes = get_sizes_by_product(product_id)
    sizes_text = ", ".join(f"{s['size']}({s['quantity']}шт)" for s in sizes) if sizes else "уточните у магазина"

    caption = (
        f"🏷 <b>{p['name']}</b>\n"
        f"💰 {p['price']} ₸\n"
        f"📂 {p.get('category', '—')}\n"
        f"📏 Размеры: {sizes_text}"
    )

    try:
        if p.get("photo_url"):
            await callback.message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(product_id),
            )
            await callback.message.delete()
        else:
            await callback.message.edit_text(
                caption, parse_mode="HTML", reply_markup=product_detail_kb(product_id)
            )
    except Exception:
        await callback.message.edit_text(
            caption, parse_mode="HTML", reply_markup=product_detail_kb(product_id)
        )
