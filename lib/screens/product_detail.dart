import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/favorite_product.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/favorites_service.dart';
import 'package:safemarket_app/screens/chat_screen.dart';
import 'package:safemarket_app/screens/order_detail_screen.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/product_service.dart';
import 'package:safemarket_app/services/report_service.dart';
import 'package:safemarket_app/widgets/purchase_method_dialog.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';
import 'package:safemarket_app/widgets/verified_badge.dart';
import 'package:safemarket_app/services/api_config.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ProductService.instance.getProductDetail(widget.productId);
    FavoritesService.instance.load();
  }

  Future<void> _buyProduct(ProductDetail p) async {
    final choice = await showPurchaseMethodDialog(
      context,
      productTitle: p.title,
      defaultAddress: p.location.isNotEmpty ? p.location : null,
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final order = await OrderService.instance.createOrder(
        productId: p.id,
        shippingAddress: choice.address,
        paymentMethod: choice.method.paymentMethod,
        deliveryMethod: choice.method.deliveryMethod,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(orderId: order.orderId),
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
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo cáo người bán / sản phẩm'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Mô tả hành vi lừa đảo hoặc vi phạm...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true || reason.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ReportService.instance.createReport(
        reportedId: p.seller.userId,
        productId: p.id,
        reason: reason,
        severity: 'high',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi báo cáo cho admin')),
        );
      }
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

  Future<void> _chatSeller(ProductDetail p) async {
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
            final fav = FavoriteProduct(
              id: '${p.id}',
              name: p.title,
              price: p.priceFormatted,
              seller: p.seller.displayName ?? p.seller.email,
              location: p.location,
              trustScore: p.seller.kycStatus == 'Verified' ? 850 : 500,
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
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFFBFDBFE),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.seller.displayName ?? p.seller.email,
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
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                      onPressed: _busy ? null : () => _buyProduct(p),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Đặt mua'),
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

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return Container(
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
      );
    }

    if (_urls.length == 1) {
      return Container(
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
      );
    }

    return SizedBox(
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
