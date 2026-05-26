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
        return AnimatedBuilder(
          animation: AuthService.instance,
          builder: (_, _) {
            return AuthService.instance.isLoggedIn
                ? const MarketplaceHomeScreen()
                : const LoginScreen();
          },
        );
      },
    );
  }
}
