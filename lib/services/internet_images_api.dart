import 'dart:convert';
import 'package:http/http.dart' as http;

class InternetImagesApi {
  final String baseUrl;

  InternetImagesApi({required this.baseUrl});

  Future<Map<String, dynamic>> searchImages({
    required String q,
    int start = 1,
    int num = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/search/images').replace(queryParameters: {
      'q': q,
      'start': '$start',
      'num': '$num',
    });

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}