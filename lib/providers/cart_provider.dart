import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/clothing_item.dart';

/// Cart item with selected options
class CartItem {
  final ClothingItem product;
  final String? selectedSize;
  final String? selectedColor;
  int quantity;

  CartItem({
    required this.product,
    this.selectedSize,
    this.selectedColor,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(),
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: ClothingItem.fromMap(map['product']),
      selectedSize: map['selectedSize'],
      selectedColor: map['selectedColor'],
      quantity: map['quantity'] ?? 1,
    );
  }

  // Unique key for cart item (product + size + color)
  String get key => '${product.id}_${selectedSize ?? 'nosize'}_${selectedColor ?? 'nocolor'}';
}

/// Provider for shopping cart
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  String _buyerId = '';

  List<CartItem> get items => _items;
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  // Total items quantity
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  // Total price
  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Initialize cart for a buyer
  Future<void> init(String buyerId) async {
    _buyerId = buyerId;
    await _loadCart();
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cart_$_buyerId');

    if (cartJson != null) {
      final List<dynamic> cartList = jsonDecode(cartJson);
      _items = cartList.map((json) => CartItem.fromMap(json)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode(_items.map((item) => item.toMap()).toList());
    await prefs.setString('cart_$_buyerId', cartJson);
  }

  /// Add item to cart
  Future<void> addToCart({
    required ClothingItem product,
    String? selectedSize,
    String? selectedColor,
    int quantity = 1,
  }) async {
    // Check if item with same options already exists
    final existingIndex = _items.indexWhere((item) {
      return item.product.id == product.id &&
          item.selectedSize == selectedSize &&
          item.selectedColor == selectedColor;
    });

    if (existingIndex >= 0) {
      // Update quantity
      _items[existingIndex].quantity += quantity;
    } else {
      // Add new item
      _items.add(CartItem(
        product: product,
        selectedSize: selectedSize,
        selectedColor: selectedColor,
        quantity: quantity,
      ));
    }

    await _saveCart();
    notifyListeners();
  }

  /// Update item quantity
  Future<void> updateQuantity(String itemKey, int newQuantity) async {
    final index = _items.indexWhere((item) => item.key == itemKey);
    if (index >= 0) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = newQuantity;
      }
      await _saveCart();
      notifyListeners();
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String itemKey) async {
    _items.removeWhere((item) => item.key == itemKey);
    await _saveCart();
    notifyListeners();
  }

  /// Clear entire cart
  Future<void> clear() async {
    _items.clear();
    await _saveCart();
    notifyListeners();
  }

  /// Get cart item by key
  CartItem? getItem(String itemKey) {
    try {
      return _items.firstWhere((item) => item.key == itemKey);
    } catch (e) {
      return null;
    }
  }
}
