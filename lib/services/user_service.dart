import 'dart:convert';

import 'package:http/http.dart' as http;
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
}
