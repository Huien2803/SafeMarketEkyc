import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/favorite_product.dart';
import 'package:safemarket_app/models/auth_user.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/models/product_comment.dart';
import 'package:safemarket_app/services/favorites_service.dart';
import 'package:safemarket_app/services/product_comment_service.dart';
import 'package:safemarket_app/screens/chat_screen.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/product_service.dart';
import 'package:safemarket_app/widgets/report_violation_sheet.dart';
import 'package:safemarket_app/widgets/login_required.dart';
import 'package:safemarket_app/widgets/product_status_badge.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';
import 'package:safemarket_app/widgets/verified_badge.dart';
import 'package:safemarket_app/models/sold_listing.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/widgets/seller_product_tile.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/screens/public_profile_screen.dart';
import 'package:safemarket_app/services/follow_service.dart';
import 'package:safemarket_app/widgets/star_rating.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductDetail> _future;
  bool _busy = false;
  bool _followingSeller = false;
  bool _followLoading = false;
  int? _followCheckedSellerId;

  @override
  void initState() {
    super.initState();
    _future = ProductService.instance.getProductDetail(widget.productId);
    FavoritesService.instance.load();
  }

  Future<void> _loadFollowStatus(int sellerId) async {
    if (!AuthService.instance.isLoggedIn) return;
    if (AuthService.instance.currentUser?.userId == sellerId) return;
    try {
      final status = await FollowService.instance.getStatus(sellerId);
      if (mounted) setState(() => _followingSeller = status.following);
    } catch (_) {}
  }

  Future<void> _toggleFollowSeller(int sellerId) async {
    if (_followLoading) return;
    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để theo dõi người bán này.',
    );
    if (!ok || !mounted) return;
    setState(() => _followLoading = true);
    try {
      if (_followingSeller) {
        await FollowService.instance.unfollow(sellerId);
      } else {
        await FollowService.instance.follow(sellerId);
      }
      if (mounted) setState(() => _followingSeller = !_followingSeller);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  /// Mở chat với người bán và tự gửi thẻ sản phẩm (kiểu Shopee).
  Future<void> _buyViaChat(ProductDetail p) async {
    if (!p.isPurchasable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.isSold
                ? 'Sản phẩm đã được bán'
                : 'Sản phẩm không còn khả dụng để mua',
          ),
        ),
      );
      return;
    }
    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để đặt mua sản phẩm này.',
    );
    if (!ok || !mounted) return;
    final verified = await ensureEkycVerified(
      context,
      message: 'Bạn cần xác thực danh tính (eKYC) trước khi mua hàng.',
    );
    if (!verified || !mounted) return;
    if (AuthService.instance.currentUser?.userId == p.seller.userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không thể mua sản phẩm của chính mình')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final threadId = await ChatService.instance.openThread(
        sellerId: p.seller.userId,
        productId: p.id,
        sellerName: p.seller.displayName ?? p.seller.email,
      );
      await ChatService.instance.sendProductCard(threadId, p);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: threadId,
            peerName: p.seller.displayName ?? p.seller.email,
            subtitle: p.title,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportProduct(ProductDetail p) async {
    final sent = await showReportViolationSheet(
      context,
      reportedUserId: p.seller.userId,
      targetLabel: p.seller.displayName ?? p.seller.email,
      productId: p.id,
      productTitle: p.title,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi báo cáo — admin sẽ kiểm duyệt'),
          backgroundColor: AppColors.trustGreen,
        ),
      );
    }
  }

  Future<void> _chatSeller(ProductDetail p) async {
    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để nhắn tin với người bán.',
    );
    if (!ok || !mounted) return;
    if (AuthService.instance.currentUser?.userId == p.seller.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là sản phẩm của bạn')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final threadId = await ChatService.instance.openThread(
        sellerId: p.seller.userId,
        productId: p.id,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: threadId,
            peerName: p.seller.displayName ?? p.seller.email,
            subtitle: p.title,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<ProductDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error ?? "Lỗi"}'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _future = ProductService.instance
                              .getProductDetail(widget.productId);
                        }),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final p = snapshot.data!;
            if (_followCheckedSellerId != p.seller.userId) {
              _followCheckedSellerId = p.seller.userId;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadFollowStatus(p.seller.userId);
              });
            }
            final fav = FavoriteProduct(
              id: '${p.id}',
              name: p.title,
              price: p.priceFormatted,
              seller: p.seller.displayName ?? p.seller.email,
              location: p.location,
              trustScore: p.seller.kycStatus == 'Verified' ? 850 : 500,
              thumbnailUrl: p.thumbnailUrl ??
                  (p.imageUrls.isNotEmpty ? p.imageUrls.first : null),
            );
            final initials = (p.seller.displayName ?? p.seller.email)
                .trim()
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      if (AuthService.instance.isLoggedIn)
                        IconButton(
                          tooltip: 'Báo cáo vi phạm',
                          icon: const Icon(Icons.flag_outlined),
                          onPressed: _busy
                              ? null
                              : () => _reportProduct(p),
                        ),
                      ListenableBuilder(
                        listenable: FavoritesService.instance,
                        builder: (_, __) {
                          final liked = FavoritesService.instance
                              .isFavorite('${p.id}');
                          return IconButton(
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked ? AppColors.primary : null,
                            ),
                            onPressed: () =>
                                FavoritesService.instance.toggle(fav),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProductImages(product: p),
                        const SizedBox(height: 20),
                        Text(
                          p.priceFormatted,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: p.location,
                        ),
                        const SizedBox(height: 8),
                        _MetaChip(
                          icon: Icons.verified_outlined,
                          label: 'Tình trạng ${p.conditionPct}%',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          p.description.isNotEmpty
                              ? p.description
                              : 'Chưa có mô tả chi tiết.',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.sellerCardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => PublicProfileScreen(
                                          userId: p.seller.userId,
                                          displayNameHint:
                                              p.seller.displayName ??
                                                  p.seller.email,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor:
                                                const Color(0xFFBFDBFE),
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          if (p.seller.kycStatus == 'Verified')
                                            const Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: VerifiedBadge(size: 20),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.seller.displayName ??
                                                  p.seller.email,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              p.seller.email,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (p.seller.reviewCount > 0) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  StarRating(
                                                    rating: p.seller
                                                        .averageRating
                                                        .round()
                                                        .clamp(1, 5),
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${p.seller.averageRating.toStringAsFixed(1)} (${p.seller.reviewCount})',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (AuthService.instance.currentUser?.userId !=
                                  p.seller.userId)
                                OutlinedButton.icon(
                                  onPressed: _followLoading
                                      ? null
                                      : () => _toggleFollowSeller(
                                            p.seller.userId,
                                          ),
                                  icon: Icon(
                                    _followingSeller
                                        ? Icons.check
                                        : Icons.person_add_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _followingSeller
                                        ? 'Đang theo dõi'
                                        : 'Theo dõi',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SellerProductsSection(
                          seller: p.seller,
                          currentProductId: p.id,
                        ),
                        const SizedBox(height: 24),
                        _ProductComments(
                          productId: p.id,
                          sellerId: p.seller.userId,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<ProductDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final p = snapshot.data!;
          final canBuy = p.isPurchasable;
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            color: AppColors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _chatSeller(p),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_busy || !canBuy) ? null : () => _buyViaChat(p),
                      icon: Icon(
                        p.isSold
                            ? Icons.check_circle_outline
                            : Icons.shopping_cart_outlined,
                      ),
                      label: Text(p.isSold ? 'Đã bán' : 'Đặt mua'),
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
}

class _ProductImages extends StatelessWidget {
  const _ProductImages({required this.product});

  final ProductDetail product;

  List<String> get _urls {
    final urls = <String>[];
    for (final u in product.imageUrls) {
      final full = ApiConfig.mediaUrl(u);
      if (full.isNotEmpty) urls.add(full);
    }
    if (urls.isEmpty) {
      final thumb = ApiConfig.mediaUrl(product.thumbnailUrl);
      if (thumb.isNotEmpty) urls.add(thumb);
    }
    return urls;
  }

  Widget _wrapWithStatus(Widget child) {
    final showBadge = product.isSold || product.status == 'Reserved';
    if (!showBadge) return child;

    return Stack(
      children: [
        child,
        Positioned(
          top: 12,
          left: 12,
          child: ProductStatusBadge(status: product.status),
        ),
        if (product.isSold)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return _wrapWithStatus(
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: ProductThumbnail(
            thumbnailUrl: product.thumbnailUrl,
            iconSize: 80,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    if (_urls.length == 1) {
      return _wrapWithStatus(
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              _urls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ProductThumbnail(
                thumbnailUrl: product.thumbnailUrl,
                iconSize: 80,
              ),
            ),
          ),
        ),
      );
    }

    return _wrapWithStatus(
      SizedBox(
        height: 220,
        child: PageView.builder(
          itemCount: _urls.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                _urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ProductThumbnail(
                  thumbnailUrl: product.thumbnailUrl,
                  iconSize: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerProductsSection extends StatelessWidget {
  const _SellerProductsSection({
    required this.seller,
    required this.currentProductId,
  });

  final AuthUser seller;
  final int currentProductId;

  void _openShop(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          userId: seller.userId,
          displayNameHint: seller.displayName ?? seller.email,
        ),
      ),
    );
  }

  void _openProduct(BuildContext context, int productId) {
    if (productId == currentProductId) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: productId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SoldListing>>(
      future: OrderService.instance.getUserListings(seller.userId),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final active = all
            .where((s) => s.isActive && s.productId != currentProductId)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SẢN PHẨM CỦA NGƯỜI BÁN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => _openShop(context),
                  child: const Text('Xem shop'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (active.isEmpty)
              GestureDetector(
                onTap: () => _openShop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: const Text(
                    'Xem shop để biết thêm sản phẩm khác của người bán.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 168,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: active.length,
                  itemBuilder: (context, i) {
                    final item = active[i];
                    return SellerProductTile(
                      item: item,
                      onTap: () => _openProduct(context, item.productId),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ====================================================================
///  Khu vực bình luận sản phẩm (realtime, công khai)
/// ====================================================================
class _ProductComments extends StatefulWidget {
  const _ProductComments({required this.productId, required this.sellerId});

  final int productId;
  final int sellerId;

  @override
  State<_ProductComments> createState() => _ProductCommentsState();
}

class _ProductCommentsState extends State<_ProductComments> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  ProductComment? _replyTo;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startReply(ProductComment c) {
    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final ok = await ensureLoggedIn(
      context,
      message: 'Đăng nhập để bình luận về sản phẩm.',
    );
    if (!ok || !mounted) return;

    final reply = _replyTo;
    setState(() => _sending = true);
    try {
      await ProductCommentService.instance.add(
        widget.productId,
        text,
        parentId: reply?.parentId ?? reply?.id,
        parentUserName: reply?.userName,
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() => _replyTo = null);
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ProductComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá bình luận'),
        content: const Text('Bạn có chắc muốn xoá bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProductCommentService.instance.delete(widget.productId, c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductComment>>(
      stream: ProductCommentService.instance.watch(widget.productId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ProductComment>[];
        final roots = all.where((c) => !c.isReply).toList();
        final repliesByParent = <String, List<ProductComment>>{};
        for (final c in all.where((c) => c.isReply)) {
          repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'BÌNH LUẬN (${all.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInput(),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting &&
                all.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (roots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: const Text(
                  'Chưa có bình luận. Hãy là người đầu tiên đặt câu hỏi cho người bán!',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              )
            else
              ...roots.map((c) {
                final replies = repliesByParent[c.id] ?? const [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommentTile(
                      comment: c,
                      isSeller: c.userId == widget.sellerId,
                      onReply: () => _startReply(c),
                      onDelete: c.mine ? () => _delete(c) : null,
                    ),
                    ...replies.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: _CommentTile(
                          comment: r,
                          isSeller: r.userId == widget.sellerId,
                          onReply: () => _startReply(c),
                          onDelete: r.mine ? () => _delete(r) : null,
                        ),
                      ),
                    ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Trả lời ${_replyTo!.userName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _cancelReply,
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _replyTo != null
                      ? 'Nhập phản hồi...'
                      : 'Viết bình luận hoặc câu hỏi...',
                  filled: true,
                  fillColor: AppColors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isSeller,
    required this.onReply,
    this.onDelete,
  });

  final ProductComment comment;
  final bool isSeller;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  String get _initials {
    final parts = comment.userName.trim().split(RegExp(r'\s+'));
    return parts
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays < 30) return '${d.inDays} ngày trước';
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '$dd/$mm/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFBFDBFE),
            child: Text(
              _initials.isEmpty ? '?' : _initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isSeller) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Người bán',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    InkWell(
                      onTap: onReply,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Trả lời',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: onDelete,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Xoá',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
