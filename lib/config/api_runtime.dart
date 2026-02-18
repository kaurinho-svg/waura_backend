// lib/config/api_runtime.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiRuntime {
  // Теперь просто проксируем статический URL из конфига
  static String get baseUrl => ApiConfig.defaultBaseUrl;

  // Метод init больше ничего не делает, но оставим пустым, чтобы не ломать main.dart сразу
  static Future<void> init() async {}

  // Методы для смены URL больше не нужны, но можно оставить заглушки или удалить
  static Future<void> setBaseUrl(String url) async {}
  static Future<void> resetToDefault() async {}
}
