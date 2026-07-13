import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/models/order.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  Map<String, String> get _headers => AuthService.instance.authHeaders;

  Future<http.Response> _authGet(Uri uri) =>
      AuthService.instance.authorizedRequest(
        (h) => http.get(uri, headers: h).timeout(ApiConfig.timeout),
      );

  Future<http.Response> _authPost(Uri uri, {Object? body}) =>
      AuthService.instance.authorizedRequest(
        (h) =>
            http.post(uri, headers: h, body: body).timeout(ApiConfig.timeout),
      );

  Future<OrderItem> createOrder({
    required int productId,
    required String shippingAddress,
    String paymentMethod = 'CASH',
    String deliveryMethod = 'DIRECT',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders');
    final res = await _authPost(
      uri,
      body: jsonEncode({
        'productId': productId,
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'deliveryMethod': deliveryMethod,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    if (res.statusCode >= 500) {
      throw Exception('Không tạo được đơn hàng. Vui lòng thử lại sau.');
    }
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) {
      throw Exception(msg.join('\n'));
    }
    throw Exception(msg is String ? msg : 'Không tạo được đơn hàng (${res.statusCode})');
  }

  Future<OrderItem> getOrder(int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId');
    final res = await _authGet(uri);
    if (res.statusCode != 200) {
      throw Exception('Không tải được đơn hàng');
    }
    return OrderItem.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<OrderItem>> getMyOrders() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/my');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderItem>> getMyPurchases() async {
    final myId = AuthService.instance.currentUser?.userId;
    if (myId == null) return [];
    final all = await getMyOrders();
    return all.where((o) => o.buyerId == myId).toList();
  }

  Future<List<OrderItem>> getMySales() async {
    final myId = AuthService.instance.currentUser?.userId;
    if (myId == null) return [];
    final all = await getMyOrders();
    return all.where((o) => o.sellerId == myId).toList();
  }

  /// Người mua đổi phương thức thanh toán / giao hàng khi đơn còn Pending.
  Future<OrderItem> changePaymentMethod(
    int orderId, {
    required String paymentMethod,
    required String deliveryMethod,
    String? shippingAddress,
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/payment-method');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
            if (shippingAddress != null && shippingAddress.isNotEmpty)
              'shippingAddress': shippingAddress,
          }),
        )
        .timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) throw Exception(msg.join('\n'));
    throw Exception(msg is String ? msg : 'Không đổi được phương thức');
  }

  Future<OrderItem> markShipped(int orderId) async =>
      _postAction(orderId, 'ship');

  Future<OrderItem> markPaymentReceived(int orderId) async =>
      _postAction(orderId, 'confirm-payment');

  Future<OrderItem> markDirectHandover(int orderId) async =>
      _postAction(orderId, 'confirm-handover');

  /// Người mua xác nhận đã nhận hàng kèm ảnh bằng chứng (bắt buộc).
  Future<OrderItem> markCompleted(int orderId, {required XFile proofImage}) async {
    Future<http.Response> send(Map<String, String> headers) async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/complete');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json';
      final auth = headers['Authorization'];
      if (auth != null) req.headers['Authorization'] = auth;

      final bytes = await proofImage.readAsBytes();
      req.files.add(
        http.MultipartFile.fromBytes(
          'proof',
          bytes,
          filename: proofImage.name.isNotEmpty ? proofImage.name : 'receipt.jpg',
        ),
      );

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }

    final res = await AuthService.instance.authorizedRequest(send);
    final body = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) {
      throw Exception(msg.join('\n'));
    }
    throw Exception(msg is String ? msg : 'Không hoàn tất được đơn hàng');
  }

  Future<OrderItem> cancelOrder(int orderId, {String reason = 'Hủy đơn'}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/cancel');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'reason': reason}),
        )
        .timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    throw Exception(body['message'] ?? 'Không hủy được đơn');
  }

  Future<OrderItem> reportDispute({
    required int orderId,
    required String type,
    String note = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/dispute');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'type': type, 'note': note}),
        )
        .timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    throw Exception(body['message'] ?? 'Không gửi được khiếu nại');
  }

  Future<OrderItem> _postAction(int orderId, String action) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/$action');
    final res = await _authPost(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(body);
    }
    throw Exception(body['message'] ?? 'Thao tác thất bại');
  }

  Future<List<SoldListing>> getSoldProducts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me/sold-products');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => SoldListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SoldListing>> getUserListings(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$userId/listings');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => SoldListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
