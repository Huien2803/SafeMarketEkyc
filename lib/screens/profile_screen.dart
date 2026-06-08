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
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/user_service.dart';
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

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _soldFuture = OrderService.instance.getSoldProducts();
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
                          _UserHeaderSection(profile: profile),
                          const SizedBox(height: 20),
                          _StatsRow(profile: profile),
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
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<List<SoldListing>>(
                                future: _soldFuture,
                                builder: (context, soldSnap) {
                                  final count = soldSnap.data?.length ?? 0;
                                  return Text(
                                    'ĐÃ ĐĂNG BÁN ($count)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
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
                              final items = soldSnap.data ?? [];
                              if (items.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: AppDecorations.card(),
                                  child: const Center(
                                    child: Text(
                                      'Bạn chưa đăng sản phẩm nào',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: items
                                    .map((s) => _SoldListingTile(item: s))
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ĐANG RAO BÁN (${profile.activeListingCount})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Xem tất cả'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppDecorations.card(),
                            child: Center(
                              child: Text(
                                profile.activeListingCount == 0
                                    ? 'Bạn chưa đăng tin nào'
                                    : 'Có ${profile.activeListingCount} tin đang bán',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
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
  const _UserHeaderSection({required this.profile});
  final UserProfile profile;

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
      ],
    );
  }

  String _formatJoinDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    return 'Tháng $mm/${d.year}';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final UserProfile profile;

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
          ),
        ),
      ],
    );
  }
}

class _SoldListingTile extends StatelessWidget {
  const _SoldListingTile({required this.item});
  final SoldListing item;

  @override
  Widget build(BuildContext context) {
    final hasBuyer = item.hasBuyer;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(),
      child: ListTile(
        leading: Icon(
          hasBuyer ? Icons.shopping_cart_checkout : Icons.storefront_outlined,
          color: hasBuyer ? AppColors.trustGreen : AppColors.textMuted,
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.priceFormatted} • ${item.buyerStatusLabel}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: hasBuyer && item.orderId != null
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: item.orderId != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OrderDetailScreen(orderId: item.orderId!),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: AppDecorations.card(),
      child: Column(
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
