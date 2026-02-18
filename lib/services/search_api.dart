import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchApi {
  final String baseUrl;
  SearchApi({required this.baseUrl});

  Future<Map<String, dynamic>> searchCatalog({
    required String q,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/search/catalog').replace(queryParameters: {
      'q': q,
      'limit': '$limit',
      'offset': '$offset',
    });

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Catalog search failed: ${r.statusCode} ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchInternet({
    required String q,
    int start = 1,
    int num = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/search/internet').replace(queryParameters: {
      'q': q,
      'start': '$start',
      'num': '$num',
    });

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Internet search failed: ${r.statusCode} ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}