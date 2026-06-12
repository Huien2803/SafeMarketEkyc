import 'package:flutter/material.dart';

/// Chấm đỏ kèm số (ẩn khi [count] <= 0).
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.top = 0,
    this.right = 0,
    this.left,
    this.bottom,
  });

  final int count;
  final double top;
  final double right;
  final double? left;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final label = count > 99 ? '99+' : '$count';

    return Positioned(
      top: top,
      right: right,
      left: left,
      bottom: bottom,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: count > 9 ? 4 : 5,
          vertical: 1,
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
