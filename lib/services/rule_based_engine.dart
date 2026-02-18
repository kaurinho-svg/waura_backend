import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clothing_item.dart';
import '../models/consultant_response.dart';
import '../providers/catalog_provider.dart';
import '../providers/marketplace_provider.dart';

/// Движок на основе правил для быстрых ответов
class RuleBasedEngine {
  final BuildContext context;

  RuleBasedEngine(this.context);

  /// Попытаться ответить на вопрос с помощью правил
  ConsultantResponse? tryAnswer(String query, {String gender = 'unknown'}) {
    final lowerQuery = query.toLowerCase().trim();

    // Правило 1: Случаи (occasions)
    if (_matchesOccasion(lowerQuery, ['работа', 'офис', 'деловая'])) {
      return _businessOutfit(gender);
    }
    if (_matchesOccasion(lowerQuery, ['свидание', 'романтик', 'date'])) {
      return _romanticOutfit(gender);
    }
    if (_matchesOccasion(lowerQuery, ['вечеринка', 'клуб', 'party', 'тусовка'])) {
      return _partyOutfit(gender);
    }
    if (_matchesOccasion(lowerQuery, ['спорт', 'тренировка', 'зал', 'фитнес'])) {
      return _sportOutfit(gender);
    }
    if (_matchesOccasion(lowerQuery, ['повседневный', 'casual', 'прогулка', 'каждый день'])) {
      return _casualOutfit(gender);
    }

    // Правило 2: Предметы одежды
    if (_matchesItem(lowerQuery, ['куртка', 'пальто', 'верхняя одежда'])) {
      return _showOuterwear();
    }
    if (_matchesItem(lowerQuery, ['платье'])) {
      return _showDresses();
    }
    if (_matchesItem(lowerQuery, ['джинсы', 'брюки', 'штаны'])) {
      return _showPants();
    }
    if (_matchesItem(lowerQuery, ['рубашка', 'футболка', 'топ'])) {
      return _showTops();
    }

    // Правило 3: Сезоны
    if (_matchesSeason(lowerQuery, ['весна', 'весенний', 'весеннюю'])) {
      return _springClothes(gender);
    }
    if (_matchesSeason(lowerQuery, ['лето', 'летний', 'летнюю', 'летом'])) {
      return _summerClothes(gender);
    }
    if (_matchesSeason(lowerQuery, ['осень', 'осенний', 'осеннюю'])) {
      return _autumnClothes(gender);
    }
    if (_matchesSeason(lowerQuery, ['зима', 'зимний', 'зимнюю', 'зимой'])) {
      return _winterClothes(gender);
    }


    // Правило 4: Анализ гардероба
    if (_matchesAnalysis(lowerQuery, ['не хватает', 'купить', 'дополнить', 'нужно'])) {
      return _analyzeWardrobe();
    }
    if (_matchesAnalysis(lowerQuery, ['мой гардероб', 'что у меня', 'мои вещи'])) {
      return _showWardrobe();
    }

    // Правило 5: Приветствия и помощь
    if (_matchesGreeting(lowerQuery, ['привет', 'здравствуй', 'добрый', 'hi', 'hello'])) {
      return _greetingResponse();
    }
    if (_matchesHelp(lowerQuery, ['помощь', 'помоги', 'что ты умеешь', 'как работаешь', 'что можешь'])) {
      return _helpResponse();
    }

    // Не нашли подходящего правила
    return null;
  }

