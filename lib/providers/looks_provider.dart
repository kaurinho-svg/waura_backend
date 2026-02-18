import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http; // For downloading temp images

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

  factory SavedLook.fromMap(Map<String, dynamic> map) {
    return SavedLook(
      id: map['id'],
      userImageUrl: map['user_image_url'] ?? '',
      clothingImageUrl: map['clothing_image_url'] ?? '',
      resultImageUrl: map['result_image_url'] ?? '',
      prompt: map['prompt'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

/// Провайдер для списка сохранённых образов
class LooksProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<SavedLook> _looks = [];
  bool _isLoading = false;

  List<SavedLook> get looks => List.unmodifiable(_looks);
  bool get isLoading => _isLoading;

  /// Загрузка истории из Supabase
  Future<void> load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _looks = [];
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('created_looks')
          .select()
          .order('created_at', ascending: false);

      _looks = (response as List).map((e) => SavedLook.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Failed to load looks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Сохранение образа (Скачивание -> Загрузка в Storage -> Запись в БД)
  Future<void> addLook({
    required String userImageUrl,
    required String clothingImageUrl,
    required String resultImageUrl,
    required String prompt,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Download and Upload Images to Supabase Storage
      // We do this to ensure persistence, as the AI API URLs might be temporary.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final persistentUserUrl = await _uploadFromUrl(userImageUrl, '$userId/${timestamp}_user.jpg');
      final persistentClothingUrl = await _uploadFromUrl(clothingImageUrl, '$userId/${timestamp}_clothing.jpg');
      final persistentResultUrl = await _uploadFromUrl(resultImageUrl, '$userId/${timestamp}_result.jpg');

      // 2. Insert into Database
      final response = await _supabase.from('created_looks').insert({
        'user_id': userId,
        'user_image_url': persistentUserUrl,
        'clothing_image_url': persistentClothingUrl,
        'result_image_url': persistentResultUrl,
        'prompt': prompt,
      }).select().single();

      // 3. Update Local State
      final newLook = SavedLook.fromMap(response);
      _looks.insert(0, newLook);
      notifyListeners();

    } catch (e) {
      debugPrint('Error adding look: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper: Download from URL -> Upload to Supabase Storage
  Future<String> _uploadFromUrl(String url, String path) async {
    try {
      // If it's already a Supabase URL, just return it (avoid re-uploading if not needed)
      if (url.contains('supabase')) return url;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Failed to download image');

      await _supabase.storage.from('generated_looks').uploadBinary(
        path,
        response.bodyBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      return _supabase.storage.from('generated_looks').getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload failed for $url: $e');
      // Fallback: return original URL if upload fails (better than nothing)
      return url; 
    }
  }

  Future<void> deleteLook(String id) async {
    try {
      await _supabase.from('created_looks').delete().eq('id', id);
      _looks.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting look: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('created_looks').delete().eq('user_id', userId);
      _looks.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing looks: $e');
    }
  }
}