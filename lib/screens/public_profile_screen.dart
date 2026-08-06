import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/models/user_profile.dart';
import 'package:safemarket_app/screens/follow_list_screen.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/seller_reviews_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/follow_service.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/user_service.dart';
import 'package:safemarket_app/widgets/seller_product_tile.dart';
import 'package:safemarket_app/widgets/star_rating.dart';
import 'package:safemarket_app/widgets/report_violation_sheet.dart';
import 'package:safemarket_app/widgets/verified_badge.dart';

/// Hồ sơ công khai — shop sản phẩm + nút theo dõi.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.displayNameHint,
  });

  final int userId;
  final String? displayNameHint;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<_ShopData> _shopFuture;
  bool _followBusy = false;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _shopFuture = _load();
  }

  Future<_ShopData> _load() async {
    final results = await Future.wait([
      UserService.instance.getProfile(widget.userId),
      OrderService.instance.getUserListings(widget.userId),
    ]);
    final profile = results[0] as UserProfile;
    final listings = results[1] as List<SoldListing>;
    if (mounted) setState(() => _following = profile.isFollowing);
    return _ShopData(profile: profile, listings: listings);
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    if (!AuthService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để theo dõi')),
      );
      return;
    }
    if (AuthService.instance.currentUser?.userId == widget.userId) return;

    setState(() => _followBusy = true);
    try {
      if (_following) {
        await FollowService.instance.unfollow(widget.userId);
      } else {
        await FollowService.instance.follow(widget.userId);
      }
      if (mounted) {
        setState(() => _following = !_following);
        _shopFuture = _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _openProduct(int productId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: productId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.instance.currentUser?.userId;
    final isSelf = myId != null && myId == widget.userId;
    final canFollow = !isSelf;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          widget.displayNameHint ?? 'Shop',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (canFollow && AuthService.instance.isLoggedIn)
            IconButton(
              tooltip: 'Báo cáo vi phạm',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () async {
                final sent = await showReportViolationSheet(
                  context,
                  reportedUserId: widget.userId,
                  targetLabel:
                      widget.displayNameHint ?? 'User #${widget.userId}',
                );
                if (sent && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi báo cáo — admin sẽ kiểm duyệt'),
                    ),
                  );
                }
              },
            ),
          if (canFollow)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _followBusy ? null : _toggleFollow,
                icon: Icon(
                  _following ? Icons.check : Icons.person_add_alt_1,
                  size: 18,
                ),
                label: Text(
                  _following ? 'Đang FL' : 'Theo dõi',
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _following
                      ? AppColors.textMuted.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor:
                      _following ? AppColors.textMuted : AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<_ShopData>(
        future: _shopFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final data = snap.data!;
          final p = data.profile;
          final active =
              data.listings.where((s) => s.isActive).toList();
          final sold = data.listings.where((s) => s.isSold).toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _shopFuture = _load());
              await _shopFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFFBFDBFE),
                        child: Text(
                          p.initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (p.ekyc.isVerified)
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: VerifiedBadge(size: 24.0),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p.displayName ?? p.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (p.location != null && p.location!.isNotEmpty)
                  Text(
                    p.location!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                const SizedBox(height: 16),
                if (isSelf)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Đây là shop của bạn',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _followBusy ? null : _toggleFollow,
                      icon: Icon(
                        _following
                            ? Icons.person_remove_outlined
                            : Icons.person_add_outlined,
                      ),
                      label: Text(
                        _following ? 'Đang theo dõi' : 'Theo dõi',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _following
                            ? AppColors.textMuted
                            : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FollowListScreen(
                                userId: p.userId,
                                mode: FollowListMode.followers,
                                titleHint: p.displayName ?? p.email,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() => _shopFuture = _load());
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                '${p.followerCount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Người theo dõi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FollowListScreen(
                                userId: p.userId,
                                mode: FollowListMode.following,
                                titleHint: p.displayName ?? p.email,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() => _shopFuture = _load());
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                '${p.followingCount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Đang theo dõi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StarRating(
                        rating: p.averageRating.round().clamp(1, 5),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.averageRating.toStringAsFixed(1)} (${p.reviewCount})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _SectionTitle('ĐANG RAO BÁN (${active.length})'),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  _EmptyBox('Chưa có tin đang bán')
                else
                  ...active.map(
                    (item) => SellerProductTile(
                      item: item,
                      compact: false,
                      onTap: () => _openProduct(item.productId),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitle('ĐÃ BÁN (${sold.length})'),
                const SizedBox(height: 8),
                if (sold.isEmpty)
                  _EmptyBox('Chưa có sản phẩm đã bán')
                else
                  ...sold.map(
                    (item) => SellerProductTile(
                      item: item,
                      compact: false,
                      onTap: () => _openProduct(item.productId),
                    ),
                  ),
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SellerReviewsScreen(
                              userId: p.userId,
                              displayName: p.displayName ?? p.email,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Xem đánh giá'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopData {
  const _ShopData({required this.profile, required this.listings});
  final UserProfile profile;
  final List<SoldListing> listings;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
