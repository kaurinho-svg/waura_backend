import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_runtime.dart';
import '../data/mock_styles.dart';

class StyleSearchApi {
  static Future<List<StyleInspiration>> searchStyles({
    required String gender,
    required String category,
  }) async {
    final String baseUrl = ApiRuntime.baseUrl;
    // Fix: Add /api/v1 prefix
    final Uri uri = Uri.parse('$baseUrl/api/v1/styles/search').replace(queryParameters: {
      'gender': gender,
      'category': category,
      'limit': '20',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List items = data['items'];

        return items.map((json) => StyleInspiration(
          imageUrl: json['imageUrl'],
          title: json['title'] ?? category,
          category: category,
          tags: List<String>.from(json['tags'] ?? []),
        )).toList();
      } else {
        throw Exception('Failed to load styles: ${response.statusCode}');
      }
    } catch (e) {
      print('Style Search Error: $e');
      throw e;
    }
  }
}
