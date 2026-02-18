import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Одна сохранённая примерка
class SavedLook {
  final String id;
  final String userImageUrl;
  final String clothingImageUrl;
  final String resultImageUrl;
  final String prompt;
  final DateTime createdAt;

  SavedLook({
    required this.id,
    required this.userImageUrl,
    required this.clothingImageUrl,
    required this.resultImageUrl,
    required this.prompt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userImageUrl': userImageUrl,
        'clothingImageUrl': clothingImageUrl,
        'resultImageUrl': resultImageUrl,
        'prompt': prompt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedLook.fromJson(Map<String, dynamic> json) => SavedLook(
        id: json['id'] as String,
        userImageUrl: json['userImageUrl'] as String,
        clothingImageUrl: json['clothingImageUrl'] as String,
        resultImageUrl: json['resultImageUrl'] as String,
        prompt: json['prompt'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Провайдер для списка сохранённых образов
class LooksProvider extends ChangeNotifier {
  static const _storageKey = 'saved_looks_v1';

  final List<SavedLook> _looks = [];

  List<SavedLook> get looks => List.unmodifiable(_looks);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _looks
        ..clear()
        ..addAll(
          data
              .map((e) => SavedLook.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load looks: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_looks.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> addLook({
    required String userImageUrl,
    required String clothingImageUrl,
    required String resultImageUrl,
    required String prompt,
  }) async {
    final look = SavedLook(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userImageUrl: userImageUrl,
      clothingImageUrl: clothingImageUrl,
      resultImageUrl: resultImageUrl,
      prompt: prompt,
      createdAt: DateTime.now(),
    );
    _looks.insert(0, look); // новые сверху
    await _persist();
    notifyListeners();
  }

  Future<void> deleteLook(String id) async {
    _looks.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _looks.clear();
    await _persist();
    notifyListeners();
  }
}