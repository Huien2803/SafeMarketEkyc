import 'dart:convert';

import 'package:safemarket_app/core/constants/report_reasons.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<void> createReport({
    required int reportedId,
    required String category,
    required String detail,
    int? productId,
    String? severity,
  }) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập để báo cáo');

    final cat = reportCategoryByCode(category);
    final res = await ApiConfig.httpPost(
      '/reports',
      headers: ApiConfig.jsonHeaders(token: token),
      body: ApiConfig.encodeBody({
        'reportedId': reportedId,
        'category': category,
        'detail': detail,
        if (productId != null) 'productId': productId,
        'severity': severity ?? cat?.severity ?? 'medium',
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = body['message'];
      if (msg is String) throw Exception(msg);
      if (msg is List && msg.isNotEmpty) throw Exception(msg.first.toString());
      throw Exception('Không gửi được báo cáo');
    }
  }
}
