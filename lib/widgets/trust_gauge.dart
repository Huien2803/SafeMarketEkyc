import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Biểu đồ cung điểm tín nhiệm (gauge chart) — xanh / vàng / đỏ theo mức điểm.
class TrustGauge extends StatelessWidget {
  const TrustGauge({
    super.key,
    required this.score,
    this.maxScore = 1000,
    this.size = 160,
  });

  final int score;
  final int maxScore;
  final double size;

  Color get _color {
    final ratio = score / maxScore;
    if (ratio >= 0.75) return const Color(0xFF16A34A);
    if (ratio >= 0.45) return const Color(0xFFEAB308);
    return const Color(0xFFDC2626);
  }

  String get _label {
    final ratio = score / maxScore;
    if (ratio >= 0.75) return 'Rất tốt';
    if (ratio >= 0.45) return 'Trung bình';
    return 'Rủi ro';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(size, size * 0.72),
            painter: _GaugePainter(
              progress: (score / maxScore).clamp(0.0, 1.0),
              color: _color,
            ),
          ),
          Positioned(
            bottom: 8,
            child: Column(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;
    const startAngle = math.pi;
    const sweep = math.pi;

    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      bgPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Thẻ gauge dùng trên trang chủ.
class TrustGaugeCard extends StatelessWidget {
  const TrustGaugeCard({super.key, required this.score, this.rankLabel});

  final int score;
  final String? rankLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          TrustGauge(score: score),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHỈ SỐ TÍN NHIỆM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rankLabel ?? 'Điểm uy tín của bạn',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Xanh: rất tốt · Vàng: trung bình · Đỏ: rủi ro',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
