import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/profile_screen.dart';

/// Màn hình "shell" của app sau khi đăng nhập.
///
/// Dùng [IndexedStack] để giữ state của từng tab (scroll position, dữ liệu
/// đã load không bị reset khi chuyển tab) — đây là pattern chuẩn của Flutter
/// cho bottom navigation và cho UX mượt nhất:
///   - Không push/pop route khi đổi tab → không có hiệu ứng trượt rườm rà
///   - Không có chuyện stack chồng nhiều bản Profile/Home cùng lúc
///   - Nút back của Android: ở tab khác Home -> quay về tab Home,
///     ở tab Home -> thoát app (PopScope điều khiển).
class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  int _bottomIndex = 0;

  void _switchTab(int index) {
    if (_bottomIndex == index) return;
    setState(() => _bottomIndex = index);
  }

  void _goHome() => _switchTab(0);

  @override
  Widget build(BuildContext context) {
    // PopScope: bắt nút back Android.
    //   - Đang ở tab Home -> cho phép pop (thoát app)
    //   - Đang ở tab khác -> chặn pop và chuyển về tab Home
    return PopScope(
      canPop: _bottomIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _bottomIndex != 0) {
          _goHome();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _bottomIndex,
            children: [
              const _HomeTab(),
              const _PlaceholderTab(
                icon: Icons.favorite_border,
                title: 'Yêu thích',
                subtitle: 'Danh sách sản phẩm bạn đã lưu sẽ hiện ở đây.',
              ),
              const _PlaceholderTab(
                icon: Icons.chat_bubble_outline,
                title: 'Tin nhắn',
                subtitle: 'Hội thoại với người bán sẽ hiện ở đây.',
              ),
              ProfileScreen(onBack: _goHome),
            ],
          ),
        ),
        floatingActionButton: _bottomIndex == 0
            ? FloatingActionButton(
                onPressed: () {},
                backgroundColor: AppColors.primary,
                elevation: 6,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: AppColors.white, size: 32),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: AppColors.white,
          elevation: 12,
          notchMargin: 8,
          shape: const CircularNotchedRectangle(),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: 'CHỦ',
                  selected: _bottomIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                _NavItem(
                  icon: Icons.favorite_border,
                  label: 'YÊU THÍCH',
                  selected: _bottomIndex == 1,
                  onTap: () => _switchTab(1),
                ),
                const SizedBox(width: 48), // khoảng cho FAB
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'CHAT',
                  selected: _bottomIndex == 2,
                  onTap: () => _switchTab(2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'TÔI',
                  selected: _bottomIndex == 3,
                  onTap: () => _switchTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ====================================================================
///  Tab 1: HOME (Marketplace) - nội dung cũ
/// ====================================================================
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with AutomaticKeepAliveClientMixin {
  int _selectedCategory = 0;

  static const _categories = [
    _CategoryItem('TẤT CẢ', Icons.auto_awesome, isAll: true),
    _CategoryItem('ĐIỆN TỬ', Icons.smartphone),
    _CategoryItem('THỜI TRANG', Icons.checkroom),
    _CategoryItem('ĐỒ GIA DỤNG', Icons.home_outlined),
    _CategoryItem('XE CỘ', Icons.directions_car_outlined),
    _CategoryItem('SÁCH', Icons.menu_book_outlined),
  ];

  static const _products = [
    _ProductData(
      name: 'iPhone 13 Pro Max - 256GB',
      price: '15.500.000đ',
      seller: 'An Nguyễn',
      trustScore: 850,
      location: 'Quận 1',
      time: '2 giờ trước',
      icon: Icons.phone_iphone,
    ),
    _ProductData(
      name: 'Sony A7 III Body',
      price: '22.000.000đ',
      seller: 'Minh Trần',
      trustScore: 720,
      location: 'Quận 3',
      time: '5 giờ trước',
      icon: Icons.camera_alt_outlined,
    ),
    _ProductData(
      name: 'MacBook Pro M1 2020',
      price: '18.900.000đ',
      seller: 'Hùng Lê',
      trustScore: 910,
      location: 'Thủ Đức',
      time: '1 ngày trước',
      icon: Icons.laptop_mac,
    ),
    _ProductData(
      name: 'AirPods Pro 2',
      price: '3.200.000đ',
      seller: 'Lan Phạm',
      trustScore: 680,
      location: 'Quận 7',
      time: '3 giờ trước',
      icon: Icons.headphones,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSearchRow()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionTitle()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = _products[index % _products.length];
                  return _ProductCard(
                    product: product,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProductDetailScreen(),
                        ),
                      );
                    },
                  );
                },
                childCount: _products.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 8),
          const Text(
            'SafeMarket',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm sản phẩm, người bán uy tín',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.tune, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = _selectedCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected ? null : AppDecorations.cardShadow,
                    ),
                    child: Icon(
                      cat.icon,
                      color: selected ? AppColors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(Icons.local_fire_department,
              color: Color(0xFFF97316), size: 22),
          SizedBox(width: 6),
          Text(
            'DÀNH CHO BẠN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Spacer(),
          Icon(Icons.grid_view, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

/// ====================================================================
///  Tab placeholder (Yêu thích / Chat) - sẽ thay nội dung thật sau
/// ====================================================================
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Chip(
                label: Text('Sắp ra mắt'),
                backgroundColor: AppColors.ekycPendingBg,
                labelStyle: TextStyle(
                  color: AppColors.ekycPendingText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem(this.label, this.icon, {this.isAll = false});
  final String label;
  final IconData icon;
  final bool isAll;
}

class _ProductData {
  const _ProductData({
    required this.name,
    required this.price,
    required this.seller,
    required this.trustScore,
    required this.location,
    required this.time,
    required this.icon,
  });

  final String name;
  final String price;
  final String seller;
  final int trustScore;
  final String location;
  final String time;
  final IconData icon;
}

/// Thẻ sản phẩm trong grid 2 cột.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final _ProductData product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Icon(product.icon,
                        size: 48, color: AppColors.textMuted),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border,
                          size: 18, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.seller,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(Icons.verified,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⭐ ${product.trustScore}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.trustGreen,
                          ),
                        ),
                        Text(
                          '${product.location} · ${product.time}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
