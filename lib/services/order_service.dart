import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/models/order.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  Future<http.Response> _authGet(Uri uri) =>
      AuthService.instance.authorizedRequest(
        (h) => http.get(uri, headers: h).timeout(ApiConfig.timeout),
      );

  Future<http.Response> _authPost(Uri uri, {Object? body}) =>
      AuthService.instance.authorizedRequest(
        (h) =>
            http.post(uri, headers: h, body: body).timeout(ApiConfig.timeout),
      );

  Map<String, dynamic> _decodeMap(http.Response res) {
    if (res.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'message': decoded.toString()};
    } catch (_) {
      return <String, dynamic>{
        'message': 'Phản hồi không hợp lệ từ máy chủ (${res.statusCode})',
      };
    }
  }

  Never _throwApi(http.Response res, String fallback) {
    final body = _decodeMap(res);
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) {
      throw Exception(msg.map((e) => e.toString()).join('\n'));
    }
    if (msg is String && msg.trim().isNotEmpty) {
      throw Exception(msg);
    }
    if (res.statusCode == 401) {
      throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    }
    throw Exception('$fallback (${res.statusCode})');
  }

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
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Không tạo được đơn hàng');
  }

  Future<OrderItem> getOrder(int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId');
    final res = await _authGet(uri);
    if (res.statusCode != 200) {
      _throwApi(res, 'Không tải được đơn hàng');
    }
    return OrderItem.fromJson(_decodeMap(res));
  }

  Future<List<OrderItem>> getMyOrders() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/my');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OrderItem.fromJson)
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
    final res = await _authPost(
      uri,
      body: jsonEncode({
        'paymentMethod': paymentMethod,
        'deliveryMethod': deliveryMethod,
        if (shippingAddress != null && shippingAddress.isNotEmpty)
          'shippingAddress': shippingAddress,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Không đổi được phương thức');
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
      if (bytes.isEmpty) {
        throw Exception('Ảnh xác nhận trống — vui lòng chụp lại');
      }
      // Android camera thường trả path không có đuôi / mimetype → server từ chối.
      final rawName = proofImage.name.trim();
      final lower = rawName.toLowerCase();
      final hasExt = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');
      final filename = hasExt ? rawName : 'receipt.jpg';
      final mime = proofImage.mimeType;
      final contentType = (mime != null && mime.startsWith('image/'))
          ? MediaType.parse(mime)
          : MediaType('image', 'jpeg');

      req.files.add(
        http.MultipartFile.fromBytes(
          'proof',
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }

    final res = await AuthService.instance.authorizedRequest(send);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Không hoàn tất được đơn hàng');
  }

  Future<OrderItem> cancelOrder(int orderId, {String reason = 'Hủy đơn'}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/cancel');
    final res = await _authPost(
      uri,
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Không hủy được đơn');
  }

  Future<OrderItem> reportDispute({
    required int orderId,
    required String type,
    String note = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/dispute');
    final res = await _authPost(
      uri,
      body: jsonEncode({'type': type, 'note': note}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Không gửi được khiếu nại');
  }

  Future<OrderItem> _postAction(int orderId, String action) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/$action');
    final res = await _authPost(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderItem.fromJson(_decodeMap(res));
    }
    _throwApi(res, 'Thao tác thất bại');
  }

  Future<List<SoldListing>> getSoldProducts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me/sold-products');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SoldListing.fromJson)
        .toList();
  }

  Future<List<SoldListing>> getUserListings(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$userId/listings');
    final res = await _authGet(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SoldListing.fromJson)
        .toList();
  }
}
