import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<int> openThread({
    required int sellerId,
    int? productId,
    int? orderId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/open');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'sellerId': sellerId,
            if (productId != null) 'productId': productId,
            if (orderId != null) 'orderId': orderId,
          }),
        )
        .timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['threadId'] as num).toInt();
    }
    throw Exception(body['message'] ?? 'Không mở được chat');
  }

  Future<ChatThreadDetail> getThreadDetail(int threadId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/threads/$threadId');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Không tải được hội thoại');
    }
    return ChatThreadDetail.fromJson(body);
  }

  Future<List<ChatThread>> getThreads() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/threads');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessage>> getMessages(int threadId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/threads/$threadId/messages');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SendMessageResult> sendMessage(int threadId, String body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/threads/$threadId/messages');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'body': body}),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['message'] ?? 'Gửi tin thất bại');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      final list = (decoded['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return SendMessageResult(
        messages: list,
        scamWarning: decoded['scamWarning'] as String?,
      );
    }
    final list = (decoded as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return SendMessageResult(messages: list);
  }

  Future<List<ChatMessage>> sendPurchaseRequest(
    int threadId,
    String shippingAddress, {
    String paymentMethod = 'BANK_TRANSFER',
    String deliveryMethod = 'SHIP',
  }) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/chat/threads/$threadId/purchase-request');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'shippingAddress': shippingAddress,
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
          }),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['message'] ?? 'Không gửi yêu cầu mua');
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessage>> confirmSale(int threadId, int messageId) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/chat/threads/$threadId/confirm-sale');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'messageId': messageId}),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['message'] ?? 'Không xác nhận được');
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class SendMessageResult {
  const SendMessageResult({required this.messages, this.scamWarning});

  final List<ChatMessage> messages;
  final String? scamWarning;
}
