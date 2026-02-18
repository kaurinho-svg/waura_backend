import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  // ✅ CLOUD BACKEND (Render.com)
  static const String cloudUrl = 'https://waura-backend.onrender.com';

  // Локальные адреса (для разработки)
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String desktopBaseUrl = 'http://127.0.0.1:8000';

  // Теперь по умолчанию для всех платформ используем Облако
  static const String mobileDefaultBaseUrl = cloudUrl;

  static String get defaultBaseUrl {
    // Теперь везде используем облако, чтобы работало "из коробки"
    return cloudUrl;
  }
}
