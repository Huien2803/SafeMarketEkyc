import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';

/// Thẻ sản phẩm trong bubble chat (kiểu Shopee).
class ChatProductCard extends StatelessWidget {
  const ChatProductCard({
    super.key,
    required this.meta,
    this.mine = false,
    this.compact = false,
  });

  final Map<String, dynamic> meta;
  final bool mine;
  final bool compact;

  int? get productId => (meta['productId'] as num?)?.toInt();

  @override
  Widget build(BuildContext context) {
    final title = meta['title'] as String? ?? 'Sản phẩm';
    final price = meta['priceFormatted'] as String? ?? '';
    final condition = meta['conditionPct'];
    final location = meta['location'] as String? ?? '';
    final thumbnailUrl = meta['thumbnailUrl'] as String?;

    final card = Container(
      width: compact ? null : MediaQuery.sizeOf(context).width * 0.72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mine
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.textMuted.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Text(
              'Sản phẩm quan tâm',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.primary : AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          if (!compact) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: compact ? 48 : 64,
                  height: compact ? 48 : 64,
                  child: ProductThumbnail(
                    thumbnailUrl: thumbnailUrl,
                    iconSize: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    if (condition != null)
                      Text(
                        'Tình trạng $condition%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (productId != null && productId! > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Chạm để xem chi tiết →',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (productId == null || productId! <= 0) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(productId: productId!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}
