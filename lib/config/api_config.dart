import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  // Android emulator localhost на ПК доступен как 10.0.2.2
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000';

  // Desktop / Web (локально)
  static const String desktopBaseUrl = 'http://127.0.0.1:8000';

  // Дефолт для телефона (первый запуск).
  // Дальше пользователь меняет через настройки (ApiRuntime).
  static const String mobileDefaultBaseUrl = 'http://192.168.0.112:8000';

  static String get defaultBaseUrl {
    if (kIsWeb) return desktopBaseUrl;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return desktopBaseUrl;
    }

    if (Platform.isAndroid) return mobileDefaultBaseUrl;
    if (Platform.isIOS) return mobileDefaultBaseUrl;

    return desktopBaseUrl;
  }
}
