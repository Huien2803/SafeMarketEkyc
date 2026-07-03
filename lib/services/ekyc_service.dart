import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:safemarket_app/models/ekyc_models.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Service gọi 5 endpoint eKYC của backend NestJS.
///
/// Luồng chuẩn dùng trong UI:
///   1. user chụp ảnh mặt trước CCCD  -> scanIdFront(file)  -> hiện form đã điền sẵn
///   2. user chụp ảnh mặt sau CCCD     -> scanIdBack(file)
///   3. user selfie                    -> faceMatch(idFront, selfie) -> similarity
///   4. user nhấn "Xác nhận"           -> submit(...) -> Verified
class EkycService {
  EkycService._();
  static final EkycService instance = EkycService._();

  Future<IdCardFront> scanIdFront(File image) async {
    final json = await _uploadSingle('/ekyc/scan-id-front', 'image', image);
    return IdCardFront.fromJson(json);
  }

  Future<IdCardBack> scanIdBack(File image) async {
    final json = await _uploadSingle('/ekyc/scan-id-back', 'image', image);
    return IdCardBack.fromJson(json);
  }

  Future<Map<String, dynamic>> livenessCheck(File selfie) async {
    return _uploadSingle('/ekyc/liveness-check', 'selfie', selfie);
  }

  Future<FaceMatchResult> faceMatch({
    required File idCard,
    required File selfie,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ekyc/face-match');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${_requireToken()}'
      ..files.add(await _multipart('idCard', idCard))
      ..files.add(await _multipart('selfie', selfie));

    final json = await _send(req);
    return FaceMatchResult.fromJson(json);
  }

  Future<EkycStatus> submit({
    required String idNumber,
    required String fullName,
    required String dob,
    required String address,
    required int recognitionPoints,
    required String livenessToken,
  }) async {
    final token = _requireToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/ekyc/submit');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'idNumber': idNumber,
            'fullName': fullName,
            'dob': dob,
            'address': address,
            'recognitionPoints': recognitionPoints,
            'livenessToken': livenessToken,
          }),
        )
        .timeout(ApiConfig.timeout);

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return EkycStatus.fromJson(decoded);
    }
    throw AuthException(_extractError(decoded), statusCode: res.statusCode);
  }

  Future<EkycStatus> getMyStatus() async {
    final token = _requireToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/ekyc/my-status');
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(ApiConfig.timeout);

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return EkycStatus.fromJson(decoded);
    }
    throw AuthException(_extractError(decoded), statusCode: res.statusCode);
  }

  // ---------- helpers ----------

  Future<Map<String, dynamic>> _uploadSingle(
    String path,
    String fieldName,
    File file,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${_requireToken()}'
      ..files.add(await _multipart(fieldName, file));
    return _send(req);
  }

  Future<Map<String, dynamic>> _send(http.MultipartRequest req) async {
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
      throw AuthException(_extractError(decoded), statusCode: res.statusCode);
    } on AuthException {
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
    if (raw is String) return raw;
    if (raw is List && raw.isNotEmpty) return raw.join('\n');
    return body['error'] as String? ?? 'Lỗi không xác định';
  }
}
