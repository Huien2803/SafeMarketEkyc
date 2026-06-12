import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/review.dart';
import 'package:safemarket_app/services/review_service.dart';
import 'package:safemarket_app/services/user_service.dart';
import 'package:safemarket_app/widgets/star_rating.dart';

/// Danh sách đánh giá nhận được (thường là người bán).
class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({
    super.key,
    required this.userId,
    this.displayName,
  });

  final int userId;
  final String? displayName;

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  late Future<_ReviewPageData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_ReviewPageData> _load() async {
    final profile =
        await UserService.instance.getProfile(widget.userId);
    final reviews =
        await ReviewService.instance.getUserReviews(widget.userId);
    return _ReviewPageData(
      name: widget.displayName ??
          profile.displayName ??
          profile.email,
      reviews: reviews,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đánh giá người bán'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<_ReviewPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final reviews = data.reviews;
          final count = reviews.length;
          final avg = count == 0
              ? 0.0
              : reviews.map((r) => r.rating).reduce((a, b) => a + b) / count;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.card(),
                  child: Column(
                    children: [
                      Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        count > 0 ? avg.toStringAsFixed(1) : '—',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (count > 0)
                        StarRating(rating: avg.round(), size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '$count đánh giá',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppDecorations.card(),
                    child: const Center(
                      child: Text(
                        'Chưa có đánh giá nào.\nHoàn tất giao dịch để nhận đánh giá từ người mua.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...reviews.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReviewCard(review: r),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewPageData {
  const _ReviewPageData({required this.name, required this.reviews});
  final String name;
  final List<ReviewItem> reviews;
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd/MM/yyyy').format(review.createdAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFBFDBFE),
                child: Text(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StarRating(rating: review.rating, size: 16),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
