import 'dart:convert';

enum OrderStatus {
  pending,    // Заказ создан, ожидает подтверждения
  confirmed,  // Подтвержден продавцом
  processing, // В обработке
  shipped,    // Отправлен
  delivered,  // Доставлен
  cancelled,  // Отменен
}

class OrderItem {
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final String size;
  final String color;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    this.size = '',
    this.color = '',
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'productImage': productImage,
        'price': price,
        'quantity': quantity,
        'size': size,
        'color': color,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        productImage: map['productImage'] ?? '',
        price: (map['price'] ?? 0.0) is int
            ? (map['price'] as int).toDouble()
            : (map['price'] ?? 0.0),
        quantity: (map['quantity'] ?? 1) is double
            ? (map['quantity'] as double).toInt()
            : (map['quantity'] ?? 1),
        size: map['size'] ?? '',
        color: map['color'] ?? '',
      );
}

class OrderModel {
  final String id;
  
  // Buyer information
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final String buyerPhone;
  
  // Seller information
  final String sellerId;
  final String storeId;
  final String storeName;
  
  // Order details
  final List<OrderItem> items;
  final double totalAmount;
  final String currency;
  OrderStatus status;
  
  // Timestamps
  final DateTime createdAt;
  DateTime updatedAt;
  
  // Delivery information
  final String shippingAddress;
  final String deliveryNotes;
  
  // Payment
  final String paymentMethod;
  bool isPaid;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    this.buyerPhone = '',
    required this.sellerId,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.totalAmount,
    this.currency = 'KZT',
    this.status = OrderStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.shippingAddress = '',
    this.deliveryNotes = '',
    this.paymentMethod = 'cash', // cash, card, online
    this.isPaid = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerEmail': buyerEmail,
        'buyerPhone': buyerPhone,
        'sellerId': sellerId,
        'storeId': storeId,
        'storeName': storeName,
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': totalAmount,
        'currency': currency,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'shippingAddress': shippingAddress,
        'deliveryNotes': deliveryNotes,
        'paymentMethod': paymentMethod,
        'isPaid': isPaid,
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] ?? 'pending';
    return OrderModel(
      id: map['id'] ?? '',
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      buyerEmail: map['buyerEmail'] ?? '',
      buyerPhone: map['buyerPhone'] ?? '',
      sellerId: map['sellerId'] ?? '',
      storeId: map['storeId'] ?? '',
      storeName: map['storeName'] ?? '',
      items: (map['items'] as List?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0) is int
          ? (map['totalAmount'] as int).toDouble()
          : (map['totalAmount'] ?? 0.0),
      currency: map['currency'] ?? 'KZT',
      status: OrderStatus.values.byName(statusStr),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      shippingAddress: map['shippingAddress'] ?? '',
      deliveryNotes: map['deliveryNotes'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      isPaid: map['isPaid'] ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory OrderModel.fromJson(String src) =>
      OrderModel.fromMap(jsonDecode(src));

  // Helper methods
  bool belongsToSeller(String sellerId) => this.sellerId == sellerId;
  bool belongsToBuyer(String buyerId) => this.buyerId == buyerId;
  
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  // Update order status
  OrderModel updateStatus(OrderStatus newStatus) {
    status = newStatus;
    updatedAt = DateTime.now();
    return this;
  }
  
  // Mark as paid
  OrderModel markAsPaid() {
    isPaid = true;
    updatedAt = DateTime.now();
    return this;
  }

  // Copy with method
  OrderModel copyWith({
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    String? shippingAddress,
    String? deliveryNotes,
    String? paymentMethod,
    bool? isPaid,
  }) {
    return OrderModel(
      id: id,
      buyerId: buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      sellerId: sellerId,
      storeId: storeId,
      storeName: storeName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      shippingAddress: shippingAddress ?? this.shippingAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
