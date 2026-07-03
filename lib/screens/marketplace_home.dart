import 'dart:async';

import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/constants/category_icons.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/product_filters.dart';
import 'package:safemarket_app/models/favorite_product.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/product_service.dart';
import 'package:safemarket_app/screens/favorites_tab.dart';
import 'package:safemarket_app/screens/notifications_screen.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/chat_list_screen.dart';
import 'package:safemarket_app/screens/profile_screen.dart';
import 'package:safemarket_app/services/favorites_service.dart';
import 'package:safemarket_app/services/notification_service.dart';
import 'package:safemarket_app/screens/post_product_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/services/user_service.dart';
import 'package:safemarket_app/widgets/count_badge.dart';
import 'package:safemarket_app/widgets/login_required.dart';
import 'package:safemarket_app/widgets/product_filter_sheet.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';
import 'package:safemarket_app/widgets/report_violation_sheet.dart';
import 'package:safemarket_app/widgets/trust_gauge.dart';

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
  final _homeTabKey = GlobalKey<_HomeTabState>();
  StreamSubscription<int>? _chatUnreadSub;
  int _chatUnread = 0;

  @override
  void initState() {
    super.initState();
    _chatUnreadSub = ChatService.instance.watchTotalUnread().listen((count) {
      if (mounted) setState(() => _chatUnread = count);
    });
  }

  @override
  void dispose() {
    _chatUnreadSub?.cancel();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_bottomIndex == index) return;
    setState(() => _bottomIndex = index);
  }

  void _goHome() => _switchTab(0);

  /// Tab Chat và Tôi yêu cầu đăng nhập — khách sẽ được mời đăng nhập.
  Future<void> _onNavTap(int index) async {
    if ((index == 2 || index == 3) && !AuthService.instance.isLoggedIn) {
      final ok = await ensureLoggedIn(
        context,
        message: index == 2
            ? 'Đăng nhập để xem và trả lời tin nhắn với người bán.'
            : 'Đăng nhập để xem hồ sơ và quản lý tài khoản của bạn.',
      );
      if (!ok || !mounted) return;
      _homeTabKey.currentState?.reloadProducts();
    }
    _switchTab(index);
  }

  Future<void> _openPostProduct() async {
    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để đăng bán sản phẩm của bạn.',
    );
    if (!ok || !mounted) return;
    _homeTabKey.currentState?.reloadProducts();
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PostProductScreen()),
    );
    if (posted == true) {
      _homeTabKey.currentState?.reloadProducts();
    }
  }

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
              _HomeTab(key: _homeTabKey),
              const FavoritesTab(),
              const _ChatTab(),
              ProfileScreen(onBack: _goHome),
            ],
          ),
        ),
        floatingActionButton: _bottomIndex == 0
            ? FloatingActionButton(
                onPressed: _openPostProduct,
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
                  onTap: () => _onNavTap(0),
                ),
                _NavItem(
                  icon: Icons.favorite_border,
                  label: 'YÊU THÍCH',
                  selected: _bottomIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
                const SizedBox(width: 48), // khoảng cho FAB
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'CHAT',
                  selected: _bottomIndex == 2,
                  badgeCount: _chatUnread,
                  onTap: () => _onNavTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'TÔI',
                  selected: _bottomIndex == 3,
                  onTap: () => _onNavTap(3),
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
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with AutomaticKeepAliveClientMixin {
  int _selectedCategoryId = 0;
  bool _verifiedOnly = false;
  ProductFilters _filters = ProductFilters.empty;
  final _searchCtrl = TextEditingController();
  List<ProductCategory> _apiCategories = [];
  List<ProductListItem> _products = [];
  bool _loading = true;
  String? _error;
  int? _myTrustScore;
  String? _myRankLabel;

  void reloadProducts() {
    _loadAll();
    _loadTrustScore();
  }

  @override
  void initState() {
    super.initState();
    FavoritesService.instance.load();
    NotificationService.instance.load();
    _loadAll();
    _loadTrustScore();
  }

  Future<void> _loadTrustScore() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final profile = await UserService.instance.getMyProfile();
      if (!mounted) return;
      setState(() {
        _myTrustScore = profile.trustScore?.currentPoint;
        _myRankLabel = profile.trustScore?.rankLabel;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await showProductFilterSheet(
      context,
      initial: _filters,
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _loadAll();
  }

  void _clearFilters() {
    setState(() => _filters = ProductFilters.empty);
    _loadAll();
  }

  String _formatVnd(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _openNotifications() async {
    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để xem thông báo của bạn.',
    );
    if (!ok || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await ProductService.instance.getCategories();
      final products = await ProductService.instance.getProducts(
        categoryId: _selectedCategoryId == 0 ? null : _selectedCategoryId,
        search: _searchCtrl.text,
        verifiedOnly: _verifiedOnly,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _apiCategories = cats;
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _products = [];
        _loading = false;
      });
    }
  }

  List<_CategoryItem> get _categories {
    final list = <_CategoryItem>[
      const _CategoryItem('TẤT CẢ', kAllCategoriesIcon, isAll: true),
    ];
    for (final c in _apiCategories) {
      list.add(
        _CategoryItem(c.name, categoryIconFor(c.name), id: c.categoryId),
      );
    }
    return list;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_myTrustScore != null)
              SliverToBoxAdapter(
                child: TrustGaugeCard(
                  score: _myTrustScore!,
                  rankLabel: _myRankLabel,
                ),
              ),
            SliverToBoxAdapter(child: _buildSearchRow()),
            SliverToBoxAdapter(child: _buildCategories()),
            if (!_loading && _error == null)
              SliverToBoxAdapter(child: _buildSectionTitle()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: true,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                        'Đảm bảo backend NestJS đang chạy: cd backend && npm run start:dev',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadAll,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_products.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filters.hasActiveFilters || _searchCtrl.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filters.hasActiveFilters || _searchCtrl.text.isNotEmpty
                              ? 'Không có sản phẩm phù hợp bộ lọc'
                              : 'Không có sản phẩm',
                          textAlign: TextAlign.center,
                        ),
                        if (_filters.hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Xóa bộ lọc'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ProductDetailScreen(
                                productId: product.id,
                              ),
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
          ListenableBuilder(
            listenable: NotificationService.instance,
            builder: (context, _) {
              final unread = NotificationService.instance.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _openNotifications,
                  ),
                  CountBadge(count: unread, top: 8, right: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilterChip(
                label: const Text('Chỉ người đã eKYC'),
                selected: _verifiedOnly,
                onSelected: (v) {
                  setState(() => _verifiedOnly = v);
                  _loadAll();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadAll(),
                  decoration: InputDecoration(
                    hintText: 'Tìm sản phẩm, người bán uy tín',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: _filters.hasActiveFilters
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _openFilters,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.tune,
                          color: _filters.hasActiveFilters
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  if (_filters.activeCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_filters.activeCount}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _loadAll,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.search, color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
          if (_filters.hasActiveFilters) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_filters.location != null)
                  Chip(
                    label: Text(_filters.location!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _filters = _filters.copyWith(clearLocation: true);
                      });
                      _loadAll();
                    },
                  ),
                if (_filters.minPrice != null || _filters.maxPrice != null)
                  Chip(
                    label: Text(
                      _filters.minPrice != null && _filters.maxPrice != null
                          ? '${_formatVnd(_filters.minPrice!)} – ${_formatVnd(_filters.maxPrice!)} đ'
                          : _filters.minPrice != null
                              ? 'Từ ${_formatVnd(_filters.minPrice!)} đ'
                              : 'Đến ${_formatVnd(_filters.maxPrice!)} đ',
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _filters = _filters.copyWith(
                          clearMinPrice: true,
                          clearMaxPrice: true,
                        );
                      });
                      _loadAll();
                    },
                  ),
                if (_filters.sort != ProductSort.newest)
                  Chip(
                    label: Text(_filters.sort.label),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _filters = _filters.copyWith(sort: ProductSort.newest);
                      });
                      _loadAll();
                    },
                  ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Xóa tất cả'),
                ),
              ],
            ),
          ],
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
          final selected = (cat.id ?? 0) == _selectedCategoryId;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryId = cat.id ?? 0);
              _loadAll();
            },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFFF97316),
            size: 22,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _loading
                  ? 'ĐANG TẢI...'
                  : '${_products.length} KẾT QUẢ',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<ProductSort>(
            tooltip: 'Sắp xếp',
            onSelected: (sort) {
              setState(() => _filters = _filters.copyWith(sort: sort));
              _loadAll();
            },
            itemBuilder: (ctx) => ProductSort.values
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (_filters.sort == s)
                          const Icon(Icons.check, size: 18, color: AppColors.primary)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _filters.sort.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
  const _CategoryItem(this.label, this.icon, {this.isAll = false, this.id});
  final String label;
  final IconData icon;
  final bool isAll;
  final int? id;
}

