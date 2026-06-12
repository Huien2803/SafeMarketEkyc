import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/auth_user.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exception riêng cho lỗi gọi API (dễ catch trong UI).
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// Service xử lý đăng ký, đăng nhập, lưu/đọc JWT token.
///
/// Token được lưu trong SharedPreferences (đơn giản, đủ cho KLTN).
/// Production thật nên dùng `flutter_secure_storage`.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kTokenKey = 'safemarket.access_token';
  static const _kUserKey = 'safemarket.user_json';

  String? _accessToken;
  AuthUser? _currentUser;

  String? get accessToken => _accessToken;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Đọc token đã lưu từ disk khi app khởi động.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kTokenKey);
    final userJson = prefs.getString(_kUserKey);
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _currentUser = null;
        _accessToken = null;
      }
    }
    notifyListeners();
  }

  Future<AuthResponse> register({
    required String phoneNumber,
    required String email,
    required String password,
    String? displayName,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'email': email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (location != null && location.isNotEmpty) 'location': location,
    };

    final res = await _postJson('/auth/register', body);
    return _finishAuth(res);
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    // Java API: LoginRequest { email, password }
    final body = <String, dynamic>{
      'email': identifier.trim(),
      'password': password,
    };
    final res = await _postJson('/auth/login', body);
    return _finishAuth(res);
  }

  Future<AuthResponse> _finishAuth(Map<String, dynamic> res) async {
    try {
      final auth = AuthResponse.fromJson(res);
      await _persist(auth);
      return auth;
    } on FormatException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final message = _extractError(decoded);
      throw AuthException(message, statusCode: response.statusCode);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Không kết nối được server: $e\nKiểm tra backend đã chạy và URL: $uri',
      );
    }
  }

  String _extractError(Map<String, dynamic> body) {
    final raw = body['message'];
    if (raw is String) return raw;
    if (raw is List && raw.isNotEmpty) return raw.join('\n');
    return body['error'] as String? ?? 'Lỗi không xác định';
  }

  Future<void> _persist(AuthResponse auth) async {
    _accessToken = auth.accessToken;
    _currentUser = auth.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, auth.accessToken);
    await prefs.setString(_kUserKey, jsonEncode(auth.user.toJson()));
    notifyListeners();
  }

  /// Cập nhật thông tin user trong bộ nhớ sau khi sửa hồ sơ.
  Future<void> updateCachedUser({
    String? displayName,
    String? phoneNumber,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = AuthUser(
      userId: user.userId,
      email: user.email,
      phoneNumber: phoneNumber ?? user.phoneNumber,
      displayName: displayName ?? user.displayName,
      kycStatus: user.kycStatus,
      accountStatus: user.accountStatus,
      isAdmin: user.isAdmin,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }
}
