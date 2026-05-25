import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Hằng số bo góc, đổ bóng dùng chung — giữ UI đồng nhất.
class AppDecorations {
  AppDecorations._();

  static const double radiusCard = 16;
  static const double radiusButton = 12;
  static const double radiusBadge = 8;

  /// Đổ bóng nhẹ cho thẻ nổi trên nền #F4F6F9.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(radiusCard),
        boxShadow: cardShadow,
      );
}
