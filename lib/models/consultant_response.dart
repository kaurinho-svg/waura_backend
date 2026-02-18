import '../models/clothing_item.dart';

/// Ответ от консультанта с рекомендациями
class ConsultantResponse {
  final String text;
  final List<ClothingItem> products;
  final List<Map<String, dynamic>> images; // [NEW] Visual suggestions
  final String source; // 'rule-based', 'gemini-api', 'fallback', 'error'
  final DateTime timestamp;

  ConsultantResponse({
    required this.text,
    this.products = const [],
    this.images = const [],
    required this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Создать ответ на основе правил
  factory ConsultantResponse.ruleBased({
    required String text,
    List<ClothingItem> products = const [],
  }) {
    return ConsultantResponse(
      text: text,
      products: products,
      source: 'rule-based',
    );
  }

  /// Создать ответ от Gemini API
  factory ConsultantResponse.gemini({
    required String text,
    List<ClothingItem> products = const [],
    List<Map<String, dynamic>> images = const [],
  }) {
    return ConsultantResponse(
      text: text,
      products: products,
      images: images,
      source: 'gemini-api',
    );
  }

  /// Создать fallback ответ (нет интернета)
  factory ConsultantResponse.fallback(String text) {
    return ConsultantResponse(
      text: text,
      products: [],
      images: [],
      source: 'fallback',
    );
  }

  /// Создать ответ об ошибке
  factory ConsultantResponse.error(String errorMessage) {
    return ConsultantResponse(
      text: 'Извините, произошла ошибка: $errorMessage\n\nПопробуйте задать вопрос по-другому.',
      products: [],
      source: 'error',
    );
  }

  /// Получить иконку источника для UI
  String get sourceIcon {
    switch (source) {
      case 'rule-based':
        return '⚡';
      case 'gemini-api':
        return '🤖';
      case 'fallback':
        return '📴';
      case 'error':
        return '⚠️';
      default:
        return '💬';
    }
  }

  /// Получить описание источника
  String get sourceDescription {
    switch (source) {
      case 'rule-based':
        return 'Быстрый ответ';
      case 'gemini-api':
        return 'Gemini AI';
      case 'fallback':
        return 'Оффлайн режим';
      case 'error':
        return 'Ошибка';
      default:
        return '';
    }
  }

  /// Есть ли рекомендации товаров
  bool get hasProducts => products.isNotEmpty;

  @override
  String toString() {
    return 'ConsultantResponse(source: $source, products: ${products.length})';
  }
}
