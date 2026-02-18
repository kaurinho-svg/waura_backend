import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing_item.dart';
import '../models/store_model.dart';

class CatalogRepository {
  static const _kItems = 'catalog_items_v1';
  static const _kStores = 'catalog_stores_v1';

  Future<(List<ClothingItem>, List<StoreModel>)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsRaw = prefs.getStringList(_kItems) ?? [];
    final storesRaw = prefs.getStringList(_kStores) ?? [];
    final items = itemsRaw.map((e) => ClothingItem.fromJson(e)).toList();
    final stores = storesRaw.map((e) => StoreModel.fromJson(e)).toList();
    return (items, stores);
  }

  Future<void> save(List<ClothingItem> items, List<StoreModel> stores) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kItems, items.map((e) => e.toJson()).toList());
    await prefs.setStringList(_kStores, stores.map((e) => e.toJson()).toList());
  }
}
