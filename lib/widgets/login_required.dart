import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/auth/login_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/ekyc_service.dart';

/// Đảm bảo người dùng đã đăng nhập trước khi thực hiện một hành động.
///
/// - Nếu đã đăng nhập: trả về `true` ngay.
/// - Nếu là khách: hiện hộp thoại mời đăng nhập. Nếu đồng ý sẽ mở
///   [LoginScreen]; sau khi quay lại, trả về trạng thái đăng nhập mới.
Future<bool> ensureLoggedIn(
  BuildContext context, {
  String message = 'Bạn cần đăng nhập để dùng tính năng này.',
}) async {
  if (AuthService.instance.isLoggedIn) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Cần đăng nhập')),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Đăng nhập'),
        ),
      ],
    ),
  );

  if (go != true || !context.mounted) return AuthService.instance.isLoggedIn;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
  );

  return AuthService.instance.isLoggedIn;
}

/// Đảm bảo người dùng đã XÁC THỰC eKYC (kyc_status = 'Verified') trước khi
/// mua/bán. Gọi sau [ensureLoggedIn].
///
/// - Trả về `true` nếu đã Verified.
/// - Nếu chưa: hiện hộp thoại giải thích + mời đi xác thực (route `/ekyc`).
///   Sau khi quay lại sẽ kiểm tra lại trạng thái và trả về kết quả mới.
Future<bool> ensureEkycVerified(
  BuildContext context, {
  String message = 'Bạn cần xác thực danh tính (eKYC) để dùng tính năng này.',
}) async {
  String status = 'Unverified';
  try {
    status = (await EkycService.instance.getMyStatus()).status;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không kiểm tra được trạng thái xác thực')),
    );
    return false;
  }
  if (status == 'Verified') return true;
  if (!context.mounted) return false;

  final detail = switch (status) {
    'Pending' => 'Hồ sơ eKYC của bạn đang chờ duyệt. Vui lòng đợi được duyệt.',
    'Rejected' => 'Hồ sơ eKYC đã bị từ chối. Vui lòng xác thực lại.',
    _ => message,
  };
  final canRetry = status != 'Pending';

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Cần xác thực danh tính')),
        ],
      ),
      content: Text(detail),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Để sau'),
        ),
        if (canRetry)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác thực ngay'),
          ),
      ],
    ),
  );

  if (go != true || !context.mounted) return false;

  await Navigator.of(context).pushNamed('/ekyc');

  if (!context.mounted) return false;
  try {
    return (await EkycService.instance.getMyStatus()).status == 'Verified';
  } catch (_) {
    return false;
  }
}
