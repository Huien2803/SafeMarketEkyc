import 'package:flutter/material.dart';

/// Bảng màu hệ thống SafeMarket — đồng bộ với thiết kế UI mẫu.
class AppColors {
  AppColors._();

  /// Xanh dương Royal — màu chủ đạo (nút, giá, active state).
  static const Color primary = Color(0xFF1E60FF);

  /// Nền xám trắng siêu nhạt toàn app.
  static const Color background = Color(0xFFF4F6F9);

  /// Xanh lá — uy tín, xác thực, điểm tín nhiệm cao.
  static const Color trustGreen = Color(0xFF198754);

  /// Điểm cuối gradient thẻ tín nhiệm.
  static const Color trustGradientEnd = Color(0xFF673AB7);

  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Nền xanh nhạt cho Seller Card.
  static const Color sellerCardBg = Color(0xFFE8F0FF);

  /// Cảnh báo vàng nhạt (màn eKYC).
  static const Color warningBg = Color(0xFFFFF8E6);
  static const Color warningText = Color(0xFFB45309);
  static const Color warningIcon = Color(0xFFF59E0B);

  /// Badge eKYC.
  static const Color ekycVerifiedBg = Color(0xFFD1FAE5);
  static const Color ekycVerifiedText = Color(0xFF047857);
  static const Color ekycPendingBg = Color(0xFFFFEDD5);
  static const Color ekycPendingText = Color(0xFFC2410C);

  /// Vi phạm / khóa tài khoản.
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF97316);

  /// Đổ bóng nhẹ.
  static const Color shadow = Color(0x1A000000);

  /// Gradient thẻ tín nhiệm Profile.
  static const LinearGradient trustCardGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, trustGradientEnd],
  );
}
