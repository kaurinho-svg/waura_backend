import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_styles.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _kKey = 'favorite_styles';

  List<StyleInspiration> _items = [];
  
  List<StyleInspiration> get items => List.unmodifiable(_items);

  bool isFavorite(String imageUrl) {
    return _items.any((i) => i.imageUrl == imageUrl);
  }

  // --- Product Favorites ---
  static const _kProductsKey = 'favorite_product_ids';
  final Set<String> _productIds = {};

  bool isProductFavorite(String id) => _productIds.contains(id);

  Future<void> toggleProductFavorite(String id) async {
    if (_productIds.contains(id)) {
      _productIds.remove(id);
    } else {
      _productIds.add(id);
    }
    notifyListeners();
    await _saveProducts();
  }

  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kProductsKey, _productIds.toList());
  }

  // Override load to include products
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Styles
    final String? jsonStr = prefs.getString(_kKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _items = list.map((json) => StyleInspiration(
          imageUrl: json['imageUrl'],
          title: json['title'],
          category: json['category'],
          tags: List<String>.from(json['tags'] ?? []),
        )).toList();
      } catch (e) {
        debugPrint("Error loading favorites: $e");
      }
    }

    // 2. Load Products
    final List<String>? ids = prefs.getStringList(_kProductsKey);
    if (ids != null) {
      _productIds.clear();
      _productIds.addAll(ids);
    }
    
    notifyListeners();
  }

  Future<void> toggleFavorite(StyleInspiration item) async {
    if (isFavorite(item.imageUrl)) {
      _items.removeWhere((i) => i.imageUrl == item.imageUrl);
    } else {
      _items.add(item);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_items.map((i) => {
      'imageUrl': i.imageUrl,
      'title': i.title,
      'category': i.category,
      'tags': i.tags,
    }).toList());
    await prefs.setString(_kKey, jsonStr);
  }
}
