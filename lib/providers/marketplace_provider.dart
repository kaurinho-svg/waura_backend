import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/store_model.dart';
import '../models/clothing_item.dart';

/// Provider для маркетплейса - собирает магазины и товары всех продавцов
class MarketplaceProvider extends ChangeNotifier {
  List<StoreModel> _allStores = [];
  List<ClothingItem> _allProducts = [];
  bool _isLoading = false;

  List<StoreModel> get allStores => _allStores;
  List<ClothingItem> get allProducts => _allProducts;
  bool get isLoading => _isLoading;

  // Get products for a specific store
  List<ClothingItem> getProductsByStore(String storeId) {
    return _allProducts.where((p) => p.storeId == storeId).toList();
  }

  // Get store by ID
  StoreModel? getStoreById(String storeId) {
    try {
      return _allStores.firstWhere((s) => s.id == storeId);
    } catch (e) {
      return null;
    }
  }

  // Get active stores only
  List<StoreModel> get activeStores {
    return _allStores.where((s) => s.isActive).toList();
  }

  // Get available products only
  List<ClothingItem> get availableProducts {
    return _allProducts.where((p) => p.isAvailable && p.stock > 0).toList();
  }

  /// Load all stores and products from all sellers
  Future<void> loadMarketplace() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys that start with 'seller_stores_' or 'seller_products_'
      final keys = prefs.getKeys();
      
      List<StoreModel> stores = [];
      List<ClothingItem> products = [];

      // Load all seller stores
      for (final key in keys) {
        if (key.startsWith('seller_stores_')) {
          final storesJson = prefs.getString(key);
          if (storesJson != null) {
            final List<dynamic> storesList = jsonDecode(storesJson);
            stores.addAll(
              storesList.map((json) => StoreModel.fromMap(json)).toList(),
            );
          }
        }
      }

      // Load all seller products
      for (final key in keys) {
        if (key.startsWith('seller_products_')) {
          final productsJson = prefs.getString(key);
          if (productsJson != null) {
            final List<dynamic> productsList = jsonDecode(productsJson);
            products.addAll(
              productsList.map((json) => ClothingItem.fromMap(json)).toList(),
            );
          }
        }
      }

      _allStores = stores;
      _allProducts = products;

