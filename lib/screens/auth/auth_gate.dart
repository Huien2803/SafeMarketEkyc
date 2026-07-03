import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/auth/login_screen.dart';
import 'package:safemarket_app/screens/marketplace_home.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Màn hình "cổng" — chạy đầu tiên, kiểm tra token đã lưu để quyết định
/// vào Marketplace hay hiện Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = AuthService.instance.loadFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'Không tải được phiên đăng nhập.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _initFuture = AuthService.instance.loadFromStorage();
                        });
                      },
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Vào màn đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Cho phép khách (chưa đăng nhập) vào xem chợ; các tính năng cần
        // tài khoản sẽ tự yêu cầu đăng nhập khi người dùng thao tác.
        return const MarketplaceHomeScreen();
      },
    );
  }
}
