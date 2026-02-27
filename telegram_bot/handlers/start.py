from aiogram import Router, F, Bot
from aiogram.filters import CommandStart, CommandObject
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder

from services.buyer_service import register_buyer, get_buyer, save_buyer_name

router = Router()


class OnboardingState(StatesGroup):
    waiting_name = State()


def main_menu_kb(is_premium: bool = False, is_vip: bool = False):
    builder = InlineKeyboardBuilder()
    builder.button(text="🛍 Каталог", callback_data="catalog:start")
    builder.button(text="📂 По категориям", callback_data="catalog:categories")
    if is_premium:
        builder.button(text="✨ AI-Стилист 💎", callback_data="stylist:start")
    if is_vip:
        builder.button(text="🎁 Получить скидку 50%", callback_data="referral:get_link")
    builder.adjust(2, 1)
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

    # Register buyer
    register_buyer(
        store_id=store["id"],
        telegram_id=message.from_user.id,
        username=message.from_user.username,
        referred_by=referred_by
    )

    # Check if buyer has a name saved already
    buyer = get_buyer(store["id"], message.from_user.id)
    buyer_name = (buyer or {}).get("name", "")

    if not buyer_name:
        # First time — ask for name
        await state.set_state(OnboardingState.waiting_name)
        await state.update_data(product_target=product_target)
        await message.answer(
            f"👋 Добро пожаловать в <b>{store['name']}</b>!\n\n"
            "Прежде чем начать, пожалуйста, напишите своё <b>имя</b> "
            "(оно будет видно продавцу при оформлении заказа):",
            parse_mode="HTML",
        )
        return

    # Buyer has a name — show menu directly
    await _show_main(message, store, product_target)


@router.message(OnboardingState.waiting_name, F.text)
async def onboarding_name_received(message: Message, state: FSMContext, store: dict):
    name = message.text.strip()
    if len(name) < 2:
        await message.answer("Пожалуйста, введите настоящее имя (минимум 2 символа).")
        return

    data = await state.get_data()
    product_target = data.get("product_target")
    await state.clear()

    save_buyer_name(store["id"], message.from_user.id, name)

    await message.answer(f"✅ Приятно познакомиться, <b>{name}</b>!", parse_mode="HTML")
    await _show_main(message, store, product_target)


async def _show_main(message: Message, store: dict, product_target: str = None):
    """Shows main menu or direct product if product_target is set."""
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
                reply_markup=product_detail_kb(p["id"])
            )
            return

    await message.answer(
        f"🛍 <b>{store['name']}</b> — что вас интересует?",
        reply_markup=main_menu_kb(
            is_premium=store.get("is_premium", False),
            is_vip=store.get("is_vip", False)
        ),
        parse_mode="HTML",
    )


# Handle referral link generation
@router.callback_query(F.data == "referral:get_link")
async def get_referral_link(callback: CallbackQuery, bot: Bot):
    bot_me = await bot.get_me()
    bot_username = bot_me.username
    user_id = callback.from_user.id
    ref_link = f"t.me/{bot_username}?start=ref_{user_id}"

    from keyboards.buyer_kb import buyer_cancel_kb
    await callback.message.answer(
        f"🎉 <b>Скидка 50% для вас и ваших друзей!</b>\n\n"
        f"Отправьте другу (или подруге) эту ссылку:\n<code>{ref_link}</code>\n\n"
        f"Как только приглашенный вами человек сделает первый заказ, вам автоматически придет персональный промокод на скидку 50%! 🎁",
        parse_mode="HTML",
        reply_markup=buyer_cancel_kb()
    )
    await callback.answer()


# Handle "Main Menu" nav button from anywhere in the bot
@router.callback_query(F.data == "nav:main_menu")
async def go_to_main_menu(callback: CallbackQuery, store: dict):
    await callback.message.answer(
        f"🏠 <b>Главное меню</b>",
        reply_markup=main_menu_kb(
            is_premium=store.get("is_premium", False),
            is_vip=store.get("is_vip", False)
        ),
        parse_mode="HTML",
    )
    await callback.answer()
