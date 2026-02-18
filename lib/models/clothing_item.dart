import 'dart:convert';

class ClothingItem {
  final String id;
  String name;
  String category; // e.g., dress, shirt, pants
  List<String> tags;

  /// local file path OR network url
  String imagePath;

  /// true = imagePath это URL, false = локальный файл
  bool isNetwork;

  bool backgroundRemoved;
  
  // Seller/Product specific fields
  String sellerId; // ID of the seller who owns this item
  String storeId; // ID of the store this item belongs to
  double price; // Price in KZT
  String currency; // Currency code (default: KZT)
  int stock; // Available quantity
  bool isAvailable; // Availability status
  List<String> sizes; // Available sizes (e.g., S, M, L, XL)
  List<String> colors; // Available colors
  String description; // Detailed product description

  ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    this.tags = const [],
    this.isNetwork = true,
    this.backgroundRemoved = false,
    this.sellerId = '',
    this.storeId = '',
    this.price = 0.0,
    this.currency = 'KZT',
    this.stock = 0,
    this.isAvailable = true,
    this.sizes = const [],
    this.colors = const [],
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'tags': tags,
        'imagePath': imagePath,
        'isNetwork': isNetwork,
        'backgroundRemoved': backgroundRemoved,
        'sellerId': sellerId,
        'storeId': storeId,
        'price': price,
        'currency': currency,
        'stock': stock,
        'isAvailable': isAvailable,
        'sizes': sizes,
        'colors': colors,
        'description': description,
      };

  factory ClothingItem.fromMap(Map<String, dynamic> map) => ClothingItem(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        category: (map['category'] ?? 'other').toString(),
        tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        imagePath: (map['imagePath'] ?? '').toString(),
        isNetwork: (map['isNetwork'] ?? true) == true,
        backgroundRemoved: (map['backgroundRemoved'] ?? false) == true,
        sellerId: (map['sellerId'] ?? '').toString(),
        storeId: (map['storeId'] ?? '').toString(),
        price: (map['price'] ?? 0.0) is int ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0),
        currency: (map['currency'] ?? 'KZT').toString(),
        stock: (map['stock'] ?? 0) is double ? (map['stock'] as double).toInt() : (map['stock'] ?? 0),
        isAvailable: (map['isAvailable'] ?? true) == true,
        sizes: (map['sizes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        colors: (map['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        description: (map['description'] ?? '').toString(),
      );

  /// Старый формат (строка JSON одного объекта) — оставил, чтобы не ломать совместимость
  String toJson() => jsonEncode(toMap());
  factory ClothingItem.fromJson(String src) =>
      ClothingItem.fromMap(jsonDecode(src) as Map<String, dynamic>);

  /// ✅ Нормальный формат для SharedPreferences: Map в списке
  Map<String, dynamic> toJsonMap() => toMap();

  factory ClothingItem.fromJsonMap(Map<String, dynamic> map) =>
      ClothingItem.fromMap(map);
}
