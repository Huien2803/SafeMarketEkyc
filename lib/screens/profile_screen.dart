import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/user_profile.dart';
import 'package:safemarket_app/screens/auth/login_screen.dart';
import 'package:safemarket_app/screens/identity_verification.dart';
import 'package:safemarket_app/screens/admin_dashboard.dart';
import 'package:safemarket_app/screens/notifications_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/screens/order_detail_screen.dart';
import 'package:safemarket_app/screens/edit_profile_screen.dart';
import 'package:safemarket_app/screens/seller_reviews_screen.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/post_product_screen.dart';
import 'package:safemarket_app/screens/purchase_history_screen.dart';
import 'package:safemarket_app/screens/wallet_screen.dart';
import 'package:safemarket_app/screens/follow_list_screen.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/product_service.dart';
import 'package:safemarket_app/services/user_service.dart';
import 'package:safemarket_app/widgets/product_status_badge.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';
import 'package:safemarket_app/widgets/verified_badge.dart';

/// Màn hình Cá nhân — lấy dữ liệu thật từ API `/users/me`.
///
/// [onBack] là callback dùng khi ProfileScreen được nhúng làm 1 tab của
/// `MarketplaceHomeScreen` (qua IndexedStack). Nếu callback != null thì nút
/// back trên app bar sẽ gọi nó (chuyển tab về Home) thay vì pop route.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profileFuture;
  late Future<List<SoldListing>> _soldFuture;

  bool get _isGuest => !AuthService.instance.isLoggedIn;
  bool _initializedForUser = false;

  @override
  void initState() {
    super.initState();
    _initializedForUser = !_isGuest;
    if (_isGuest) {
      _profileFuture = Future<UserProfile>.error(
        AuthException('Chưa đăng nhập', statusCode: 401),
      );
      _soldFuture = Future<List<SoldListing>>.value(const []);
    } else {
      _profileFuture = _loadProfile();
      _soldFuture = OrderService.instance.getSoldProducts();
    }
  }

  Future<void> _goLogin() async {
    final nav = Navigator.of(context);
    await nav.push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
    if (mounted && !_isGuest) _refresh();
  }

  Future<UserProfile> _loadProfile() {
    return UserService.instance.getMyProfile().catchError((Object e) {
      throw e is AuthException ? e : AuthException(e.toString());
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _soldFuture = OrderService.instance.getSoldProducts();
    });
    try {
      await _profileFuture;
    } catch (_) {}
  }

  /// Nếu được nhúng làm tab (có callback) -> chuyển tab về Home.
  /// Nếu được push như 1 route độc lập -> pop quay lại màn trước.
  /// Trường hợp xấu nhất (route gốc, không có gì để pop) -> về '/home'.
  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi SafeMarket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuest) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
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
                    child: const Icon(Icons.person_outline,
                        size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bạn đang xem với tư cách khách',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập để quản lý hồ sơ, đăng bán, nhắn tin và '
                    'theo dõi người bán uy tín.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _goLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập / Đăng ký'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!_initializedForUser) {
      _initializedForUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLogout: _confirmLogout,
              );
            }
            final profile = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Về trang chủ',
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                            onPressed: _handleBack,
                          ),
                          const Text(
                            'Cá nhân',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Đăng xuất',
                            icon: const Icon(Icons.logout),
                            onPressed: _confirmLogout,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _UserHeaderSection(
                            profile: profile,
                            onEdit: () async {
                              final updated = await Navigator.push<UserProfile>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditProfileScreen(profile: profile),
                                ),
                              );
                              if (updated != null) _refresh();
                            },
                          ),
                          const SizedBox(height: 20),
                          _StatsRow(
                            profile: profile,
                            onReviewsTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => SellerReviewsScreen(
                                    userId: profile.userId,
                                    displayName:
                                        profile.displayName ?? profile.email,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _FollowStatsRow(
                            followerCount: profile.followerCount,
                            followingCount: profile.followingCount,
                            onFollowersTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => FollowListScreen(
                                    userId: profile.userId,
                                    mode: FollowListMode.followers,
                                    titleHint:
                                        profile.displayName ?? profile.email,
                                  ),
                                ),
                              ).then((_) => _refresh());
                            },
                            onFollowingTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => FollowListScreen(
                                    userId: profile.userId,
                                    mode: FollowListMode.following,
                                    titleHint:
                                        profile.displayName ?? profile.email,
                                  ),
                                ),
                              ).then((_) => _refresh());
                            },
                          ),
                          const SizedBox(height: 20),
                          _TrustCard(trustScore: profile.trustScore),
                          const SizedBox(height: 24),
                          const Text(
                            'TRẠNG THÁI XÁC THỰC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _EkycTile(ekyc: profile.ekyc),
                          if (profile.isAdmin || AuthService.instance.currentUser?.isAdmin == true) ...[
                            const SizedBox(height: 10),
                            ListTile(
                              tileColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: const Icon(Icons.admin_panel_settings,
                                  color: AppColors.primary),
                              title: const Text('Bảng quản trị SafeAdmin'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const AdminDashboardScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          _VerificationTile(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: AppColors.trustGreen,
                            title: 'Ví của tôi',
                            subtitle:
                                'Xem số dư bán hàng và rút tiền về ngân hàng',
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const WalletScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _VerificationTile(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: AppColors.primary,
                            title: 'Giao dịch thành công',
                            subtitle: profile.soldCount + profile.boughtCount > 0
                                ? 'Đã bán ${profile.soldCount} • Đã mua ${profile.boughtCount}'
                                : 'Chưa có giao dịch hoàn tất',
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () {
                              final initialTab =
                                  profile.soldCount > profile.boughtCount ? 1 : 0;
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PurchaseHistoryScreen(
                                    initialTab: initialTab,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<List<SoldListing>>(
                                future: _soldFuture,
                                builder: (context, soldSnap) {
                                  final active = (soldSnap.data ?? [])
                                      .where((s) => s.isActive)
                                      .length;
                                  return Text(
                                    'ĐANG RAO BÁN ($active)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<SoldListing>>(
                            future: _soldFuture,
                            builder: (context, soldSnap) {
                              if (soldSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final activeItems = (soldSnap.data ?? [])
                                  .where((s) => s.isActive)
                                  .toList();
                              if (activeItems.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: AppDecorations.card(),
                                  child: const Center(
                                    child: Text(
                                      'Bạn chưa có tin đang bán',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: activeItems
                                    .map(
                                      (s) => _SellerListingTile(
                                        item: s,
                                        showSoldBadge: false,
                                        onChanged: _refresh,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // --- ĐÃ ẨN ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<List<SoldListing>>(
                                future: _soldFuture,
                                builder: (context, soldSnap) {
                                  final hidden = (soldSnap.data ?? [])
                                      .where((s) => s.isHidden)
                                      .length;
                                  return Text(
                                    'ĐÃ ẨN ($hidden)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<SoldListing>>(
                            future: _soldFuture,
                            builder: (context, soldSnap) {
                              if (soldSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              final hiddenItems = (soldSnap.data ?? [])
                                  .where((s) => s.isHidden)
                                  .toList();
                              if (hiddenItems.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: AppDecorations.card(),
                                  child: const Center(
                                    child: Text(
                                      'Không có tin đang ẩn',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: hiddenItems
                                    .map(
                                      (s) => _SellerListingTile(
                                        item: s,
                                        showSoldBadge: false,
                                        onChanged: _refresh,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<List<SoldListing>>(
                                future: _soldFuture,
                                builder: (context, soldSnap) {
                                  final sold = (soldSnap.data ?? [])
                                      .where((s) => s.isSold)
                                      .length;
                                  return Text(
                                    'ĐÃ BÁN ($sold)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<SoldListing>>(
                            future: _soldFuture,
                            builder: (context, soldSnap) {
                              if (soldSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              final soldItems = (soldSnap.data ?? [])
                                  .where((s) => s.isSold)
                                  .toList();
                              if (soldItems.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: AppDecorations.card(),
                                  child: const Center(
                                    child: Text(
                                      'Chưa có sản phẩm đã bán',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: soldItems
                                    .map(
                                      (s) => _SellerListingTile(
                                        item: s,
                                        showSoldBadge: true,
                                        onChanged: _refresh,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Không tải được hồ sơ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeaderSection extends StatelessWidget {
  const _UserHeaderSection({
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFBFDBFE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            if (profile.ekyc.isVerified)
              const Positioned(
                right: -4,
                bottom: -4,
                child: VerifiedBadge(size: 24),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName ?? profile.email,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (profile.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.phoneNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (profile.location != null && profile.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.location!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Gia nhập: ${_formatJoinDate(profile.createdAt)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Chỉnh sửa hồ sơ',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
        ),
      ],
    );
  }

  String _formatJoinDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    return 'Tháng $mm/${d.year}';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.profile,
    required this.onReviewsTap,
  });

  final UserProfile profile;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${profile.soldCount}',
            label: 'ĐÃ BÁN',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '${profile.boughtCount}',
            label: 'ĐÃ MUA',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: profile.reviewCount > 0
                ? '${profile.averageRating.toStringAsFixed(1)}★'
                : '—',
            label: 'ĐÁNH GIÁ (${profile.reviewCount})',
            onTap: onReviewsTap,
          ),
        ),
      ],
    );
  }
}

class _FollowStatsRow extends StatelessWidget {
  const _FollowStatsRow({
    required this.followerCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$followerCount',
            label: 'NGƯỜI THEO DÕI',
            onTap: onFollowersTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$followingCount',
            label: 'ĐANG THEO DÕI',
            onTap: onFollowingTap,
          ),
        ),
      ],
    );
  }
}

class _SellerListingTile extends StatelessWidget {
  const _SellerListingTile({
    required this.item,
    required this.showSoldBadge,
    this.onChanged,
  });

  final SoldListing item;
  final bool showSoldBadge;
  final VoidCallback? onChanged;

  void _openProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: item.productId),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PostProductScreen(editProductId: item.productId),
      ),
    );
    if (ok == true) onChanged?.call();
  }

  Future<void> _hide(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ẩn tin đăng?'),
        content: const Text(
          'Tin sẽ không hiện trên chợ. Bạn có thể hiện lại bất cứ lúc nào.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ẩn tin')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ProductService.instance.hideProduct(item.productId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ẩn tin đăng')),
      );
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _unhide(BuildContext context) async {
    try {
      await ProductService.instance.unhideProduct(item.productId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hiện lại tin trên chợ')),
      );
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tin đăng?'),
        content: const Text(
          'Thao tác không hoàn tác. Ảnh và tin sẽ bị xóa khỏi hệ thống.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ProductService.instance.deleteProduct(item.productId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa tin đăng')),
      );
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBuyer = item.hasBuyer;
    final manageable = item.isManageable;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(),
      child: InkWell(
        onTap: () => _openProduct(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ProductThumbnail(
                        thumbnailUrl: item.thumbnailUrl,
                        iconSize: 28,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    if (showSoldBadge || item.isHidden)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: ProductStatusBadge(
                          status: item.isHidden ? 'Hidden' : 'Sold',
                          compact: true,
                        ),
                      ),
                    if (showSoldBadge || item.isHidden)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.priceFormatted,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isSold
                          ? (item.buyerName != null
                              ? 'Đã bán cho ${item.buyerName}'
                              : 'Đã bán')
                          : item.isHidden
                              ? 'Đã ẩn — không hiện trên chợ'
                              : item.buyerStatusLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (manageable)
                PopupMenuButton<String>(
                  tooltip: 'Quản lý tin',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _edit(context);
                      case 'hide':
                        _hide(context);
                      case 'unhide':
                        _unhide(context);
                      case 'delete':
                        _delete(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Sửa tin'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (item.productStatus == 'Available')
                      const PopupMenuItem(
                        value: 'hide',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_off_outlined),
                          title: Text('Ẩn tin'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (item.isHidden)
                      const PopupMenuItem(
                        value: 'unhide',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_outlined),
                          title: Text('Hiện lại'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Xóa tin', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              else if (hasBuyer && item.orderId != null)
                IconButton(
                  tooltip: 'Chi tiết đơn',
                  icon: const Icon(Icons.receipt_long_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            OrderDetailScreen(orderId: item.orderId!),
                      ),
                    );
                  },
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppDecorations.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: AppDecorations.card(),
          child: child,
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.trustScore});
  final TrustScore? trustScore;

  @override
  Widget build(BuildContext context) {
    final score = trustScore;
    if (score == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Chưa có điểm tín nhiệm'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.trustCardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ĐIỂM TÍN NHIỆM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_rankIcon(score.rankLevel),
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      score.rankLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${score.currentPoint} / ${score.maxPoint}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _trustMessage(score.rankLevel),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _rankIcon(String level) {
    switch (level) {
      case 'Diamond':
        return Icons.diamond;
      case 'Gold':
        return Icons.emoji_events;
      case 'Silver':
        return Icons.military_tech;
      default:
        return Icons.workspace_premium;
    }
  }

  String _trustMessage(String level) {
    switch (level) {
      case 'Diamond':
        return 'Tài khoản uy tín bậc nhất.';
      case 'Gold':
        return 'Tài khoản an toàn. Ưu tiên hiển thị trên sàn.';
      case 'Silver':
        return 'Đang xây dựng uy tín. Hoàn tất eKYC để tăng điểm.';
      default:
        return 'Mới gia nhập. Hoàn tất eKYC để tăng điểm tín nhiệm.';
    }
  }
}

class _EkycTile extends StatelessWidget {
  const _EkycTile({required this.ekyc});
  final EkycSummary ekyc;

  @override
  Widget build(BuildContext context) {
    final (icon, color, subtitle, trailing) = _state();
    return _VerificationTile(
      icon: icon,
      iconColor: color,
      title: 'Định danh eKYC',
      subtitle: subtitle,
      trailing: trailing,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const IdentityVerificationScreen(),
          ),
        );
      },
    );
  }

  (IconData, Color, String, Widget) _state() {
    if (ekyc.isVerified) {
      return (
        Icons.shield,
        AppColors.trustGreen,
        'Đã xác minh${ekyc.fullName != null ? ' • ${ekyc.fullName}' : ''}',
        const Icon(Icons.check_circle, color: AppColors.trustGreen),
      );
    }
    if (ekyc.isPending) {
      return (
        Icons.hourglass_bottom,
        Colors.orange,
        'Đang chờ duyệt eKYC',
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      );
    }
    if (ekyc.isRejected) {
      return (
        Icons.error_outline,
        Colors.red,
        'eKYC bị từ chối, hãy nộp lại',
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      );
    }
    return (
      Icons.shield_outlined,
      AppColors.textMuted,
      'Chưa xác thực — bấm để xác minh ngay',
      const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}

class _VerificationTile extends StatelessWidget {
  const _VerificationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
