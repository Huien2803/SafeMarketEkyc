import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/wallet.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Ví người bán: xem số dư, lịch sử giao dịch và rút tiền về ngân hàng.
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  Map<String, String> get _headers => AuthService.instance.authHeaders;

  Future<http.Response> _get(Uri uri) => AuthService.instance.authorizedRequest(
        (h) => http.get(uri, headers: h).timeout(ApiConfig.timeout),
      );

  Future<http.Response> _post(Uri uri, {Object? body}) =>
      AuthService.instance.authorizedRequest(
        (h) => http
            .post(uri, headers: h, body: body)
            .timeout(ApiConfig.timeout),
      );

  Future<WalletInfo> getWallet() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/wallet');
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw Exception('Không tải được ví');
    }
    return WalletInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<WithdrawalItem>> getWithdrawals() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/wallet/withdrawals');
    final res = await _get(uri);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => WithdrawalItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> requestWithdrawal({
    required int amount,
    required String bankName,
    required String bankAccount,
    required String accountHolder,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/wallet/withdrawals');
    final res = await _post(
      uri,
      body: jsonEncode({
        'amount': amount,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'accountHolder': accountHolder,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final formatted = body['newBalanceFormatted'] as String?;
      return formatted != null
          ? 'Đã gửi yêu cầu rút tiền (chờ admin duyệt). Số dư còn lại: $formatted'
          : 'Đã gửi yêu cầu rút tiền — chờ admin duyệt.';
    }
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) throw Exception(msg.join('\n'));
    throw Exception(msg is String ? msg : 'Rút tiền thất bại');
  }
}
