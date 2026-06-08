import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/review.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ReviewItem> submitReview({
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/reviews');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'orderId': orderId,
            'rating': rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          }),
        )
        .timeout(ApiConfig.timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ReviewItem.fromJson(body);
    }
    throw Exception(body['message'] ?? 'Không gửi được đánh giá');
  }

  Future<OrderReviewStatus> getOrderReviewStatus(int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/reviews/order/$orderId/status');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      return const OrderReviewStatus(
        canReview: false,
        buyerReviewed: false,
        sellerReviewed: false,
        revieweeId: 0,
      );
    }
    return OrderReviewStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<ReviewItem>> getUserReviews(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/reviews/user/$userId');
    final res = await http.get(uri).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
