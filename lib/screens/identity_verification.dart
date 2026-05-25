import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Màn hình Xác thực danh tính eKYC — chuẩn bị CCCD và quét khuôn mặt.
class IdentityVerificationScreen extends StatelessWidget {
  const IdentityVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Xác thực danh tính',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Minh họa điện thoại ở giữa màn hình
                    _PhoneIllustration(),
                    const SizedBox(height: 32),
                    const Text(
                      'Bạn cần chuẩn bị:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PreparationCard(
                      icon: Icons.shield,
                      title: 'Căn cước công dân',
                      subtitle: 'Bản gốc, còn hạn sử dụng',
                    ),
                    const SizedBox(height: 12),
                    _PreparationCard(
                      icon: Icons.person_outline,
                      title: 'Khuôn mặt chính chủ',
                      subtitle: 'Không đeo kính, khẩu trang',
                    ),
                    const SizedBox(height: 24),
                    // Khung cảnh báo bảo mật AI
                    _SecurityNoticeBox(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Nút hành động cố định dưới đáy
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Xác thực ngay'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vùng minh họa smartphone bo góc tối giản.
class _PhoneIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFE3EDFF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Container(
            width: 80,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ yêu cầu chuẩn bị (CCCD / khuôn mặt).
class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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

/// Hộp thông tin bảo mật AI — nền vàng nhạt.
class _SecurityNoticeBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warningIcon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hệ thống sử dụng công nghệ AI để bảo mật dữ liệu. '
              'Thông tin cá nhân của bạn sẽ được mã hóa 100%.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
