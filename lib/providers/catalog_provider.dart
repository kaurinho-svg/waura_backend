import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../models/clothing_item.dart';
import '../models/store_model.dart';

class CatalogProvider extends ChangeNotifier {
  // Supabase instance
  final _supabase = Supabase.instance.client;

  final List<ClothingItem> _items = [];
  final List<StoreModel> _stores = [];
  int _idCounter = 0;
  bool _loaded = false;

  /// Список вещей (только для чтения)
  List<ClothingItem> get items => List.unmodifiable(_items);
  List<StoreModel> get stores => List.unmodifiable(_stores);
  bool get isLoaded => _loaded;

  /// Инициализация: грузим каталог из Supabase
  Future<void> init() async {
    await loadItems();
  }

  /// Загрузить вещи из Supabase
  Future<void> loadItems() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _items.clear();
        _loaded = true;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('wardrobe_items')
          .select()
          .order('created_at', ascending: false);

      _items.clear();
      for (final row in response) {
        _items.add(ClothingItem(
          id: row['id'],
          name: row['name'] ?? '',
          category: row['category'] ?? 'other',
          imagePath: row['image_url'] ?? '',
          isNetwork: true, // Всегда true для Supabase
          tags: List<String>.from(row['tags'] ?? []),
          isAvailable: true,
        ));
      }
      
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wardrobe: $e');
    }
  }

  /// Добавить вещь (Загрузка фото + создание записи в БД)
  /// [imageFile] опционален. Если передан - грузим в Storage. Если нет - считаем item.imagePath уже URL.
  Future<void> addItem(ClothingItem item, [File? imageFile]) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      String imageUrl = item.imagePath;

      // 1. Upload Image to Supabase Storage (if file provided)
      if (imageFile != null) {
        final fileExt = imageFile.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '$userId/$fileName';

        await _supabase.storage.from('wardrobe').upload(
              filePath,
              imageFile,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );

        // Get Public URL
        imageUrl = _supabase.storage.from('wardrobe').getPublicUrl(filePath);
      }

      // 2. Insert into Database
      final response = await _supabase.from('wardrobe_items').insert({
        'user_id': userId,
        'name': item.name,
        'category': item.category,
        'image_url': imageUrl,
        'tags': item.tags,
        'is_favorite': false,
      }).select().single();

      // 3. Update Local State
      final newItem = ClothingItem(
        id: response['id'],
        name: response['name'],
        category: response['category'],
        imagePath: response['image_url'],
        isNetwork: true,
        tags: List<String>.from(response['tags'] ?? []),
      );
      
      _items.insert(0, newItem);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding item: $e');
      rethrow;
    }
  }

  /// Удалить вещь
  Future<void> removeItem(String id) async {
    try {
      // 1. Get item URL to find storage path
      final item = _items.firstWhere((e) => e.id == id);
      final imageUrl = item.imagePath; // Public URL

      // 2. Delete from Database
      await _supabase.from('wardrobe_items').delete().eq('id', id);

      // 3. Delete from Storage (Try to parse path from URL)
      // URL format: .../storage/v1/object/public/wardrobe/USER_ID/FILE_NAME
      try {
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('wardrobe');
        if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
          final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
          await _supabase.storage.from('wardrobe').remove([storagePath]);
        }
      } catch (e) {
        debugPrint('Error deleting image file: $e');
        // Continue even if image delete fails
      }

      // 4. Update Local State
      _items.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  // Deprecated/Modified helpers
  String newId() => ''; // Not needed, DB generates UUIDs

  /// Метод для совместимости, но теперь требует файл
  Future<void> addLocalFileItem({
    required String name,
    String category = 'other',
    List<String> tags = const [],
    required String imagePath,
    bool backgroundRemoved = false,
  }) async {
    // This wrapper is needed because UI passes path string, but we need File object for upload
    final file = File(imagePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $imagePath');
      return;
    }

    final item = ClothingItem(
      id: '', // Temp ID
      name: name,
      category: category,
      tags: tags,
      imagePath: imagePath,
      isNetwork: false,
    );

    await addItem(item, file);
  }

  // Stub methods for Stores (not migrated yet)
  void addStore(StoreModel store) {}
  void updateStore(StoreModel store) {}
}
