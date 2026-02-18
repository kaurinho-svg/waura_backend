import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/clothing_item.dart';
import '../models/store_model.dart';

class CatalogProvider extends ChangeNotifier {
  static const String _kItemsKey = 'catalog_items_v1';
  static const String _kIdCounterKey = 'catalog_id_counter_v1';

  final List<ClothingItem> _items = [];
  final List<StoreModel> _stores = [];

  int _idCounter = 0;
  bool _loaded = false;

  /// Список вещей (только для чтения)
  List<ClothingItem> get items => List.unmodifiable(_items);

  /// Список магазинов (если ты их используешь)
  List<StoreModel> get stores => List.unmodifiable(_stores);

  bool get isLoaded => _loaded;

  /// Простой генератор id: "1", "2", "3"…
  String newId() {
    _idCounter++;
    _persistIdCounter(); // чтобы не терять счётчик
    return _idCounter.toString();
  }

  /// Инициализация: грузим каталог из SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) загрузим idCounter
    _idCounter = prefs.getInt(_kIdCounterKey) ?? 0;

    // 2) загрузим items
    final raw = prefs.getString(_kItemsKey);
    _items.clear();

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<dynamic>();
        for (final e in list) {
          if (e is Map) {
            _items.add(
              ClothingItem.fromJsonMap(Map<String, dynamic>.from(e)),
            );
          }
        }
      } catch (_) {
        // если формат сломан — не падаем
      }
    }

    // 3) если вдруг idCounter меньше, чем max id в списке — подтянем
    final maxId = _items
        .map((e) => int.tryParse(e.id) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maxId > _idCounter) _idCounter = maxId;
    await _persistIdCounter();

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_items.map((e) => e.toJsonMap()).toList());
    await prefs.setString(_kItemsKey, data);
  }

  Future<void> _persistIdCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIdCounterKey, _idCounter);
  }

  /// Добавить вещь в каталог (в память + в prefs)
  Future<void> addItem(ClothingItem item) async {
    _items.insert(0, item);
    await _persistItems();
    notifyListeners();
  }

  /// Удалить вещь по id (в память + в prefs)
  Future<void> removeItem(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persistItems();
    notifyListeners();
  }

  /// ✅ Удобный метод: добавить вещь из локального файла (то, что нужно для "Каталог вещей")
  /// imagePath должен быть ЛОКАЛЬНЫМ путём, чтобы CatalogScreen мог показать Image.file(...)
  Future<void> addLocalFileItem({
    required String name,
    String category = 'other',
    List<String> tags = const [],
    required String imagePath,
    bool backgroundRemoved = false,
  }) async {
    final item = ClothingItem(
      id: newId(),
      name: name,
      category: category,
      tags: tags,
      imagePath: imagePath,
      isNetwork: false, // ключевой момент: это ЛОКАЛЬНЫЙ файл
      backgroundRemoved: backgroundRemoved,
    );
    await addItem(item);
  }

  /// (опционально) защита от дублей по пути
  bool containsImagePath(String path) {
    final p = path.trim();
    return _items.any((e) => e.imagePath.trim() == p);
  }

  /// Добавить магазин (если нужно)
  void addStore(StoreModel store) {
    _stores.add(store);
    notifyListeners();
  }

  /// Обновить магазин (если нужно)
  void updateStore(StoreModel store) {
    final index = _stores.indexWhere((s) => s.id == store.id);
    if (index != -1) {
      _stores[index] = store;
      notifyListeners();
    }
  }
}
