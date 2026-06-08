import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<void> createReport({
    required int reportedId,
    required String reason,
    int? productId,
    String severity = 'medium',
  }) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập để báo cáo');

    final uri = Uri.parse('${ApiConfig.baseUrl}/reports');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'reportedId': reportedId,
            'reason': reason,
            if (productId != null) 'productId': productId,
            'severity': severity,
          }),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Không gửi được báo cáo');
    }
  }
}
