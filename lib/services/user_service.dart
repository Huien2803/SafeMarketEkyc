import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/models/user_profile.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  /// Lấy profile của user đang đăng nhập (yêu cầu JWT trong header).
  Future<UserProfile> getMyProfile() async {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      throw AuthException('Chưa đăng nhập', statusCode: 401);
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me');
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeout);

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 401) {
        await AuthService.instance.logout();
        throw AuthException(
          'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
          statusCode: 401,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UserProfile.fromJson(decoded);
      }

      final msg = decoded['message'];
      throw AuthException(
        msg is String ? msg : 'Lỗi tải hồ sơ (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Không kết nối được server: $e');
    }
  }

  /// Profile public của user khác (trust score, eKYC…).
  Future<UserProfile> getProfile(int userId) async {
    final token = AuthService.instance.accessToken;
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$userId');
    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      throw AuthException('Không tải được hồ sơ user $userId');
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserProfile> updateMyProfile({
    String? displayName,
    String? phoneNumber,
    String? location,
    String? avatarUrl,
  }) async {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      throw AuthException('Chưa đăng nhập', statusCode: 401);
    }

    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (location != null) body['location'] = location;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me');
    final response = await http
        .put(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);

    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserProfile.fromJson(decoded);
    }

    final msg = decoded['message'];
    throw AuthException(
      msg is String ? msg : 'Không cập nhật được hồ sơ',
      statusCode: response.statusCode,
    );
  }

  /// Tải ảnh đại diện (file thật) lên server, trả về profile đã cập nhật.
  Future<UserProfile> uploadAvatar(XFile image) async {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      throw AuthException('Chưa đăng nhập', statusCode: 401);
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me/avatar');

    // Đọc bytes thay vì path để chạy được cả trên web (path là blob URL).
    final bytes = await image.readAsBytes();
    final name = (image.name).toLowerCase();
    final declaredMime = image.mimeType?.toLowerCase();
    final MediaType mime;
    if (declaredMime != null && declaredMime.startsWith('image/')) {
      final parts = declaredMime.split('/');
      mime = MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
    } else if (name.endsWith('.png')) {
      mime = MediaType('image', 'png');
    } else if (name.endsWith('.webp')) {
      mime = MediaType('image', 'webp');
    } else {
      mime = MediaType('image', 'jpeg');
    }

    final ext = mime.subtype == 'png'
        ? 'png'
        : mime.subtype == 'webp'
            ? 'webp'
            : 'jpg';

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: name.isNotEmpty ? name : 'avatar.$ext',
          contentType: mime,
        ),
      );

    try {
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return UserProfile.fromJson(decoded);
      }
      final msg = decoded['message'];
      throw AuthException(
        msg is String ? msg : 'Không tải được ảnh đại diện',
        statusCode: res.statusCode,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Không kết nối được server: $e');
    }
  }
}
