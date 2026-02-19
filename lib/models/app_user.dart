enum Gender { male, female }
enum UserRole { buyer, seller }

class AppUser {
  final String name;
  final String email;
  final Gender gender;
  final UserRole role;
  
  // Seller-specific fields (optional)
  final List<String> storeIds; // List of store IDs owned by seller (supports multiple stores)
  
  // Premium Status
  final bool isPremium;

  const AppUser({
    required this.name,
    required this.email,
    required this.gender,
    required this.role,
    this.storeIds = const [],
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "email": email,
        "gender": gender.name,
        "role": role.name,
        "storeIds": storeIds,
        "is_premium": isPremium,
      };

  static AppUser fromJson(Map<String, dynamic> json) {
    final genderStr = (json["gender"] as String?) ?? "male";
    final roleStr = (json["role"] as String?) ?? "buyer";

    return AppUser(
      name: (json["name"] as String?) ?? "",
      email: (json["email"] as String?) ?? "",
      gender: Gender.values.byName(genderStr),
      role: UserRole.values.byName(roleStr),
      storeIds: (json["storeIds"] as List?)?.cast<String>() ?? [],
      isPremium: (json["is_premium"] as bool?) ?? false,
    );
  }
  
  // Helper method to check if user is a seller
  bool get isSeller => role == UserRole.seller;
  
  // Helper method to check if user is a buyer
  bool get isBuyer => role == UserRole.buyer;
  
  // Copy with method for updating user data
  AppUser copyWith({
    String? name,
    String? email,
    Gender? gender,
    UserRole? role,
    List<String>? storeIds,
    bool? isPremium,
  }) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      storeIds: storeIds ?? this.storeIds,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
