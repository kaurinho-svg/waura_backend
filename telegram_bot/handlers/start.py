from aiogram import Router, F, Bot
from aiogram.filters import CommandStart, CommandObject, Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder

from services.buyer_service import register_buyer, get_buyer, save_buyer_name, save_buyer_language
from locales import t, get_lang
from keyboards.buyer_kb import language_kb, buyer_cancel_kb

router = Router()


class OnboardingState(StatesGroup):
    waiting_name = State()
    waiting_language = State()


def main_menu_kb(lang: str = "ru", is_premium: bool = False, is_vip: bool = False,
                 store: dict = None):
    """Builds the main buyer menu based on per-store feature flags (or tier as fallback).
    Flag = None  → fall back to tier logic
    Flag = True  → always show (regardless of tier)
    Flag = False → always hide (regardless of tier)
    """
    s = store or {}

    def _flag(key, tier_default):
        val = s.get(key)
        return tier_default if val is None else bool(val)

    show_stylist  = _flag("feature_stylist",  is_premium or is_vip)
    show_referral = _flag("feature_referral", is_vip)

    builder = InlineKeyboardBuilder()
    builder.button(text=t("btn_catalog", lang), callback_data="catalog:start")
    builder.button(text=t("btn_categories", lang), callback_data="catalog:categories")
    builder.button(text="👤 Мой профиль", callback_data="profile:start")
    if show_stylist:
        builder.button(text=t("btn_stylist", lang), callback_data="stylist:start")
    if show_referral:
        builder.button(text=t("btn_referral", lang), callback_data="referral:get_link")
    builder.adjust(2, 1, 2)
    return builder.as_markup()


@router.message(CommandStart())
async def cmd_start(message: Message, command: CommandObject, state: FSMContext, store: dict):
    payload = command.args
    referred_by = None
    product_target = None

    if payload:
        if payload.startswith("ref_"):
            try:
                referred_by = int(payload.split("_")[1])
            except ValueError:
                pass
        elif payload.startswith("prod_"):
            product_target = payload.split("prod_")[1]

    register_buyer(
        store_id=store["id"],
        telegram_id=message.from_user.id,
        username=message.from_user.username,
        referred_by=referred_by
    )

    buyer = get_buyer(store["id"], message.from_user.id)
    buyer_name = (buyer or {}).get("name", "")

    if not buyer_name:
        await state.set_state(OnboardingState.waiting_name)
        await state.update_data(product_target=product_target)
        await message.answer(
            t("welcome_new", "ru", store=store["name"]),
            parse_mode="HTML",
        )
        return

    lang = get_lang(buyer)
    await _show_main(message, store, lang, product_target)


@router.message(OnboardingState.waiting_name, F.text)
async def onboarding_name_received(message: Message, state: FSMContext, store: dict):
    name = message.text.strip()
    if len(name) < 2:
        await message.answer(t("name_too_short", "ru"))
        return

    data = await state.get_data()
    await state.set_state(OnboardingState.waiting_language)
    await state.update_data(name=name, product_target=data.get("product_target"))

    save_buyer_name(store["id"], message.from_user.id, name)

    await message.answer(
        t("name_saved", "ru", name=name),
        parse_mode="HTML",
        reply_markup=language_kb(),
    )


@router.callback_query(F.data.startswith("lang:"))
async def language_selected(callback: CallbackQuery, state: FSMContext, store: dict):
    lang = callback.data.split(":")[1]  # "ru", "kk", or "en"
    save_buyer_language(store["id"], callback.from_user.id, lang)

    # Check if in onboarding or just changing language
    current_state = await state.get_state()
    product_target = None
    if current_state == OnboardingState.waiting_language:
        data = await state.get_data()
        product_target = data.get("product_target")
        await state.clear()

    await callback.message.answer(t("language_set", lang), parse_mode="HTML")
    await _show_main(callback.message, store, lang, product_target)
    await callback.answer()


@router.message(Command("language"))
async def change_language(message: Message):
    await message.answer(
        t("choose_language", "ru"),
        reply_markup=language_kb(),
    )


async def _show_main(message: Message, store: dict, lang: str, product_target: str = None):
    if product_target:
        from services.supabase_service import get_product_by_id
        from keyboards.buyer_kb import product_detail_kb
        p = get_product_by_id(product_target)
        if p and p.get("is_active"):
            caption = (
                f"🏷 <b>{p['name']}</b>\n"
                f"💰 {p['price']:,.0f} ₸\n\n"
                f"📝 {p.get('description', '')}"
            )
            await message.answer_photo(
                photo=p["photo_url"],
                caption=caption,
                parse_mode="HTML",
                reply_markup=product_detail_kb(p["id"], lang=lang)
            )
            return

    await message.answer(
        t("welcome_back", lang, store=store["name"]),
        reply_markup=main_menu_kb(
            lang=lang,
            is_premium=store.get("is_premium", False),
            is_vip=store.get("is_vip", False),
            store=store,
        ),
        parse_mode="HTML",
    )


@router.callback_query(F.data == "referral:get_link")
async def get_referral_link(callback: CallbackQuery, bot: Bot, store: dict):
    buyer = get_buyer(store["id"], callback.from_user.id)
    lang = get_lang(buyer)
    bot_me = await bot.get_me()
    ref_link = f"t.me/{bot_me.username}?start=ref_{callback.from_user.id}"
    await callback.message.answer(
        t("referral_text", lang, link=ref_link),
        parse_mode="HTML",
        reply_markup=buyer_cancel_kb(lang)
    )
    await callback.answer()


@router.callback_query(F.data == "nav:main_menu")
async def go_to_main_menu(callback: CallbackQuery, store: dict):
    buyer = get_buyer(store["id"], callback.from_user.id)
    lang = get_lang(buyer)
    await callback.message.answer(
        t("welcome_back", lang, store=store["name"]),
        reply_markup=main_menu_kb(
            lang=lang,
            is_premium=store.get("is_premium", False),
            is_vip=store.get("is_vip", False),
            store=store,
        ),
        parse_mode="HTML",
    )
    await callback.answer()
