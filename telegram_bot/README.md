# Waura Telegram Bot 🤖

**White-label** бот-платформа. Каждый магазин получает свой именной Telegram-бот.
Один сервер обслуживает все боты. Общая база данных Supabase с Flutter-приложением.

## Архитектура

```
@ShopABot ──┐
@ShopBBot ──┤──▶  bot.py (один процесс)  ──▶  Supabase (общая БД)
@ShopCBot ──┘             ↑
                  StoreContextMiddleware
              (каждый бот знает свой store_id)
```

## Структура

```
telegram_bot/
├── bot.py                    # Точка входа
├── config.py                 # Переменные окружения
├── requirements.txt
├── .env.example              # Шаблон .env
├── handlers/
│   ├── start.py              # /start, выбор роли
│   ├── shop.py               # Управление магазином
│   ├── catalog.py            # Каталог для покупателей
│   ├── tryon.py              # Виртуальная примерка
│   └── orders.py             # Оформление заказов
├── keyboards/
│   ├── shop_kb.py
│   └── buyer_kb.py
├── services/
│   ├── supabase_service.py   # Работа с БД
│   └── tryon_service.py      # Вызов FastAPI (fal.ai)
└── middleware/
    └── subscription.py       # Проверка подписки магазина
```

## Запуск локально

```bash
cd telegram_bot

# 1. Создать виртуальное окружение
python -m venv venv
venv\Scripts\activate       # Windows
# source venv/bin/activate  # Mac/Linux

# 2. Установить зависимости
pip install -r requirements.txt

# 3. Настроить .env
copy .env.example .env
# Заполните TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

# 4. Запустить
python bot.py
```

## Переменные окружения

| Переменная | Описание |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Токен от @BotFather |
| `SUPABASE_URL` | URL вашего Supabase проекта |
| `SUPABASE_SERVICE_ROLE_KEY` | Service Role ключ Supabase |
| `BACKEND_URL` | URL FastAPI бэкенда (по умолчанию waura-backend.onrender.com) |

## Supabase — необходимые таблицы

Выполните в SQL Editor вашего Supabase проекта:

```sql
-- Магазины
CREATE TABLE bot_stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_id bigint UNIQUE NOT NULL,  -- Telegram ID владельца
  bot_token text NOT NULL DEFAULT '',  -- Токен бота от @BotFather
  name text NOT NULL,
  kaspi_phone text DEFAULT '',         -- Номер для переводов
  kaspi_pay_url text DEFAULT '',       -- Ссылка Kaspi Pay для бизнеса
  payment_info text DEFAULT '',
  is_subscribed boolean DEFAULT false,
  subscription_until timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Товары
CREATE TABLE bot_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid REFERENCES bot_stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  price numeric NOT NULL,
  category text DEFAULT '',
  photo_url text DEFAULT '',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Размеры и наличие
CREATE TABLE bot_product_sizes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES bot_products(id) ON DELETE CASCADE,
  size text NOT NULL,
  quantity int DEFAULT 0
);

-- Заказы
CREATE TABLE bot_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES bot_products(id),
  buyer_telegram_id bigint NOT NULL,
  size text DEFAULT '',
  status text DEFAULT 'pending',
  payment_screenshot_id text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- Покупатели (для рассылки)
CREATE TABLE bot_buyers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid REFERENCES bot_stores(id) ON DELETE CASCADE,
  telegram_id bigint NOT NULL,
  username text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  UNIQUE(store_id, telegram_id)
);
```

## Подключить новый магазин

1. Магазин создаёт бота в @BotFather → получает токен
2. Вы добавляете запись в Supabase:
```sql
INSERT INTO bot_stores (telegram_id, bot_token, name, kaspi_phone)
VALUES (123456789, 'токен_от_botfather', 'Название магазина', '+7 701 123 45 67');
```
3. Перезапустить `python bot.py` — новый бот поднимется автоматически

> 💡 **Владелец магазина управляет товарами** через команду `/admin` в своём боте.
> Только его Telegram ID (telegram_id в БД) имеет доступ к панели администратора.
