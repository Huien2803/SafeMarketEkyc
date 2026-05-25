import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Thanh điểm tín nhiệm (dùng trong bảng Admin).
class TrustScoreBar extends StatelessWidget {
  const TrustScoreBar({
    super.key,
    required this.score,
    this.maxScore = 1000,
  });

  final int score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    final progress = (score / maxScore).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
