import 'package:flutter/foundation.dart';

/// Сообщение в чате с консультантом
class ConsultantMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? source; // 'rule-based', 'gemini-api', 'error'
  final List<String> recommendedProducts; // ID товаров
  final List<Map<String, dynamic>> generatedImages; // [NEW] URLs + Titles
  final String? imagePath; // [NEW] Local path to user's uploaded image

  ConsultantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.source,
    this.recommendedProducts = const [],
    this.generatedImages = const [],
    this.imagePath,
  });

  /// Создать сообщение от пользователя
  factory ConsultantMessage.user(String text, {String? imagePath}) {
    return ConsultantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      recommendedProducts: const [],
      generatedImages: const [],
      imagePath: imagePath,
    );
  }

  /// Создать сообщение от ассистента
  factory ConsultantMessage.assistant(
    String text, {
    String? source,
    List<String> recommendedProducts = const [],
    List<Map<String, dynamic>> generatedImages = const [],
  }) {
    return ConsultantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      source: source,
      recommendedProducts: recommendedProducts,
      generatedImages: generatedImages,
    );
  }

  /// Конвертация в Map для сохранения
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'recommendedProducts': recommendedProducts,
      'generatedImages': generatedImages,
    };
  }

  /// Создание из Map
  factory ConsultantMessage.fromMap(Map<String, dynamic> map) {
    return ConsultantMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      source: map['source'] as String?,
      recommendedProducts: map['recommendedProducts'] != null
          ? List<String>.from(map['recommendedProducts'] as List)
          : const [],
      generatedImages: map['generatedImages'] != null
          ? List<Map<String, dynamic>>.from(
              (map['generatedImages'] as List).map((e) => Map<String, dynamic>.from(e)))
          : const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsultantMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
