import 'dart:io' show Platform;

/// Глобальные настройки приложения.
class AppConfig {
  /// Базовый адрес backend-сервера try-on.
  ///
  /// Для демо-версии:
  /// - backend запущен на компьютере
  /// - телефон в той же сети / на раздаче
  /// - сюда подставляем IPv4-адрес компьютера из `ipconfig`
  static String get tryOnBaseUrl {
    // TODO: поменять на свой IP
    // Пример: если ipconfig показывает 192.168.43.10:
    return 'http://192.168.43.10:8000';
  }
}




