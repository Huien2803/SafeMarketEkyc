import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/order.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/screens/order_detail_screen.dart';

String _timeAgoVi(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays < 30) return '${d.inDays} ngày trước';
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  return '$dd/$mm/${t.year}';
}

/// Lịch sử giao dịch — chợ đồ cũ không có giỏ hàng,
/// mỗi đơn = 1 lần liên hệ mua trực tiếp với người bán.
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key, this.initialTab = 0});

  /// 0 = đã mua, 1 = đã bán
  final int initialTab;

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<OrderItem>> _purchasesFuture;
  late Future<List<OrderItem>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _reload();
  }

  void _reload() {
    _purchasesFuture = OrderService.instance.getMyPurchases();
    _salesFuture = OrderService.instance.getMySales();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_purchasesFuture, _salesFuture]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch sử giao dịch',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Đã mua'),
            Tab(text: 'Đã bán'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderListTab(
            future: _purchasesFuture,
            emptyTitle: 'Chưa có đơn mua nào',
            emptySubtitle:
                'Khi bạn liên hệ mua sản phẩm, đơn sẽ hiện ở đây.',
            counterpartyLabel: 'Người bán',
            onRefresh: _refresh,
          ),
          _OrderListTab(
            future: _salesFuture,
            emptyTitle: 'Chưa có đơn bán nào',
            emptySubtitle:
                'Khi có người liên hệ mua sản phẩm của bạn, đơn sẽ hiện ở đây.',
            counterpartyLabel: 'Người mua',
            onRefresh: _refresh,
          ),
        ],
      ),
    );
  }
}

class _OrderListTab extends StatelessWidget {
  const _OrderListTab({
    required this.future,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.counterpartyLabel,
    required this.onRefresh,
  });

  final Future<List<OrderItem>> future;
  final String emptyTitle;
  final String emptySubtitle;
  final String counterpartyLabel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString(),
            onRetry: () => onRefresh(),
          );
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return _EmptyView(title: emptyTitle, subtitle: emptySubtitle);
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _OrderCard(
                order: orders[index],
                counterpartyLabel: counterpartyLabel,
              );
            },
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.counterpartyLabel,
  });

  final OrderItem order;
  final String counterpartyLabel;

  String get _counterpartyName =>
      counterpartyLabel == 'Người bán' ? order.sellerName : order.buyerName;

  Color get _statusColor {
    if (order.isCompleted) return AppColors.trustGreen;
    if (order.orderStatus == 'Cancelled') return AppColors.danger;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(orderId: order.orderId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3EDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.productPriceFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.person_outline,
            label: counterpartyLabel,
            value: _counterpartyName,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Thời gian',
            value: _timeAgoVi(order.createdAt),
          ),
          if (order.shippingAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.notes,
              label: 'Ghi chú',
              value: order.shippingAddress,
            ),
          ],
          if (order.isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.star_outline,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Hoàn tất — có thể đánh giá người bán trong chi tiết đơn',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
