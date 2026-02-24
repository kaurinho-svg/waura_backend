"""
Broadcast handler: shop owner sends /broadcast to message all their buyers.
"""
import asyncio
from aiogram import Router, Bot
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import Message

from services.buyer_service import get_buyers_for_store
from keyboards.shop_kb import cancel_kb, shop_main_menu

router = Router()


class BroadcastState(StatesGroup):
    waiting_message = State()


def is_owner(telegram_id: int, store: dict) -> bool:
    if store.get("telegram_id") == telegram_id:
        return True
    extra_admins = store.get("admin_ids") or []
    return telegram_id in extra_admins


@router.message(Command("broadcast"))
async def broadcast_start(message: Message, state: FSMContext, store: dict):
    if not is_owner(message.from_user.id, store):
        await message.answer("⛔️ Только владелец магазина может делать рассылку.")
        return

    buyers = get_buyers_for_store(store["id"])
    if not buyers:
        await message.answer(
            "😔 Пока нет покупателей для рассылки.\n\n"
            "Покупатели добавляются в базу автоматически когда пишут вашему боту."
        )
        return

    await state.set_state(BroadcastState.waiting_message)
    await message.answer(
        f"📣 <b>Рассылка</b>\n\n"
        f"Сообщение получат <b>{len(buyers)}</b> покупателей.\n\n"
        f"Отправьте текст, фото или видео для рассылки:",
        parse_mode="HTML",
        reply_markup=cancel_kb(),
    )


@router.message(BroadcastState.waiting_message)
async def broadcast_send(message: Message, state: FSMContext, store: dict, bot: Bot):
    await state.clear()

    buyers = get_buyers_for_store(store["id"])
    if not buyers:
        await message.answer("😔 Нет покупателей для рассылки.")
        return

    sent = 0
    failed = 0

    status_msg = await message.answer(f"⏳ Отправляю {len(buyers)} покупателям...")

    for buyer_id in buyers:
        try:
            if message.photo:
                await bot.send_photo(
                    chat_id=buyer_id,
                    photo=message.photo[-1].file_id,
                    caption=message.caption or "",
                    parse_mode="HTML",
                )
            elif message.video:
                await bot.send_video(
                    chat_id=buyer_id,
                    video=message.video.file_id,
                    caption=message.caption or "",
                    parse_mode="HTML",
                )
            else:
                await bot.send_message(
                    chat_id=buyer_id,
                    text=message.text or "",
                    parse_mode="HTML",
                )
            sent += 1
        except Exception:
            failed += 1

        # Telegram rate limit: max 30 msg/sec
        await asyncio.sleep(0.05)

    await status_msg.edit_text(
        f"✅ Рассылка завершена!\n\n"
        f"📨 Отправлено: {sent}\n"
        f"❌ Не доставлено: {failed}",
    )

