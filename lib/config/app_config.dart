import 'api_runtime.dart';

class AppConfig {
  /// Базовый URL бэкенда (без хвостового /)
  /// Пример: http://192.168.0.112:8000
  static String get backendBaseUrl => ApiRuntime.baseUrl;

  /// Префикс API как в FastAPI settings.API_PREFIX
  /// Для nano-banana / remove-bg
  static const String apiPrefix = "/api/v1";

  /// Полная база API: http://IP:8000/api/v1
  static String get apiBase => "$backendBaseUrl$apiPrefix";

  /// База для SEARCH (у тебя эндпоинты /search/... без /api/v1)
  /// Пример: http://IP:8000
  static String get searchBase => backendBaseUrl;
}
