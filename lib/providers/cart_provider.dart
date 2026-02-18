import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../models/clothing_item.dart';

/// Cart item with selected options
class CartItem {
  final String id; // DB ID
  final ClothingItem product;
  final String? selectedSize;
  final String? selectedColor;
  int quantity;

  CartItem({
    required this.id,
    required this.product,
    this.selectedSize,
    this.selectedColor,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  // Unique key for cart item logic (product + size + color)
  String get key => '${product.id}_${selectedSize ?? 'nosize'}_${selectedColor ?? 'nocolor'}';
}

/// Provider for shopping cart
class CartProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isLoading => _isLoading;

  // Total items quantity
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  // Total price
  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Initialize cart (load from Supabase)
  Future<void> init() async {
    await _loadCart();
  }

  Future<void> _loadCart() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _items = [];
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('cart_items')
          .select()
          .order('created_at', ascending: false);

      _items = (_itemsFromResponse(response));
    } catch (e) {
      debugPrint('Error loading cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<CartItem> _itemsFromResponse(List<dynamic> data) {
    return data.map((row) {
      return CartItem(
        id: row['id'],
        product: ClothingItem.fromMap(row['product_data']),
        selectedSize: row['selected_size'],
        selectedColor: row['selected_color'],
        quantity: row['quantity'] ?? 1,
      );
    }).toList();
  }

  /// Add item to cart
  Future<void> addToCart({
    required ClothingItem product,
    String? selectedSize,
    String? selectedColor,
    int quantity = 1,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Check if item already exists locally to update quantity
    // Ideally we should check DB, but local state is roughly synced
    final existingIndex = _items.indexWhere((item) {
      return item.product.id == product.id &&
          item.selectedSize == selectedSize &&
          item.selectedColor == selectedColor;
    });

    try {
      if (existingIndex >= 0) {
        // Update quantity
        final existingItem = _items[existingIndex];
        final newQuantity = existingItem.quantity + quantity;
        
        await _supabase.from('cart_items').update({
          'quantity': newQuantity,
        }).eq('id', existingItem.id);

        existingItem.quantity = newQuantity;
      } else {
        // Insert new item
        final response = await _supabase.from('cart_items').insert({
          'user_id': userId,
          'product_data': product.toMap(),
          'quantity': quantity,
          'selected_size': selectedSize,
          'selected_color': selectedColor,
        }).select().single();

        final newItem = CartItem(
          id: response['id'],
          product: product,
          selectedSize: selectedSize,
          selectedColor: selectedColor,
          quantity: quantity,
        );
        _items.add(newItem);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      rethrow;
    }
  }

  /// Update item quantity
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(cartItemId);
      return;
    }

    try {
      await _supabase.from('cart_items').update({
         'quantity': newQuantity,
      }).eq('id', cartItemId);

      final index = _items.indexWhere((item) => item.id == cartItemId);
      if (index != -1) {
        _items[index].quantity = newQuantity;
        notifyListeners();
      }
    } catch (e) {
       debugPrint('Error updating quantity: $e');
    }
  }

  /// Remove item from cart (using Cart ID)
  Future<void> removeItem(String cartItemId) async {
    try {
      await _supabase.from('cart_items').delete().eq('id', cartItemId);
      _items.removeWhere((item) => item.id == cartItemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  /// Clear entire cart
  Future<void> clear() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('cart_items').delete().eq('user_id', userId);
      _items.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }

  /// Get cart item by key (product_size_color) - legacy helper
  /// Not fully reliable with ID-based logic, but useful for UI checks
  CartItem? getItemByKey(String key) {
    try {
      return _items.firstWhere((item) => item.key == key);
    } catch (e) {
      return null;
    }
  }
}
