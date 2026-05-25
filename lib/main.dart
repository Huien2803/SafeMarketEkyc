import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_theme.dart';
import 'package:safemarket_app/screens/admin_dashboard.dart';
import 'package:safemarket_app/screens/identity_verification.dart';
import 'package:safemarket_app/screens/marketplace_home.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeMarketApp());
}

/// Ứng dụng gốc SafeMarket — Material 3, theme theo thiết kế mẫu.
class SafeMarketApp extends StatelessWidget {
  const SafeMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeMarket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppLauncher(),
      routes: {
        '/home': (_) => const MarketplaceHomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/ekyc': (_) => const IdentityVerificationScreen(),
        '/product': (_) => const ProductDetailScreen(),
        '/admin': (_) => const AdminDashboardScreen(),
      },
    );
  }
}

/// Màn chọn nhanh để demo 5 giao diện (có thể thay bằng routing thật sau).
class _AppLauncher extends StatelessWidget {
  const _AppLauncher();

  @override
  Widget build(BuildContext context) {
    final screens = [
      _LauncherItem(
        'Chợ đồ cũ',
        Icons.storefront,
        const MarketplaceHomeScreen(),
      ),
      _LauncherItem('Cá nhân', Icons.person, const ProfileScreen()),
      _LauncherItem(
        'Xác thực eKYC',
        Icons.verified_user,
        const IdentityVerificationScreen(),
      ),
      _LauncherItem(
        'Chi tiết sản phẩm',
        Icons.shopping_bag,
        const ProductDetailScreen(),
      ),
      _LauncherItem(
        'Admin Dashboard',
        Icons.admin_panel_settings,
        const AdminDashboardScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeMarket — Demo UI'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screens.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = screens[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => item.screen),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const MarketplaceHomeScreen(),
            ),
          );
        },
        label: const Text('Vào app chính'),
        icon: const Icon(Icons.home),
      ),
    );
  }
}

class _LauncherItem {
  const _LauncherItem(this.title, this.icon, this.screen);
  final String title;
  final IconData icon;
  final Widget screen;
}
