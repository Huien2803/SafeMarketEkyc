import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/services/api_config.dart';

/// Ảnh sản phẩm — fallback icon nếu chưa có URL.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 48,
    this.borderRadius,
  });

  final String? thumbnailUrl;
  final BoxFit fit;
  final double iconSize;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final url = ApiConfig.mediaUrl(thumbnailUrl);

    if (url.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: radius,
        ),
        child: Center(
          child: Icon(
            Icons.shopping_bag_outlined,
            size: iconSize,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFF3F4F6),
          child: Icon(Icons.broken_image_outlined, size: iconSize),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF3F4F6),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
