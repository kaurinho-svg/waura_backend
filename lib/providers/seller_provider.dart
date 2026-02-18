import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/store_model.dart';
import '../models/clothing_item.dart';
import '../models/order_model.dart';

class SellerProvider extends ChangeNotifier {
  // Seller's stores
  List<StoreModel> _stores = [];
  
  // All products across all seller's stores
  List<ClothingItem> _products = [];
  
  // Orders for seller's stores
  List<OrderModel> _orders = [];
  
  // Current seller ID
  String _sellerId = '';
  
  // Loading states
  bool _isLoading = false;
  
  SellerProvider();
  
  // Getters
  List<StoreModel> get stores => _stores;
  List<ClothingItem> get products => _products;
  List<OrderModel> get orders => _orders;
  String get sellerId => _sellerId;
  bool get isLoading => _isLoading;
  
  // Get active stores only
  List<StoreModel> get activeStores => 
      _stores.where((store) => store.isActive).toList();
  
  // Get products for a specific store
  List<ClothingItem> getProductsByStore(String storeId) =>
      _products.where((p) => p.storeId == storeId).toList();
  
  // Get orders for a specific store
  List<OrderModel> getOrdersByStore(String storeId) =>
      _orders.where((o) => o.storeId == storeId).toList();
  
  // Get orders by status
  List<OrderModel> getOrdersByStatus(OrderStatus status) =>
      _orders.where((o) => o.status == status).toList();
  
  // Statistics
  int get totalProducts => _products.length;
  int get totalOrders => _orders.length;
  int get pendingOrders => _orders.where((o) => o.status == OrderStatus.pending).length;
  
  double get totalRevenue => _orders
      .where((o) => o.status == OrderStatus.delivered && o.isPaid)
      .fold(0.0, (sum, order) => sum + order.totalAmount);
  
  // Low stock products (stock < 5)
  List<ClothingItem> get lowStockProducts =>
      _products.where((p) => p.stock < 5 && p.stock > 0).toList();
  
  // Out of stock products
  List<ClothingItem> get outOfStockProducts =>
      _products.where((p) => p.stock == 0).toList();
  
  // Initialize seller data
  Future<void> init(String sellerId) async {
    _sellerId = sellerId;
    _isLoading = true;
    notifyListeners();
    
    await _loadStores();
    await _loadProducts();
    await _loadOrders();
    
    _isLoading = false;
    notifyListeners();
  }
  
  // ========== STORE MANAGEMENT ==========
  
  Future<void> _loadStores() async {
    final prefs = await SharedPreferences.getInstance();
    final storesJson = prefs.getString('seller_stores_$_sellerId');
    
    if (storesJson != null) {
      final List<dynamic> storesList = jsonDecode(storesJson);
      _stores = storesList.map((json) => StoreModel.fromMap(json)).toList();
    }
  }
  
  Future<void> _saveStores() async {
    final prefs = await SharedPreferences.getInstance();
    final storesJson = jsonEncode(_stores.map((s) => s.toMap()).toList());
    await prefs.setString('seller_stores_$_sellerId', storesJson);
  }
  
  Future<void> addStore(StoreModel store) async {
    _stores.add(store);
    await _saveStores();
    notifyListeners();
  }
  
  Future<void> updateStore(StoreModel store) async {
    final index = _stores.indexWhere((s) => s.id == store.id);
    if (index != -1) {
      _stores[index] = store;
      await _saveStores();
      notifyListeners();
    }
  }
  
  Future<void> deleteStore(String storeId) async {
    _stores.removeWhere((s) => s.id == storeId);
    // Also remove products from this store
    _products.removeWhere((p) => p.storeId == storeId);
    await _saveStores();
    await _saveProducts();
    notifyListeners();
  }
  
  Future<void> toggleStoreStatus(String storeId) async {
    final index = _stores.indexWhere((s) => s.id == storeId);
    if (index != -1) {
      _stores[index] = _stores[index].copyWith(
        isActive: !_stores[index].isActive,
      );
      await _saveStores();
      notifyListeners();
    }
  }
  
  // ========== PRODUCT MANAGEMENT ==========
  
  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = prefs.getString('seller_products_$_sellerId');
    
