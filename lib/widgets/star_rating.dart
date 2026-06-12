import 'package:flutter/material.dart';

/// Hiển thị sao (chỉ đọc hoặc chọn).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= rating;
        final icon = Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
        if (onChanged == null) return icon;
        return InkWell(
          onTap: () => onChanged!(star),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: icon,
          ),
        );
      }),
    );
  }
}
