import 'backend_api_service.dart';
import '../models/clothing_item.dart';
import '../models/consultant_response.dart';

import '../models/consultant_message.dart';

/// Сервис для работы с AI консультантом через backend
class GeminiService {
  late BackendApiService _api;
  bool _isInitialized = false;

  /// Инициализация сервиса
  Future<void> initialize() async {
    try {
      _api = BackendApiService();
      
      // Проверить доступность backend
      final isAvailable = await _api.checkStatus();
      
      if (isAvailable) {
        _isInitialized = true;
        print('✅ Backend API initialized successfully');
      } else {
        print('⚠️ Backend API not available');
        _isInitialized = false;
        _lastError = "Status check failed";
      }
    } catch (e) {
      print('❌ Failed to initialize Backend API: $e');
      _isInitialized = false;
      _lastError = e.toString();
    }
  }

  /// Проверка, инициализирован ли сервис
  bool get isAvailable => _isInitialized;
  String? _lastError; // [NEW]

  /// Задать вопрос консультанту
  Future<ConsultantResponse> ask({
    required String query,
    required List<ClothingItem> wardrobe,
    required List<ClothingItem> marketplace,
    required String gender,
    required String language,
    List<ConsultantMessage> history = const [],
  }) async {
    if (!_isInitialized) {
      // Пытаемся инициализировать снова (если сервер проснулся)
      await initialize();
      if (!_isInitialized) {
        return ConsultantResponse.fallback(
          'Backend сервер недоступен.\n'
          'Ошибка: ${_lastError ?? "Неизвестно"}\n\n'
          'Попробуйте еще раз через минуту.',
        );
      }
    }

    return await _api.askConsultant(
      query: query,
      wardrobe: wardrobe,
      marketplace: marketplace,
      gender: gender,
      language: language,
      history: history.map((m) => m.toMap()).toList(),
    );
  }
  
  /// Задать вопрос консультанту с изображением
  Future<ConsultantResponse> askWithImage({
    required String query,
    required String imagePath,
    required List<ClothingItem> wardrobe,
    required List<ClothingItem> marketplace,
    required String gender,
    required String language,
    List<ConsultantMessage> history = const [],
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        return ConsultantResponse.fallback(
          'Backend сервер недоступен.\n'
          'Ошибка: ${_lastError ?? "Неизвестно"}',
        );
      }
    }

    return await _api.askConsultantWithImage(
      query: query,
      imagePath: imagePath,
      wardrobe: wardrobe,
      marketplace: marketplace,
      gender: gender,
      language: language,
      history: history.map((m) => m.toMap()).toList(),
    );
  }
}
