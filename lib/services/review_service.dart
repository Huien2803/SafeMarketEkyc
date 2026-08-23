import 'dart:convert';

import 'package:safemarket_app/models/review.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return ApiConfig.jsonHeaders(token: token);
  }

  Future<ReviewItem> submitReview({
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    final res = await ApiConfig.httpPost(
      '/reviews',
      headers: _headers,
      body: ApiConfig.encodeBody({
        'orderId': orderId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ReviewItem.fromJson(body as Map<String, dynamic>);
    }
    throw Exception(_messageFromBody(body));
  }

  String _messageFromBody(dynamic body) {
    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is List) return msg.join(', ');
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Không gửi được đánh giá (${body is Map ? body.toString() : 'lỗi API'})';
  }

  Future<OrderReviewStatus> getOrderReviewStatus(int orderId) async {
    final res = await ApiConfig.httpGet(
      '/reviews/order/$orderId/status',
      headers: _headers,
    );
    if (res.statusCode != 200) {
      return const OrderReviewStatus(
        canReview: false,
        buyerReviewed: false,
        sellerReviewed: false,
        revieweeId: 0,
        revieweeName: null,
      );
    }
    return OrderReviewStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<ReviewItem>> getUserReviews(int userId) async {
    final res = await ApiConfig.httpGet('/reviews/user/$userId');
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
