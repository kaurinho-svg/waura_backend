from aiogram import Router, F
from aiogram.filters import CommandStart
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder

from services.buyer_service import register_buyer

router = Router()


def main_menu_kb():
    builder = InlineKeyboardBuilder()
    builder.button(text="🛍 Каталог", callback_data="catalog:start")
    builder.button(text="📂 По категориям", callback_data="catalog:categories")
    builder.adjust(2)
    return builder.as_markup()


@router.message(CommandStart())
async def cmd_start(message: Message, store: dict):
    # Register buyer for broadcast feature
    register_buyer(
        store_id=store["id"],
        telegram_id=message.from_user.id,
        username=message.from_user.username,
    )

    await message.answer(
        f"👋 Добро пожаловать в <b>{store['name']}</b>!\n\n"
        f"Здесь вы можете просмотреть каталог одежды, примерить понравившиеся вещи и сделать заказ.\n\n"
        f"Выберите действие:",
        reply_markup=main_menu_kb(),
        parse_mode="HTML",
    )
