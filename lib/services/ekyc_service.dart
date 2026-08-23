import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:safemarket_app/models/ekyc_models.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Client eKYC — luồng gắn session server (kiểu ngân hàng / VNeID):
///   startSession → scanFront → scanBack → completeLiveness → faceMatch → submit
class EkycService {
  EkycService._();
  static final EkycService instance = EkycService._();

  Future<String> startSession() async {
    final json = await _postJson('/ekyc/session/start', {});
    return (json['sessionId'] ?? '').toString();
  }

  Future<IdCardFront> scanIdFront({
    required String sessionId,
    required File image,
  }) async {
    final json = await _uploadWithFields(
      '/ekyc/scan-id-front',
      'image',
      image,
      fields: {'sessionId': sessionId},
    );
    return IdCardFront.fromJson(json);
  }

  Future<IdCardBack> scanIdBack({
    required String sessionId,
    required File image,
  }) async {
    final json = await _uploadWithFields(
      '/ekyc/scan-id-back',
      'image',
      image,
      fields: {'sessionId': sessionId},
    );
    return IdCardBack.fromJson(json);
  }

  Future<({String livenessToken, int recognitionPoints})> completeLiveness({
    required String sessionId,
    required File selfie,
    required int recognitionPoints,
  }) async {
    final json = await _uploadWithFields(
      '/ekyc/liveness/complete',
      'selfie',
      selfie,
      fields: {
        'sessionId': sessionId,
        'recognitionPoints': '$recognitionPoints',
      },
    );
    return (
      livenessToken: (json['livenessToken'] ?? '').toString(),
      recognitionPoints: (json['recognitionPoints'] as num?)?.toInt() ??
          recognitionPoints,
    );
  }

  Future<FaceMatchResult> faceMatch({
    required String sessionId,
    File? idCard,
    File? selfie,
  }) async {
    final json = await ApiConfig.withFailover((base) async {
      final uri = Uri.parse('$base/ekyc/face-match');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_requireToken()}'
        ..fields['sessionId'] = sessionId;
      if (idCard != null) {
        req.files.add(await _multipart('idCard', idCard));
      }
      if (selfie != null) {
        req.files.add(await _multipart('selfie', selfie));
      }
      return _send(req);
    });
    return FaceMatchResult.fromJson(json);
  }

  Future<EkycStatus> submit({
    required String sessionId,
    required String livenessToken,
    required String dob,
    required String address,
    String? home,
  }) async {
    final decoded = await _postJson('/ekyc/submit', {
      'sessionId': sessionId,
      'livenessToken': livenessToken,
      'dob': dob,
      'address': address,
      if (home != null && home.isNotEmpty) 'home': home,
    });
    return EkycStatus.fromJson(decoded);
  }

  Future<EkycStatus> getMyStatus() async {
    final token = _requireToken();
    final res = await ApiConfig.httpGet(
      '/ekyc/my-status',
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return EkycStatus.fromJson(decoded);
    }
    throw AuthException(_extractError(decoded), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiConfig.httpPost(
      path,
      headers: ApiConfig.jsonHeaders(token: _requireToken()),
      body: ApiConfig.encodeBody(body),
    );
    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw AuthException(_extractError(decoded), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _uploadWithFields(
    String path,
    String fieldName,
    File file, {
    Map<String, String> fields = const {},
  }) async {
    return ApiConfig.withFailover((base) async {
      final uri = Uri.parse('$base$path');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${_requireToken()}'
        ..fields.addAll(fields)
        ..files.add(await _multipart(fieldName, file));
      return _send(req);
    });
  }

  Future<Map<String, dynamic>> _send(http.MultipartRequest req) async {
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
      throw AuthException(_extractError(decoded), statusCode: res.statusCode);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      rethrow; // để withFailover thử host khác
    } on SocketException {
      rethrow;
    } on http.ClientException {
      rethrow;
    } catch (e) {
      throw AuthException('Không kết nối được server: $e');
    }
  }

  Future<http.MultipartFile> _multipart(String field, File file) async {
    final path = file.path.toLowerCase();
    final mime = path.endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
    return http.MultipartFile.fromPath(field, file.path, contentType: mime);
  }

  String _requireToken() {
    final t = AuthService.instance.accessToken;
    if (t == null) {
      throw AuthException('Bạn cần đăng nhập lại', statusCode: 401);
    }
    return t;
  }

  String _extractError(Map<String, dynamic> body) {
    final raw = body['message'];
    if (raw is String) return _viValidation(raw);
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => _viValidation(e.toString())).join('\n');
    }
    return body['error'] as String? ?? 'Lỗi không xác định';
  }

  String _viValidation(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('dob') && lower.contains('empty')) {
      return 'Thiếu ngày sinh — quay lại bước mặt trước CCCD và nhập ngày sinh.';
    }
    if (lower.contains('address') &&
        (lower.contains('empty') || lower.contains('longer'))) {
      return 'Thiếu địa chỉ thường trú — quay lại bước mặt trước CCCD và nhập địa chỉ.';
    }
    if (lower.contains('session')) {
      return msg;
    }
    return msg;
  }
}
