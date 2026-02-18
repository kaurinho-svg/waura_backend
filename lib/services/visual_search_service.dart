import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_runtime.dart';

class VisualSearchService {
  final String baseUrl;

  VisualSearchService({String? baseUrl}) 
      : baseUrl = baseUrl ?? ApiRuntime.baseUrl;

  /// Analyze an image (Base64) and get clothing items
  Future<List<VisualSearchItem>> analyzeImage(String base64Image) async {
    final uri = Uri.parse('$baseUrl/api/v1/visual-search/analyze');

    try {
      final response = await http.post(
        uri,
        // Removed Content-Type application/json to allow default Form UrlEncoded
        body: {'image_b64': base64Image},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List items = data['items'];
        
        return items.map((json) => VisualSearchItem.fromJson(json)).toList();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
  /// Auto-tag a single clothing item
  Future<AutoTagResult> autoTagClothing(String base64Image, {String locale = 'en'}) async {
    final uri = Uri.parse('$baseUrl/api/v1/visual-search/auto-tag');

    try {
      final response = await http.post(
        uri,
        body: {
          'image_b64': base64Image,
          'language': locale,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AutoTagResult.fromJson(data);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to auto-tag: $e');
    }
  }
}

class AutoTagResult {
  final String name;
  final String category;
  final String subCategory;
  final String color;
  final List<String> season;
  final List<String> style;
  final List<String> tags;

  AutoTagResult({
    this.name = '',
    this.category = 'other',
    this.subCategory = '',
    this.color = '',
    this.season = const [],
    this.style = const [],
    this.tags = const [],
  });

  factory AutoTagResult.fromJson(Map<String, dynamic> json) {
    return AutoTagResult(
      name: json['name'] ?? '',
      category: json['category'] ?? 'other',
      subCategory: json['subCategory'] ?? '',
      color: json['color'] ?? '',
      season: (json['season'] as List?)?.map((e) => e.toString()).toList() ?? [],
      style: (json['style'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

}

class VisualSearchItem {
  final String name;
  final String category;
  final String color;
  final String brand;
  final String description;

  VisualSearchItem({
    required this.name,
    required this.category,
    required this.color,
    this.brand = '',
    required this.description,
  });

  factory VisualSearchItem.fromJson(Map<String, dynamic> json) {
    return VisualSearchItem(
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      color: json['color'] ?? '',
      brand: json['brand'] ?? '',
      description: json['description'] ?? '',
    );
  }
  
  // Helper to create a search query for Marketplace
  // If brand is known, include it for better results!
  String get searchQuery {
    if (brand.isNotEmpty && brand.toLowerCase() != 'unknown') {
      return '$brand $color $name $category'.trim();
    }
    return '$color $name $category'.trim();
  }
}
