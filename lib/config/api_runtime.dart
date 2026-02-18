// lib/config/api_runtime.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiRuntime {
  static const _kKey = 'api_base_url';

  static late SharedPreferences _prefs;

  static String _baseUrl = ApiConfig.defaultBaseUrl;

  /// Текущий URL, который используют ВСЕ запросы приложения
  static String get baseUrl => _baseUrl;

  /// Дефолтный URL (для первого запуска), зависит от платформы
  static String get defaultBaseUrl => ApiConfig.defaultBaseUrl;

  /// Инициализация при старте приложения
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _baseUrl = _prefs.getString(_kKey) ?? ApiConfig.defaultBaseUrl;
  }

  /// Сохранить новый URL из настроек
  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim();
    await _prefs.setString(_kKey, _baseUrl);
  }

  static Future<void> resetToDefault() async {
    await setBaseUrl(ApiConfig.defaultBaseUrl);
  }
}