      if (_allStores.isEmpty || _allProducts.isEmpty) {
        _seedMockData(); // Seed if empty
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading marketplace: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refresh marketplace data
  Future<void> refresh() async {
    await loadMarketplace();
  }

  void _seedMockData() {
    // 1. Mock Stores (Same as mock_styles.dart)
    _allStores = [
      StoreModel(id: 'zara', name: 'ZARA', url: 'https://zara.com', description: 'Latest trends in clothing.', isActive: true),
      StoreModel(id: 'hm', name: 'H&M', url: 'https://hm.com', description: 'Fashion and quality at best price.', isActive: true),
      StoreModel(id: 'massimo', name: 'Massimo Dutti', url: 'https://massimodutti.com', description: 'Elegant style.', isActive: true),
      StoreModel(id: 'mango', name: 'MANGO', url: 'https://mango.com', description: 'Mediterranean culture.', isActive: true),
    ];

    // 2. Mock Products
    _allProducts = [
      // ZARA Items
      ClothingItem(
        id: 'z1',
        name: 'Oversized Blazer',
        category: 'Upper Body',
        imagePath: 'https://static.zara.net/photos///2023/I/0/1/p/8372/232/800/2/w/850/8372232800_6_1_1.jpg?ts=1697034636952',
        storeId: 'zara',
        price: 39990,
        currency: 'KZT',
        description: 'Blazer with lapel collar and long sleeves. Shoulder pads.',
        sizes: ['XS', 'S', 'M', 'L'],
        colors: ['Black', 'Grey'],
        tags: ['blazer', 'office'],
      ),
      ClothingItem(
        id: 'z2',
        name: 'Wide-Leg Jeans',
        category: 'Lower Body',
        imagePath: 'https://static.zara.net/photos///2023/I/0/1/p/6045/222/400/2/w/850/6045222400_6_1_1.jpg?ts=1695204432123',
        storeId: 'zara',
        price: 25990,
        currency: 'KZT',
        description: 'High-waist jeans with five belt loops.',
        sizes: ['34', '36', '38', '40'],
        colors: ['Blue'],
        tags: ['jeans', 'casual'],
      ),
       ClothingItem(
        id: 'z3',
        name: 'Basic T-Shirt',
        category: 'Upper Body',
        imagePath: 'https://static.zara.net/photos///2023/I/0/1/p/4424/153/250/2/w/850/4424153250_6_1_1.jpg?ts=1691147050123',
        storeId: 'zara',
        price: 9990,
        currency: 'KZT',
        description: 'Cotton T-shirt with round neck.',
        sizes: ['S', 'M', 'L'],
        colors: ['White', 'Black'],
        tags: ['basics', 't-shirt'],
      ),

      // H&M Items
      ClothingItem(
        id: 'h1',
        name: 'Hoodie',
        category: 'Upper Body',
        imagePath: 'https://lp2.hm.com/hmgoepprod?set=quality%5B79%5D%2Csource%5B%2F62%2F6e%2F626e2051677c7322986961445778a599298495a8.jpg%5D%2Corigin%5Bdam%5D%2Ccategory%5Bmen_hoodiessweatshirts_hoodies%5D%2Ctype%5BDESCRIPTIVESTILLLIFE%5D%2Cres%5Bm%5D%2Chmver%5B2%5D&call=url[file:/product/main]',
        storeId: 'hm',
        price: 14990,
        currency: 'KZT',
        description: 'Relaxed-fit hoodie in sweatshirt fabric.',
        sizes: ['S', 'M', 'L', 'XL'],
        colors: ['Grey', 'Black'],
        tags: ['hoodie', 'casual'],
      ),
      ClothingItem(
        id: 'h2',
        name: 'Slim Fit Chinos',
        category: 'Lower Body',
        imagePath: 'https://lp2.hm.com/hmgoepprod?set=quality%5B79%5D%2Csource%5B%2Fb3%2F78%2Fb378292812239611d8d21c3855ff4df146059c11.jpg%5D%2Corigin%5Bdam%5D%2Ccategory%5B%5D%2Ctype%5BDESCRIPTIVESTILLLIFE%5D%2Cres%5Bm%5D%2Chmver%5B2%5D&call=url[file:/product/main]',
        storeId: 'hm',
        price: 18990,
        currency: 'KZT',
        description: 'Chinos in stretch cotton twill.',
        sizes: ['30', '32', '34'],
        colors: ['Beige', 'Navy'],
        tags: ['pants', 'smart casual'],
      ),
      
      // Massimo Dutti
      ClothingItem(
        id: 'm1',
        name: 'Wool Sweater',
        category: 'Upper Body',
        imagePath: 'https://static.massimodutti.net/3/photos//2023/I/0/2/p/5610/500/800/2/w/1920/5610500800_2_1_16.jpg?ts=1697103456789',
        storeId: 'massimo',
        price: 45990,
        currency: 'KZT',
        description: '100% Wool sweater.',
        sizes: ['M', 'L', 'XL'],
        colors: ['Black'],
        tags: ['winter', 'wool'],
      ),
    ];
  }

  /// Search products by name or category
  List<ClothingItem> searchProducts(String query) {
    if (query.isEmpty) return availableProducts;
    
    final lowerQuery = query.toLowerCase();
    return availableProducts.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
             p.category.toLowerCase().contains(lowerQuery) ||
             p.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter products by category
  List<ClothingItem> filterByCategory(String category) {
    return availableProducts.where((p) => p.category == category).toList();
  }

  /// Get all unique categories
  List<String> get categories {
    final cats = _allProducts.map((p) => p.category).toSet().toList();
    cats.sort();
    return cats;
  }
}
