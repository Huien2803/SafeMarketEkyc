import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentCheckoutResult {
  const PaymentCheckoutResult({
    required this.devMode,
    this.paymentUrl,
    this.txnRef,
    this.message,
  });

  final bool devMode;
  final String? paymentUrl;
  final String? txnRef;
  final String? message;

  factory PaymentCheckoutResult.fromJson(Map<String, dynamic> json) {
    return PaymentCheckoutResult(
      devMode: json['devMode'] as bool? ?? false,
      paymentUrl: json['paymentUrl'] as String?,
      txnRef: json['txnRef'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Thanh toán online escrow qua VNPay (hoặc demo dev).
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Map<String, String> get _headers => AuthService.instance.authHeaders;

  Future<PaymentCheckoutResult> checkout(int orderId) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/payments/orders/$orderId/checkout');
    final res = await AuthService.instance.authorizedRequest(
      (h) => http.post(uri, headers: h).timeout(ApiConfig.timeout),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return PaymentCheckoutResult.fromJson(body);
    }
    final msg = body['message'];
    if (msg is String) throw Exception(msg);
    if (msg is List && msg.isNotEmpty) throw Exception(msg.first.toString());
    throw Exception('Không tạo được phiên thanh toán');
  }

  Future<void> simulatePay(int orderId) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/payments/orders/$orderId/simulate-pay');
    final res = await AuthService.instance.authorizedRequest(
      (h) => http.post(uri, headers: h).timeout(ApiConfig.timeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Thanh toán demo thất bại');
    }
  }

  /// Mở VNPay trên trình duyệt / app ngân hàng.
  Future<bool> openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Checkout + mở VNPay hoặc simulate dev.
  Future<String?> payOrder(int orderId) async {
    final checkout = await checkoutOrder(orderId);
    if (checkout.devMode) {
      await simulatePay(orderId);
      return checkout.message ??
          'Đã thanh toán demo — tiền tạm giữ tại SafeMarket.';
    }
    final url = checkout.paymentUrl;
    if (url == null || url.isEmpty) {
      throw Exception('Không nhận được link thanh toán');
    }
    final opened = await openPaymentUrl(url);
    if (!opened) throw Exception('Không mở được cổng thanh toán VNPay');
    return checkout.message;
  }

  Future<PaymentCheckoutResult> checkoutOrder(int orderId) => checkout(orderId);
}
