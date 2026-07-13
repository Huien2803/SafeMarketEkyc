import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/auth_user.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kết quả yêu cầu OTP đăng ký.
class RegisterOtpResult {
  const RegisterOtpResult({
    required this.expiresInSeconds,
    this.devOtp,
    this.message,
  });

  final int expiresInSeconds;
  /// Có khi backend chưa cấu hình SMTP (dev) — hiển thị cho user test.
  final String? devOtp;
  final String? message;
}

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// Service xử lý đăng ký, đăng nhập, lưu/đọc JWT + refresh token.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kTokenKey = 'safemarket.access_token';
  static const _kRefreshKey = 'safemarket.refresh_token';
  static const _kUserKey = 'safemarket.user_json';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  AuthUser? _currentUser;
  Future<bool>? _refreshInFlight;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Map<String, String> get authHeaders {
    final token = _accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Đọc token đã lưu khi app khởi động (secure storage + migrate từ prefs cũ).
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = await _secure.read(key: _kTokenKey);
    _refreshToken = await _secure.read(key: _kRefreshKey);

    // Migrate từ SharedPreferences (bản cũ) sang secure storage.
    if (_accessToken == null) {
      final legacy = prefs.getString(_kTokenKey);
      if (legacy != null) {
        _accessToken = legacy;
        await _secure.write(key: _kTokenKey, value: legacy);
        await prefs.remove(_kTokenKey);
      }
    }

    final userJson = prefs.getString(_kUserKey);
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _currentUser = null;
        _accessToken = null;
        _refreshToken = null;
      }
    }
    notifyListeners();
  }

  Future<RegisterOtpResult> requestRegisterOtp({
    required String phoneNumber,
    required String email,
    required String password,
    required String displayName,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'email': email,
      'password': password,
      'displayName': displayName,
      if (location != null && location.isNotEmpty) 'location': location,
    };

    final res = await _postJson('/auth/register/request-otp', body);
    final secs = res['expiresInSeconds'];
    return RegisterOtpResult(
      expiresInSeconds: secs is int ? secs : 300,
      devOtp: res['devOtp'] as String?,
      message: res['message'] as String?,
    );
  }

  Future<AuthResponse> verifyRegisterOtp({
    required String email,
    required String otp,
  }) async {
    final res = await _postJson('/auth/register/verify-otp', {
      'email': email,
      'otp': otp,
    });
    return _finishAuth(res);
  }

  Future<RegisterOtpResult> requestPasswordResetOtp({
    required String email,
  }) async {
    final res = await _postJson('/auth/password/forgot', {'email': email});
    final secs = res['expiresInSeconds'];
    return RegisterOtpResult(
      expiresInSeconds: secs is int ? secs : 300,
      devOtp: res['devOtp'] as String?,
      message: res['message'] as String?,
    );
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final res = await _postJson('/auth/password/reset', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    return res['message'] as String? ?? 'Đặt lại mật khẩu thành công.';
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'email': identifier.trim(),
      'password': password,
    };
    final res = await _postJson('/auth/login', body);
    return _finishAuth(res);
  }

  /// Làm mới access token. Trả về false nếu refresh thất bại.
  Future<bool> refresh() async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _doRefresh();
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefresh() async {
    final rt = _refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final res = await _postJson('/auth/refresh', {'refreshToken': rt});
      await _finishAuth(res);
      return true;
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        await clearSession();
      }
      return false;
    } catch (_) {
      return false;
    }
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
    final rt = _refreshToken;
    if (rt != null && rt.isNotEmpty) {
      try {
        await _postJson('/auth/logout', {'refreshToken': rt});
      } catch (_) {
        // Vẫn xóa session local dù revoke thất bại.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    await _secure.delete(key: _kTokenKey);
    await _secure.delete(key: _kRefreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
    notifyListeners();
  }

  /// Gửi request có Bearer; nếu 401 thì refresh 1 lần rồi retry.
  Future<http.Response> authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var res = await send(authHeaders);
    if (res.statusCode != 401) return res;

    final ok = await refresh();
    if (!ok) return res;
    return send(authHeaders);
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
    if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
      _refreshToken = auth.refreshToken;
    }
    _currentUser = auth.user;

    await _secure.write(key: _kTokenKey, value: auth.accessToken);
    if (_refreshToken != null) {
      await _secure.write(key: _kRefreshKey, value: _refreshToken);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey); // không lưu access token plaintext nữa
    await prefs.setString(_kUserKey, jsonEncode(auth.user.toJson()));
    notifyListeners();
  }

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
