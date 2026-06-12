import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ChatUploadService {
  ChatUploadService._();
  static final ChatUploadService instance = ChatUploadService._();

  Future<String> uploadChatImage(XFile image) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập');

    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/upload-image');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    final bytes = await image.readAsBytes();
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name,
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final url = body['imageUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Không nhận được URL ảnh');
      }
      return url;
    }
    throw Exception(body['message'] ?? 'Không gửi được ảnh');
  }
}
