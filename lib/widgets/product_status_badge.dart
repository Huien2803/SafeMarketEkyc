import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Nhãn trạng thái sản phẩm (Đã bán, Đang giữ chỗ, …).
class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  static String labelFor(String status) {
    switch (status) {
      case 'Sold':
        return 'Đã bán';
      case 'Reserved':
        return 'Đang giữ chỗ';
      case 'Hidden':
        return 'Đã ẩn';
      default:
        return '';
    }
  }

  static Color colorFor(String status) {
    switch (status) {
      case 'Sold':
        return const Color(0xFF6B7280);
      case 'Reserved':
        return AppColors.warning;
      case 'Hidden':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = labelFor(status);
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: colorFor(status).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
