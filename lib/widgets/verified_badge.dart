import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Icon khiên xác thực eKYC — gắn trên avatar người bán / profile.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 20,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.verified,
        size: size * 0.65,
        color: AppColors.white,
      ),
    );
  }
}
