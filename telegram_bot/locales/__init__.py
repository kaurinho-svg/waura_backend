"""
Localization helper for the Telegram bot.
Usage:
    from locales import t, get_lang
    text = t("welcome_new", lang, store="MyStore")
"""
from typing import Optional

from locales import ru, kk, en

_LOCALES = {
    "ru": ru.MESSAGES,
    "kk": kk.MESSAGES,
    "en": en.MESSAGES,
}

DEFAULT_LANG = "ru"


def t(key: str, lang: Optional[str] = None, **kwargs) -> str:
    """
    Returns the translated string for the given key and language.
    Falls back to Russian if key or lang is not found.
    Format kwargs are applied via str.format(**kwargs).
    """
    lang = lang if lang in _LOCALES else DEFAULT_LANG
    messages = _LOCALES[lang]
    text = messages.get(key) or _LOCALES[DEFAULT_LANG].get(key, key)
    if kwargs:
        try:
            text = text.format(**kwargs)
        except KeyError:
            pass
    return text


def get_lang(buyer: Optional[dict]) -> str:
    """Safely extracts the language from a buyer record. Defaults to 'ru'."""
    if not buyer:
        return DEFAULT_LANG
    lang = (buyer or {}).get("language", DEFAULT_LANG)
    return lang if lang in _LOCALES else DEFAULT_LANG
