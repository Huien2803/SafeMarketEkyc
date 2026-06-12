import 'package:flutter/material.dart';
import 'package:safemarket_app/widgets/star_rating.dart';

/// Dialog đánh giá sau giao dịch hoàn tất.
class ReviewSubmitDialog {
  ReviewSubmitDialog._();

  static Future<({int rating, String? comment})?> show(
    BuildContext context, {
    required String revieweeName,
    required bool reviewingSeller,
  }) {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final title =
        reviewingSeller ? 'Đánh giá người bán' : 'Đánh giá người mua';
    final subtitle = reviewingSeller
        ? 'Chia sẻ trải nghiệm mua hàng với $revieweeName'
        : 'Chia sẻ trải nghiệm bán hàng với $revieweeName';

    return showDialog<({int rating, String? comment})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                StarRating(
                  rating: rating,
                  size: 32,
                  onChanged: (v) => setLocal(() => rating = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Nhận xét (tuỳ chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final comment = commentCtrl.text.trim();
                Navigator.pop(ctx, (
                  rating: rating,
                  comment: comment.isEmpty ? null : comment,
                ));
              },
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    ).whenComplete(commentCtrl.dispose);
  }
}
