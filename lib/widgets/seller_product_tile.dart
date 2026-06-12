import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/widgets/product_status_badge.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';

/// Thẻ sản phẩm trong shop người bán (ngang hoặc dọc).
class SellerProductTile extends StatelessWidget {
  const SellerProductTile({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 140,
    this.compact = true,
  });

  final SoldListing item;
  final VoidCallback onTap;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return _VerticalTile(item: item, onTap: onTap);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 10),
        decoration: AppDecorations.card(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: width,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductThumbnail(
                    thumbnailUrl: item.thumbnailUrl,
                    iconSize: 32,
                  ),
                  if (item.isSold)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: ProductStatusBadge(status: 'Sold', compact: true),
                    ),
                  if (item.isSold)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.priceFormatted,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalTile extends StatelessWidget {
  const _VerticalTile({required this.item, required this.onTap});

  final SoldListing item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ProductThumbnail(
                        thumbnailUrl: item.thumbnailUrl,
                        iconSize: 28,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    if (item.isSold)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: ProductStatusBadge(status: 'Sold', compact: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.priceFormatted,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
