import 'dart:convert';

class StoreModel {
  final String id;
  String name;
  String url; // website
  List<String> clothingItemIds; // references to ClothingItem
  
  // Seller-specific fields
  String ownerId; // User ID of the seller who owns this store
  String description; // Store description
  String logoUrl; // Store logo URL or path
  bool isActive; // Store active status
  DateTime createdAt; // When the store was created
  Map<String, String> contactInfo; // phone, email, social media links

  StoreModel({
    required this.id,
    required this.name,
    required this.url,
    this.clothingItemIds = const [],
    this.ownerId = '',
    this.description = '',
    this.logoUrl = '',
    this.isActive = true,
    DateTime? createdAt,
    this.contactInfo = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'clothingItemIds': clothingItemIds,
        'ownerId': ownerId,
        'description': description,
        'logoUrl': logoUrl,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'contactInfo': contactInfo,
      };

  factory StoreModel.fromMap(Map<String, dynamic> map) => StoreModel(
        id: map['id'],
        name: map['name'] ?? '',
        url: map['url'] ?? '',
        clothingItemIds: (map['clothingItemIds'] as List?)?.cast<String>() ?? [],
        ownerId: map['ownerId'] ?? '',
        description: map['description'] ?? '',
        logoUrl: map['logoUrl'] ?? '',
        isActive: map['isActive'] ?? true,
        createdAt: map['createdAt'] != null 
            ? DateTime.parse(map['createdAt']) 
            : DateTime.now(),
        contactInfo: (map['contactInfo'] as Map?)?.cast<String, String>() ?? {},
      );

  String toJson() => jsonEncode(toMap());
  factory StoreModel.fromJson(String src) => StoreModel.fromMap(jsonDecode(src));
  
  // Helper method to check if store belongs to a specific seller
  bool belongsTo(String sellerId) => ownerId == sellerId;
  
  // Copy with method for updating store data
  StoreModel copyWith({
    String? name,
    String? url,
    List<String>? clothingItemIds,
    String? ownerId,
    String? description,
    String? logoUrl,
    bool? isActive,
    DateTime? createdAt,
    Map<String, String>? contactInfo,
  }) {
    return StoreModel(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      clothingItemIds: clothingItemIds ?? this.clothingItemIds,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}
