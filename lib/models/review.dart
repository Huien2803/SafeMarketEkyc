class ReviewItem {
  const ReviewItem({
    required this.reviewId,
    required this.orderId,
    required this.rating,
    this.comment,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.revieweeName,
    required this.createdAt,
  });

  final int reviewId;
  final int orderId;
  final int rating;
  final String? comment;
  final int reviewerId;
  final String reviewerName;
  final int revieweeId;
  final String revieweeName;
  final DateTime createdAt;

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      reviewId: (json['reviewId'] as num).toInt(),
      orderId: (json['orderId'] as num).toInt(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      reviewerId: (json['reviewerId'] as num).toInt(),
      reviewerName: json['reviewerName'] as String? ?? '',
      revieweeId: (json['revieweeId'] as num).toInt(),
      revieweeName: json['revieweeName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class OrderReviewStatus {
  const OrderReviewStatus({
    required this.canReview,
    required this.buyerReviewed,
    required this.sellerReviewed,
    required this.revieweeId,
    this.revieweeName,
  });

  final bool canReview;
  final bool buyerReviewed;
  final bool sellerReviewed;
  final int revieweeId;
  final String? revieweeName;

  factory OrderReviewStatus.fromJson(Map<String, dynamic> json) {
    return OrderReviewStatus(
      canReview: json['canReview'] as bool? ?? false,
      buyerReviewed: json['buyerReviewed'] as bool? ?? false,
      sellerReviewed: json['sellerReviewed'] as bool? ?? false,
      revieweeId: (json['revieweeId'] as num?)?.toInt() ?? 0,
      revieweeName: json['revieweeName'] as String?,
    );
  }
}