  bool _matchesGreeting(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  bool _matchesHelp(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  bool _matchesOccasion(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  bool _matchesItem(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  bool _matchesSeason(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  bool _matchesAnalysis(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  // === Ответы для случаев ===

  ConsultantResponse _businessOutfit(String gender) {
    final wardrobe = _getWardrobe();
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '👔 Для работы рекомендую деловой стиль:\n\n';

    if (isMale) {
      if (wardrobe.any((i) => i.category == 'Пиджаки')) {
         response += '✓ У вас есть пиджак - отлично!\n';
         response += 'Добавьте классическую рубашку и брюки.\n\n';
      } else {
         response += 'Базовый мужской гардероб:\n';
         response += '• Костюм (синий/серый)\n';
         response += '• Рубашка (белая/голубая)\n';
         response += '• Туфли оксфорды\n\n';
      }
    } else {
      final hasShirt = wardrobe.any((i) => i.category == 'Рубашки');
      final hasPants = wardrobe.any((i) => i.category == 'Брюки');
      
      if (hasShirt && hasPants) {
        response += '✓ У вас есть рубашка и брюки - отличная основа!\n';
        response += 'Рекомендую добавить жакет для завершения образа.\n\n';
      } else {
        response += 'Базовый деловой гардероб:\n';
        response += '• Рубашка или блузка\n';
        response += '• Брюки или юбка-карандаш\n';
        response += '• Жакет\n\n';
      }
    }

    final products = marketplace
        .where((p) => ['Рубашки', 'Брюки', 'Пиджаки', 'Костюмы'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Подходящие товары из маркетплейса:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _romanticOutfit(String gender) {
    final wardrobe = _getWardrobe();
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '💕 Для свидания рекомендую романтичный образ:\n\n';

    if (isMale) {
      if (wardrobe.any((i) => i.category == 'Рубашки')) {
         response += '✓ У вас есть рубашка - отлично для свидания!\n';
         response += 'Добавьте чиносы или темные джинсы.\n\n';
      } else {
         response += 'Стильный мужской образ:\n';
         response += '• Рубашка (белая или в клетку)\n';
         response += '• Пиджак casual\n';
         response += '• Чиносы или джинсы\n\n';
      }
    } else {
      final hasDress = wardrobe.any((i) => i.category == 'Платья');
      if (hasDress) {
        response += '✓ У вас есть платье - идеально для свидания!\n';
        response += 'Дополните образ аксессуарами.\n\n';
      } else {
        response += 'Романтичные варианты:\n';
        response += '• Платье (нежные цвета)\n';
        response += '• Блузка + юбка\n';
        response += '• Красивый топ + джинсы\n\n';
      }
    }

    final products = marketplace
        .where((p) => ['Платья', 'Блузки', 'Юбки', 'Рубашки', 'Пиджаки'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Подходящие товары:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _partyOutfit(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '🎉 Для вечеринки рекомендую яркий образ:\n\n';
    
    if (isMale) {
      response += '• Стильная футболка или рубашка с принтом\n';
      response += '• Джинсы или брюки casual\n';
      response += '• Кроссовки или лоферы\n\n';
    } else {
      response += '• Стильное платье или костюм\n';
      response += '• Яркие цвета или блестки\n';
      response += '• Удобная обувь для танцев\n\n';
    }

    final products = marketplace
        .where((p) => ['Платья', 'Костюмы', 'Футболки'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Вечерние варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _sportOutfit(String gender) {
    final marketplace = _getMarketplace();

    String response = '💪 Для тренировок нужна спортивная одежда:\n\n';
    response += '• Спортивная футболка/топ\n';
    response += '• Спортивные штаны или шорты\n';
    response += '• Кроссовки\n\n';

    final products = marketplace
        .where((p) => p.category == 'Спортивная одежда')
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Спортивные товары:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _casualOutfit(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '👕 Повседневный casual стиль:\n\n';
    
    if (isMale) {
      response += '• Футболка, поло или худи\n';
      response += '• Джинсы или карго\n';
      response += '• Брутальные ботинки или кроссовки\n\n';
    } else {
      response += '• Футболка или свитшот\n';
      response += '• Джинсы\n';
      response += '• Кроссовки или кеды\n\n';
    }

    final products = marketplace
        .where((p) => ['Футболки', 'Джинсы', 'Кроссовки'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Casual варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  // === Ответы для предметов ===

  ConsultantResponse _showOuterwear() {
    final marketplace = _getMarketplace();

    String response = '🧥 Верхняя одежда:\n\n';

    final products = marketplace
        .where((p) => ['Куртки', 'Пальто'].contains(p.category))
        .take(5)
        .toList();

    if (products.isEmpty) {
      response += 'К сожалению, сейчас нет доступных курток в маркетплейсе.';
    } else {
      response += 'Доступные варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _showDresses() {
    final marketplace = _getMarketplace();

    String response = '👗 Платья:\n\n';

    final products = marketplace
        .where((p) => p.category == 'Платья')
        .take(5)
        .toList();

    if (products.isEmpty) {
      response += 'К сожалению, сейчас нет доступных платьев в маркетплейсе.';
    } else {
      response += 'Доступные платья:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _showPants() {
    final marketplace = _getMarketplace();

    String response = '👖 Брюки и джинсы:\n\n';

    final products = marketplace
        .where((p) => ['Брюки', 'Джинсы'].contains(p.category))
        .take(5)
        .toList();

    if (products.isEmpty) {
      response += 'К сожалению, сейчас нет доступных брюк в маркетплейсе.';
    } else {
      response += 'Доступные варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _showTops() {
    final marketplace = _getMarketplace();

    String response = '👕 Верх:\n\n';

    final products = marketplace
        .where((p) => ['Рубашки', 'Футболки', 'Блузки'].contains(p.category))
        .take(5)
        .toList();

    if (products.isEmpty) {
      response += 'К сожалению, сейчас нет доступных вещей в маркетплейсе.';
    } else {
      response += 'Доступные варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  // === Ответы для сезонов ===

  ConsultantResponse _springClothes(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '🌸 Для весны рекомендую:\n\n';
    
    if (isMale) {
      response += '• Легкая куртка (бомбер или джинсовка)\n';
      response += '• Джинсы или чиносы\n';
      response += '• Свитшот или худи\n';
      response += '• Кроссовки\n\n';
    } else {
      response += '• Легкая куртка или тренч\n';
      response += '• Джинсы или брюки\n';
      response += '• Блузка или свитшот\n';
      response += '• Ботильоны или кеды\n\n';
    }

    final products = marketplace
        .where((p) => ['Куртки', 'Ветровки', 'Рубашки', 'Джинсы', 'Толстовки'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Весенние варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _summerClothes(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '☀️ Для лета рекомендую:\n\n';
    
    if (isMale) {
      response += '• Футболки (базовые и с принтом)\n';
      response += '• Шорты (джинсовые или хлопок)\n';
      response += '• Сланцы или легкие кеды\n\n';
    } else {
      response += '• Легкие топы и футболки\n';
      response += '• Шорты или юбки\n';
      response += '• Летние платья и сарафаны\n';
      response += '• Сандалии\n\n';
    }

    final products = marketplace
        .where((p) => ['Футболки', 'Шорты', 'Платья', 'Сандалии'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Летние варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _autumnClothes(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '🍂 Для осени рекомендую:\n\n';
    
    if (isMale) {
      response += '• Парка или кожаная куртка\n';
      response += '• Плотные джинсы\n';
      response += '• Свитер или толстовка\n';
      response += '• Ботинки\n\n';
    } else {
      response += '• Пальто или тренч\n';
      response += '• Джинсы или теплые брюки\n';
      response += '• Уютный свитер или кардиган\n';
      response += '• Сапоги или ботинки\n\n';
    }

    final products = marketplace
        .where((p) => ['Куртки', 'Свитера', 'Кардиганы', 'Пальто'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Осенние варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  ConsultantResponse _winterClothes(String gender) {
    final marketplace = _getMarketplace();
    final isMale = gender.toLowerCase() == 'male';

    String response = '❄️ Для зимы нужна теплая одежда:\n\n';
    
    if (isMale) {
      response += '• Пуховик или зимняя парка\n';
      response += '• Теплый свитер крупной вязки\n';
      response += '• Зимние ботинки\n';
      response += '• Шапка и шарф\n\n';
    } else {
      response += '• Пуховик или шуба\n';
      response += '• Теплый свитер или платье-свитер\n';
      response += '• Утепленные брюки\n';
      response += '• Зимние сапоги\n\n';
    }

    final products = marketplace
        .where((p) => ['Пуховики', 'Пальто', 'Свитера'].contains(p.category))
        .take(3)
        .toList();

    if (products.isNotEmpty) {
      response += 'Зимние варианты:';
    }

    return ConsultantResponse.ruleBased(text: response, products: products);
  }

  // === Анализ гардероба ===

  ConsultantResponse _analyzeWardrobe() {
    final wardrobe = _getWardrobe();

    if (wardrobe.isEmpty) {
      return ConsultantResponse.ruleBased(
        text: '📊 Ваш гардероб пуст.\n\nРекомендую начать с базовых вещей:\n'
            '• Футболки (2-3 шт)\n'
            '• Джинсы (1-2 пары)\n'
            '• Рубашка\n'
            '• Куртка',
      );
    }

    final categories = <String, int>{};
    for (final item in wardrobe) {
      categories[item.category] = (categories[item.category] ?? 0) + 1;
    }

    String response = '📊 Анализ вашего гардероба:\n\n';
    response += 'У вас есть:\n';
    categories.forEach((category, count) {
      response += '✓ $category: $count шт\n';
    });

    response += '\nРекомендации:\n';
    if (!categories.containsKey('Рубашки')) {
      response += '• Добавьте рубашку для деловых встреч\n';
    }
    if (!categories.containsKey('Куртки')) {
      response += '• Нужна куртка для холодной погоды\n';
    }
    if (!categories.containsKey('Джинсы')) {
      response += '• Джинсы - универсальная вещь\n';
    }

    return ConsultantResponse.ruleBased(text: response);
  }

  ConsultantResponse _showWardrobe() {
    final wardrobe = _getWardrobe();

    if (wardrobe.isEmpty) {
      return ConsultantResponse.ruleBased(
        text: '👔 Ваш гардероб пуст.\n\nДобавьте вещи в каталог, чтобы я мог помочь вам создавать образы!',
      );
    }

    String response = '👔 Ваш гардероб:\n\n';
    final categories = <String, List<ClothingItem>>{};
    
    for (final item in wardrobe) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    categories.forEach((category, items) {
      response += '$category (${items.length}):\n';
      for (final item in items.take(3)) {
        response += '  • ${item.name}\n';
      }
      if (items.length > 3) {
        response += '  ... и еще ${items.length - 3}\n';
      }
      response += '\n';
    });

    return ConsultantResponse.ruleBased(text: response);
  }

  // === Приветствия и помощь ===

  ConsultantResponse _greetingResponse() {
    return ConsultantResponse.ruleBased(
      text: '👋 Привет! Я ваш AI-консультант по стилю.\n\n'
          'Я помогу вам:\n'
          '• Подобрать образ для любого случая\n'
          '• Найти нужные вещи в маркетплейсе\n'
          '• Проанализировать ваш гардероб\n\n'
          'Задайте вопрос или выберите быстрый вариант ниже! 👇',
    );
  }

  ConsultantResponse _helpResponse() {
    return ConsultantResponse.ruleBased(
      text: '🤖 Я умею помогать со стилем!\n\n'
          'Вот что я могу:\n\n'
          '📋 Случаи:\n'
          '• Работа/офис\n'
          '• Свидание\n'
          '• Вечеринка\n'
          '• Спорт\n'
          '• Повседневный стиль\n\n'
          '👕 Поиск одежды:\n'
          '• Куртки, платья, джинсы\n'
          '• Рубашки, футболки\n\n'
          '🌸 Сезоны:\n'
          '• Весенняя одежда\n'
          '• Летняя одежда\n'
          '• Осенняя одежда\n'
          '• Зимняя одежда\n\n'
          '📊 Анализ:\n'
          '• Чего не хватает в гардеробе\n'
          '• Показать мой гардероб\n\n'
          'Просто спросите! Например: "Что надеть на работу?"',
    );
  }

  // === Вспомогательные методы ===

  List<ClothingItem> _getWardrobe() {
    try {
      final catalog = context.read<CatalogProvider>();
      return catalog.items;
    } catch (e) {
      return [];
    }
  }

  List<ClothingItem> _getMarketplace() {
    try {
      final marketplace = context.read<MarketplaceProvider>();
      return marketplace.allProducts;
    } catch (e) {
      return [];
    }
  }
}
