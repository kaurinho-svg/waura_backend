// lib/services/nano_banana_api.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// Thrown when backend returns 402 (not enough credits)
class InsufficientCreditsException implements Exception {
  const InsufficientCreditsException();
  @override
  String toString() => 'InsufficientCreditsException';
}

class NanoBananaApi {
  final http.Client _client;
  NanoBananaApi({http.Client? client}) : _client = client ?? http.Client();

  // ✅ apiBase уже содержит /api/v1
  Uri _uri(String path) => Uri.parse("${AppConfig.apiBase}$path");

  /// POST /nano-banana/upload-temp
  /// Возвращает: {"url": "...public url..."}
  Future<String> uploadTemp(XFile file) async {
    final req = http.MultipartRequest("POST", _uri("/nano-banana/upload-temp"));
    // Force close connection to avoid socket pooling issues (Semaphore timeout fix)
    req.headers["Connection"] = "close";

    final filename = file.name.isNotEmpty ? file.name : "upload.bin";

    if (kIsWeb) {
      final Uint8List bytes = await file.readAsBytes();
      req.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: filename,
          contentType: _guessContentType(filename),
        ),
      );
    } else {
      req.files.add(
        await http.MultipartFile.fromPath(
          "file",
          file.path,
          filename: filename,
          contentType: _guessContentType(filename),
        ),
      );
    }

    // Increase timeout for large files (Windows Socket issue workaround)
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final resp = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 120));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("upload-temp failed: ${resp.statusCode} ${resp.body}");
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = data["url"]?.toString();
    if (url == null || url.isEmpty) {
      throw Exception("upload-temp: server didn't return url. Body=${resp.body}");
    }
    return url;
  }

  /// POST /nano-banana/edit — costs 2 credits
  Future<Map<String, dynamic>> edit({
    required String user_image_url,
    required String clothing_image_url,
    required String style_prompt,
    String? user_id,
    bool is_premium = false,
  }) async {
    final resp = await _client.post(
      _uri("/nano-banana/edit"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_image_url": user_image_url,
        "clothing_image_url": clothing_image_url,
        "style_prompt": style_prompt,
        "is_premium": is_premium,
        if (user_id != null) "user_id": user_id,
      }),
    ).timeout(const Duration(minutes: 5));

    if (resp.statusCode == 402) {
      throw InsufficientCreditsException();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("edit failed: ${resp.statusCode} ${resp.body}");
    }

    return (jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// POST /nano-banana/video-tryon — costs 10 credits
  Future<Map<String, dynamic>> videoTryOn({
    required String user_image_url,
    required String clothing_image_url,
    required String style_prompt,
    String? user_id,
  }) async {
    final resp = await _client.post(
      _uri("/nano-banana/video-tryon"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_image_url": user_image_url,
        "clothing_image_url": clothing_image_url,
        "style_prompt": style_prompt,
        if (user_id != null) "user_id": user_id,
      }),
    ).timeout(const Duration(minutes: 10));

    if (resp.statusCode == 402) {
      throw InsufficientCreditsException();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("video-tryon failed: ${resp.statusCode} ${resp.body}");
    }

    return (jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// GET /nano-banana/credits?user_id=...
  Future<Map<String, dynamic>> getCredits(String userId) async {
    final uri = Uri.parse("${AppConfig.apiBase}/nano-banana/credits?user_id=$userId");
    final resp = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("getCredits failed: ${resp.statusCode}");
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Пытаемся достать итоговую картинку из ответа
  String? extractResultImageUrl(Map<String, dynamic> result) {
    final images = result["images"];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first["url"] != null) return first["url"].toString();
      if (first is String) return first;
    }

    final image = result["image"];
    if (image is Map && image["url"] != null) return image["url"].toString();

    final output = result["output"];
    if (output is Map && output["url"] != null) return output["url"].toString();

    if (result["url"] != null) return result["url"].toString();

    return null;
  }

  MediaType _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".png")) return MediaType("image", "png");
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      return MediaType("image", "jpeg");
    }
    if (lower.endsWith(".webp")) return MediaType("image", "webp");
    return MediaType("application", "octet-stream");
  }
}