Color _conditionColor(int pct) {
  if (pct >= 85) return AppColors.trustGreen;
  if (pct >= 70) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

/// Badge % độ bền góc ảnh sản phẩm.
class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    final color = _conditionColor(pct);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$pct%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Thẻ sản phẩm trong grid 2 cột.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final ProductListItem product;
  final VoidCallback onTap;

  FavoriteProduct get _favorite => FavoriteProduct(
        id: '${product.id}',
        name: product.title,
        price: product.priceFormatted,
        seller: product.sellerName,
        location: product.location,
        trustScore: product.trustScore,
        thumbnailUrl: product.thumbnailUrl,
      );

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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: ProductThumbnail(
                      thumbnailUrl: product.thumbnailUrl,
                      iconSize: 48,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _ConditionBadge(pct: product.conditionPct),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ListenableBuilder(
                      listenable: FavoritesService.instance,
                      builder: (context, _) {
                        final liked =
                            FavoritesService.instance
                                .isFavorite('${product.id}');
                        return GestureDetector(
                          onTap: () => FavoritesService.instance
                              .toggle(_favorite),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: liked
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        );
                      },
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
                      product.priceFormatted,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Độ bền ${product.conditionPct}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _conditionColor(product.conditionPct),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (AuthService.instance.isLoggedIn &&
                            product.sellerId != null &&
                            AuthService.instance.currentUser?.userId !=
                                product.sellerId)
                          GestureDetector(
                            onTap: () async {
                              await showReportViolationSheet(
                                context,
                                reportedUserId: product.sellerId!,
                                targetLabel: product.sellerName,
                                productId: product.id,
                                productTitle: product.title,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.flag_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        if (product.sellerVerified)
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
                          product.location,
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

/// Tab tin nhắn — danh sách hội thoại với người bán.
class _ChatTab extends StatelessWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'TIN NHẮN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: ChatListScreen()),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 24),
              CountBadge(count: badgeCount, top: -4, right: -10),
            ],
          ),
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
