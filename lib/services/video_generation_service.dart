import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_runtime.dart';

class VideoGenerationService {
  final String baseUrl;

  VideoGenerationService({String? baseUrl}) 
      : baseUrl = baseUrl ?? ApiRuntime.baseUrl;

  /// Generate video from image using Kling AI
  /// Returns URL of the generated video
  Future<String> generateVideo({
    required String imageUrl,
    String? prompt,
    String duration = "5",
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/video/generate');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_url': imageUrl,
          'prompt': prompt,
          'duration': duration,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Fal.ai Kling response structure check
        // Usually returns { "video": { "url": "..." } } or similar
        // Let's assume standard Fal response pattern validation
        
        if (data is Map) {
            // Check for 'video' object
            if (data['video'] != null && data['video']['url'] != null) {
                return data['video']['url'];
            }
            if (data['url'] != null) return data['url'];
        }
        
        throw Exception('Invalid response format: $data');
      } else {
        throw Exception('Server error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate video: $e');
    }
  }
}