    if (productsJson != null) {
      final List<dynamic> productsList = jsonDecode(productsJson);
      _products = productsList.map((json) => ClothingItem.fromMap(json)).toList();
    }
  }
  
  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = jsonEncode(_products.map((p) => p.toMap()).toList());
    await prefs.setString('seller_products_$_sellerId', productsJson);
  }
  
  Future<void> addProduct(ClothingItem product) async {
    _products.add(product);
    await _saveProducts();
    notifyListeners();
  }
  
  Future<void> updateProduct(ClothingItem product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      await _saveProducts();
      notifyListeners();
    }
  }
  
  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    await _saveProducts();
    notifyListeners();
  }
  
  Future<void> updateProductStock(String productId, int newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index].stock = newStock;
      _products[index].isAvailable = newStock > 0;
      await _saveProducts();
      notifyListeners();
    }
  }
  
  Future<void> toggleProductAvailability(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index].isAvailable = !_products[index].isAvailable;
      await _saveProducts();
      notifyListeners();
    }
  }
  
  // Bulk operations
  Future<void> deleteProducts(List<String> productIds) async {
    _products.removeWhere((p) => productIds.contains(p.id));
    await _saveProducts();
    notifyListeners();
  }
  
  Future<void> toggleProductsAvailability(List<String> productIds, bool isAvailable) async {
    for (final id in productIds) {
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index].isAvailable = isAvailable;
      }
    }
    await _saveProducts();
    notifyListeners();
  }
  
  // ========== ORDER MANAGEMENT ==========
  
  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getString('seller_orders_$_sellerId');
    
    if (ordersJson != null) {
      final List<dynamic> ordersList = jsonDecode(ordersJson);
      _orders = ordersList.map((json) => OrderModel.fromMap(json)).toList();
    }
  }
  
  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = jsonEncode(_orders.map((o) => o.toMap()).toList());
    await prefs.setString('seller_orders_$_sellerId', ordersJson);
  }
  
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].updateStatus(newStatus);
      
      // If order is delivered, reduce stock
      if (newStatus == OrderStatus.delivered) {
        for (final item in _orders[index].items) {
          final productIndex = _products.indexWhere((p) => p.id == item.productId);
          if (productIndex != -1) {
            final newStock = _products[productIndex].stock - item.quantity;
            await updateProductStock(item.productId, newStock.clamp(0, 999999));
          }
        }
      }
      
      await _saveOrders();
      
      // Also update buyer's order status
      await _syncBuyerOrderStatus(orderId, newStatus);
      
      notifyListeners();
    }
  }
  
  /// Sync order status with buyer's order history
  Future<void> _syncBuyerOrderStatus(String orderId, OrderStatus newStatus) async {
    final order = _orders.firstWhere((o) => o.id == orderId);
    final prefs = await SharedPreferences.getInstance();
    final buyerOrdersKey = 'buyer_orders_${order.buyerId}';
    final ordersJson = prefs.getString(buyerOrdersKey);
    
    if (ordersJson != null) {
      final List<dynamic> ordersList = jsonDecode(ordersJson);
      final List<OrderModel> buyerOrders = ordersList.map((json) => OrderModel.fromMap(json)).toList();
      
      final buyerOrderIndex = buyerOrders.indexWhere((o) => o.id == orderId);
      if (buyerOrderIndex != -1) {
        buyerOrders[buyerOrderIndex].updateStatus(newStatus);
        final updatedJson = jsonEncode(buyerOrders.map((o) => o.toMap()).toList());
        await prefs.setString(buyerOrdersKey, updatedJson);
      }
    }
  }
  
  Future<void> markOrderAsPaid(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].markAsPaid();
      await _saveOrders();
      notifyListeners();
    }
  }
  
  // Add new order (when buyer places order)
  Future<void> addOrder(OrderModel order) async {
    _orders.add(order);
    await _saveOrders();
    notifyListeners();
  }
  
  // ========== UTILITY METHODS ==========
  
  // Generate unique ID
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  // Clear all data (for logout)
  Future<void> clear() async {
    _stores.clear();
    _products.clear();
    _orders.clear();
    _sellerId = '';
    notifyListeners();
  }
  
  // Refresh all data
  Future<void> refresh() async {
    if (_sellerId.isEmpty) return;
    await init(_sellerId);
  }
}
