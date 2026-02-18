import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // [NEW] For MediaType
import 'dart:convert';
import 'package:path/path.dart' as path; // [NEW] For extension
import '../models/clothing_item.dart';
import '../models/consultant_response.dart';

import '../config/app_config.dart';

class BackendApiService {
  final String baseUrl;
  
  BackendApiService({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.backendBaseUrl {
    print('🔌 BackendApiService initialized with URL: ${this.baseUrl}');
  }
  
  /// Check if backend is available
  Future<bool> checkStatus() async {
    try {
      print('📡 Checking backend status at: $baseUrl/api/v1/consultant/status');
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/consultant/status'),
      ).timeout(const Duration(seconds: 10));  // Increased timeout
      
      print('📥 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isConfigured = data['status'] == 'configured';
        print('✅ Backend Configured: $isConfigured');
        return isConfigured;
      }
      return false;
    } catch (e) {
      print('❌ Backend status check failed: $e');
      return false;
    }
  }
  
  /// Ask the AI consultant a question
  Future<ConsultantResponse> askConsultant({
    required String query,
    required List<ClothingItem> wardrobe,
    required List<ClothingItem> marketplace,
    required String gender,
    required String language,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      print('🔄 Sending question to backend: ${query.substring(0, query.length > 50 ? 50 : query.length)}... (Gender: $gender)');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/consultant/ask'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'question': query,
          'context': {
            'wardrobe': wardrobe.map((item) => {
              'id': item.id,
              'name': item.name,
              'category': item.category,
              'color': item.colors.isNotEmpty ? item.colors.first : 'Unknown',
            }).toList(),
            'marketplace': marketplace.map((item) => {
              'id': item.id,
              'name': item.name,
              'category': item.category,
              'price': item.price,
            }).toList(),
            'gender': gender,
          },
          'history': history,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 60));  // Increased timeout for AI requests
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          print('✅ Received response from backend');
          
          List<Map<String, dynamic>> images = [];
          if (data['images'] != null) {
            images = List<Map<String, dynamic>>.from(data['images']);
          }

          return ConsultantResponse.gemini(
            text: data['answer'],
            products: [], // Can be enhanced later
            images: images,
          );
        } else {
          // Backend returned fallback
          return ConsultantResponse.fallback(
            data['fallback'] ?? 'Ошибка сервера',
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Backend API error: $e');
      return ConsultantResponse.fallback(
        'Не могу подключиться к серверу.\n\n'
        'Попробуйте простые вопросы или проверьте, что backend запущен.',
      );
    }
  }
  
  /// Ask the AI consultant a question with an image
  Future<ConsultantResponse> askConsultantWithImage({
    required String query,
    required String imagePath,
    required List<ClothingItem> wardrobe,
    required List<ClothingItem> marketplace,
    required String gender,
    required String language,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      print('🔄 Sending question with image to backend: ${query.isEmpty ? "(no text)" : query.substring(0, query.length > 50 ? 50 : query.length)}...');
      
      final uri = Uri.parse('$baseUrl/api/v1/consultant/ask_with_image');
      final request = http.MultipartRequest('POST', uri);
      
      // 1. Add Text Fields
      request.fields['question'] = query.isEmpty 
          ? (language == 'ru' ? 'Что ты думаешь об этом образе?' : 'What do you think about this outfit?') 
          : query;
      request.fields['language'] = language;
      
      // 2. Add JSON Fields (Context + History)
      final contextData = {
        'wardrobe': wardrobe.map((item) => {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'color': item.colors.isNotEmpty ? item.colors.first : 'Unknown',
        }).toList(),
        'marketplace': marketplace.map((item) => {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'price': item.price,
        }).toList(),
        'gender': gender,
      };
      
      request.fields['context'] = jsonEncode(contextData);
      request.fields['history'] = jsonEncode(history);
      
      // 3. Add Image File
      if (imagePath.isNotEmpty) {
        final extension = path.extension(imagePath).toLowerCase().replaceAll('.', '');
        final contentType = MediaType('image', extension == 'png' ? 'png' : 'jpeg');
        
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: contentType,
        ));
      }
      
      // 4. Send Request
      final stream = await request.send().timeout(const Duration(seconds: 120)); // High timeout for image upload + AI processing
      final response = await http.Response.fromStream(stream);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          print('✅ Received response from backend (with image)');
          
          List<Map<String, dynamic>> images = [];
          if (data['images'] != null) {
            images = List<Map<String, dynamic>>.from(data['images']);
          }

          return ConsultantResponse.gemini(
            text: data['answer'],
            products: [],
            images: images,
          );
        } else {
          return ConsultantResponse.fallback(
            data['fallback'] ?? 'Ошибка сервера',
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ Backend API error (with image): $e');
      return ConsultantResponse.fallback(
        'Не могу отправить изображение.\n\n'
        'Проверьте соединение с сервером.',
      );
    }
  }
}
