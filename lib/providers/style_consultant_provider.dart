import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/consultant_message.dart';
import '../models/consultant_response.dart';
import '../services/rule_based_engine.dart';
import '../services/gemini_service.dart';
import '../providers/catalog_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';


/// Provider для управления AI-консультантом по стилю
class StyleConsultantProvider with ChangeNotifier {
  final List<ConsultantMessage> _messages = [];
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _initError; // [NEW] Track initialization error

  List<ConsultantMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasMessages => _messages.isNotEmpty;
  String? get initError => _initError;

  /// Инициализация провайдера
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Add welcome message immediately so user sees something
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
    
    // Mark as initialized immediately to show UI
    _isInitialized = true;
    notifyListeners();

    try {
      _initError = null;
      _isLoading = true; // Show loading indicator in chat while connecting
      notifyListeners();

      // Инициализируем Gemini API (Check Status)
      await _geminiService.initialize();
      
      // Check if service actually became available
      if (!_geminiService.isAvailable) {
         _initError = "Backend connection failed";
         _messages.add(ConsultantMessage.assistant(
           "⚠️ Backend is sleeping or unavailable. I can still answer, but might be slow or use fallback logic.",
           source: 'system'
         ));
      }
    } catch (e) {
      _initError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Добавить приветственное сообщение
  void _addWelcomeMessage() {
    // Import AppLocalizations extension if not imported
    // Assuming context.tr works via global extension or imported
    // For system messages, we can store the English text as fallback, 
    // but the UI will override it with the localized version based on 'source'.
    final welcomeText = '👋 Hello! I am your AI Style Consultant.';

    _messages.add(ConsultantMessage.assistant(welcomeText, source: 'system'));
  }

  /// Задать вопрос консультанту
  Future<void> askQuestion(String query, BuildContext context) async {
    if (query.trim().isEmpty) return;

    // Добавляем вопрос пользователя
    final userMessage = ConsultantMessage.user(query);
    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    try {
      // Получаем ответ
      final response = await _getResponse(query, context);

      // Извлекаем ID рекомендованных товаров
      final productIds = response.products.map((p) => p.id).toList();

      // Добавляем ответ консультанта с рекомендациями
      final assistantMessage = ConsultantMessage.assistant(
        _formatResponse(response),
        source: response.source,
        recommendedProducts: productIds,
        generatedImages: response.images,
      );
      _messages.add(assistantMessage);
    } catch (e) {
      // Добавляем сообщение об ошибке
      final errorMessage = ConsultantMessage.assistant(
        'Извините, произошла ошибка: $e\n\nПопробуйте задать вопрос по-другому.',
        source: 'error',
      );
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Задать вопрос с изображением
  Future<void> askQuestionWithImage(String query, String imagePath, BuildContext context) async {
    // Добавляем вопрос пользователя с изображением
    final userMessage = ConsultantMessage.user(
      query.isEmpty ? 'What do you think about this?' : query,
      imagePath: imagePath,
    );
    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    try {
      // Получаем ответ с учетом изображения
      final catalog = context.read<CatalogProvider>();
      final marketplace = context.read<MarketplaceProvider>();
      final auth = context.read<AuthProvider>();
      final gender = auth.user?.gender.name ?? 'unknown';
      final localeProvider = context.read<LocaleProvider>();
      final language = localeProvider.locale.languageCode;

      final response = await _geminiService.askWithImage(
        query: query.isEmpty ? 'What do you think about this outfit? Give me style advice.' : query,
        imagePath: imagePath,
        wardrobe: catalog.items,
        marketplace: marketplace.allProducts,
        gender: gender,
        language: language,
        history: _messages,
      );

      // Извлекаем ID рекомендованных товаров
      final productIds = response.products.map((p) => p.id).toList();

      // Добавляем ответ консультанта
      final assistantMessage = ConsultantMessage.assistant(
        _formatResponse(response),
        source: response.source,
        recommendedProducts: productIds,
        generatedImages: response.images,
      );
      _messages.add(assistantMessage);
    } catch (e) {
      // Добавляем сообщение об ошибке
      final errorMessage = ConsultantMessage.assistant(
        'Sorry, an error occurred: $e\n\nPlease try again.',
        source: 'error',
      );
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Получить ответ от консультанта
  Future<ConsultantResponse> _getResponse(
    String query,
    BuildContext context,
  ) async {
    // 1. Проверить доступность Gemini API
    if (!_geminiService.isAvailable) {
      return ConsultantResponse.fallback(
        'Для сложных вопросов нужен Gemini API.\n\n'
        'Попробуйте простые вопросы:\n'
        '• "Что надеть на работу?"\n'
        '• "Покажи куртки"\n'
        '• "Чего не хватает в гардеробе?"',
      );
    }

    // 3. Использовать Gemini API (умно, требует интернет)
    try {
      final catalog = context.read<CatalogProvider>();
      final marketplace = context.read<MarketplaceProvider>();
      final auth = context.read<AuthProvider>();
      final gender = auth.user?.gender.name ?? 'unknown'; // Get gender or default
      final localeProvider = context.read<LocaleProvider>();
      final language = localeProvider.locale.languageCode;

      return await _geminiService.ask(
        query: query,
        wardrobe: catalog.items,
        marketplace: marketplace.allProducts,
        gender: gender,
        language: language,
        history: _messages, // Pass current history
      );
    } catch (e) {
      return ConsultantResponse.error(e.toString());
    }
  }

  /// Форматировать ответ для отображения
  String _formatResponse(ConsultantResponse response) {
    String text = response.text;

    // Добавляем информацию о товарах
    if (response.hasProducts) {
      text += '\n\n📦 Рекомендованные товары (${response.products.length}):';
      for (final product in response.products) {
        text += '\n• ${product.name} - ${product.price.toStringAsFixed(0)}₸';
      }
    }

    // Добавляем источник ответа
    text += '\n\n${response.sourceIcon} ${response.sourceDescription}';

    return text;
  }

  /// Очистить историю чата
  void clearHistory() {
    _messages.clear();
    _addWelcomeMessage();
    notifyListeners();
  }

  /// Получить последний ответ консультанта
  ConsultantMessage? get lastAssistantMessage {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isUser) {
        return _messages[i];
      }
    }
    return null;
  }

  /// Получить товары из последнего ответа
  List<String> getProductIdsFromLastResponse() {
    final lastMessage = lastAssistantMessage;
    if (lastMessage == null) return [];

    // Извлекаем ID товаров из текста (если они там есть)
    final regex = RegExp(r'ID:(\w+)');
    final matches = regex.allMatches(lastMessage.text);
    return matches.map((m) => m.group(1)!).toList();
  }

  @override
  void dispose() {
    _messages.clear();
    super.dispose();
  }
}
