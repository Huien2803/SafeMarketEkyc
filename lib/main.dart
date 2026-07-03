import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_theme.dart';
import 'package:safemarket_app/firebase_options.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/screens/admin_dashboard.dart';
import 'package:safemarket_app/screens/auth/auth_gate.dart';
import 'package:safemarket_app/screens/auth/login_screen.dart';
import 'package:safemarket_app/screens/auth/register_screen.dart';
import 'package:safemarket_app/screens/identity_verification.dart';
import 'package:safemarket_app/screens/marketplace_home.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tự dò địa chỉ server backend phù hợp với thiết bị đang chạy.
  await ApiConfig.resolveBaseUrl();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init: $e — cấu hình firebase_options.dart + google-services.json');
  }
  runApp(const SafeMarketApp());
}

class SafeMarketApp extends StatelessWidget {
  const SafeMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeMarket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MarketplaceHomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/ekyc': (_) => const IdentityVerificationScreen(),
        '/product': (ctx) {
          final id = ModalRoute.of(ctx)?.settings.arguments;
          return ProductDetailScreen(
            productId: id is int ? id : 1,
          );
        },
        '/admin': (_) => const AdminDashboardScreen(),
      },
    );
  }
}
