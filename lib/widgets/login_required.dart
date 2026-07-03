import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/auth/login_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';

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
