import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/order_model.dart';

/// Provider for buyer's order history
class BuyerOrdersProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  String _buyerId = '';

  List<OrderModel> get orders => _orders;
  bool get isEmpty => _orders.isEmpty;

  /// Initialize for a buyer
  Future<void> init(String buyerId) async {
    _buyerId = buyerId;
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getString('buyer_orders_$_buyerId');

    if (ordersJson != null) {
      final List<dynamic> ordersList = jsonDecode(ordersJson);
      _orders = ordersList.map((json) => OrderModel.fromMap(json)).toList();
      // Sort by date, newest first
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = jsonEncode(_orders.map((o) => o.toMap()).toList());
    await prefs.setString('buyer_orders_$_buyerId', ordersJson);
  }

  /// Add order to buyer's history
  Future<void> addOrder(OrderModel order) async {
    _orders.insert(0, order); // Add to beginning
    await _saveOrders();
    notifyListeners();
  }

  /// Get order by ID
  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Update order status (called when seller updates status)
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].updateStatus(newStatus);
      await _saveOrders();
      notifyListeners();
    }
  }

  /// Clear all orders
  Future<void> clear() async {
    _orders.clear();
    await _saveOrders();
    notifyListeners();
  }
}
