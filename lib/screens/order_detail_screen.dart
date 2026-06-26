import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/order.dart';
import 'package:safemarket_app/models/review.dart';
import 'package:safemarket_app/screens/chat_screen.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/review_service.dart';
import 'package:safemarket_app/widgets/review_submit_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OrderItem> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = OrderService.instance.getOrder(widget.orderId);
      });

  int? get _myId => AuthService.instance.currentUser?.userId;

  bool _isBuyer(OrderItem o) => _myId == o.buyerId;
  bool _isSeller(OrderItem o) => _myId == o.sellerId;

  Future<void> _openChat(OrderItem o) async {
    final sellerId = o.sellerId;
    try {
      final threadId = await ChatService.instance.openThread(
        sellerId: sellerId,
        productId: o.productId,
        orderId: o.orderId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: threadId,
            peerName: o.sellerName,
            subtitle: o.productTitle,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _showReviewDialog(OrderItem o, OrderReviewStatus status) async {
    final reviewingSeller = _isBuyer(o);
    final revieweeName = status.revieweeName ??
        (reviewingSeller ? o.sellerName : o.buyerName);
    final result = await ReviewSubmitDialog.show(
      context,
      revieweeName: revieweeName,
      reviewingSeller: reviewingSeller,
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await ReviewService.instance.submitReview(
        orderId: o.orderId,
        rating: result.rating,
        comment: result.comment,
      );
      if (mounted) {
        final bonus = result.rating == 5 && reviewingSeller
            ? ' Người bán được +30 điểm tin cậy.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cảm ơn bạn đã đánh giá!$bonus')),
        );
      }
    });
  }

  /// Người mua xác nhận đã nhận hàng: bắt buộc chụp/chọn ảnh bằng chứng.
  Future<void> _confirmReceivedWithProof(OrderItem o) async {
    if (_busy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chụp ảnh xác nhận đã nhận hàng',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    await _run(() async {
      await OrderService.instance.markCompleted(o.orderId, proofImage: image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã xác nhận nhận hàng. Người bán đã được thông báo.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _reload();
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
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<OrderItem>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('${snapshot.error ?? "Lỗi"}'));
          }
          final o = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.productTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        o.productPriceFormatted,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow('Mã đơn', '#${o.orderId}'),
                      _InfoRow('Trạng thái', o.statusLabel),
                      _InfoRow('Phương thức', o.methodSummary),
                      _InfoRow('Người bán', o.sellerName),
                      _InfoRow('Người mua', o.buyerName),
                      if (o.escrowStatus != null)
                        _InfoRow('Escrow', o.escrowLabel),
                      _InfoRow(o.addressLabel, o.shippingAddress),
                      if (o.disputeNote != null && o.disputeNote!.isNotEmpty)
                        _InfoRow('Ghi chú khiếu nại', o.disputeNote!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (o.receiptProofUrl != null &&
                    o.receiptProofUrl!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_outlined,
                                size: 18, color: AppColors.trustGreen),
                            const SizedBox(width: 8),
                            Text(
                              _isSeller(o)
                                  ? 'Ảnh người mua xác nhận đã nhận hàng'
                                  : 'Ảnh bạn đã gửi xác nhận nhận hàng',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ApiConfig.mediaUrl(o.receiptProofUrl),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 220,
                              color: AppColors.background,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (o.isShipOrder && o.orderStatus == 'Pending')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Bước 1: Người mua chuyển khoản qua chat\n'
                      'Bước 2: Người bán xác nhận đã nhận tiền\n'
                      'Bước 3: Giao ship → khách xác nhận nhận hàng',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                if (o.isDirectOrder && o.orderStatus == 'Pending')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Hẹn gặp tại địa điểm đã chọn.\n'
                      'Khách trả tiền mặt khi nhận hàng.\n'
                      'Người bán xác nhận giao xong → khách xác nhận nhận hàng.',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _openChat(o),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat trực tiếp với chủ bán'),
                ),
                const SizedBox(height: 12),
                if (_isSeller(o) && o.isShipOrder && o.orderStatus == 'Pending')
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await OrderService.instance
                                  .markPaymentReceived(o.orderId);
                            }),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Đã nhận chuyển khoản'),
                  ),
                if (_isSeller(o) &&
                    o.isShipOrder &&
                    o.orderStatus == 'Paid') ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await OrderService.instance.markShipped(o.orderId);
                            }),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Đã giao ship'),
                  ),
                ],
                if (_isSeller(o) && o.isDirectOrder && o.orderStatus == 'Pending')
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await OrderService.instance
                                  .markDirectHandover(o.orderId);
                            }),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Đã giao trực tiếp & nhận tiền mặt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.trustGreen,
                    ),
                  ),
                if (_isBuyer(o) &&
                    ((o.isShipOrder &&
                            (o.orderStatus == 'Paid' ||
                                o.orderStatus == 'Shipped')) ||
                        (o.isDirectOrder && o.orderStatus == 'Paid'))) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cần chụp ảnh sản phẩm khi nhận để xác nhận. '
                            'Ảnh sẽ gửi cho người bán làm bằng chứng.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _confirmReceivedWithProof(o),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh & xác nhận đã nhận hàng'),
                  ),
                  if (o.isShipOrder) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await OrderService.instance.reportDispute(
                                  orderId: o.orderId,
                                  type: 'NO_RECEIVE',
                                  note: 'Người mua báo không nhận được hàng',
                                );
                              }),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text(
                          'Không nhận được hàng (trừ điểm người bán)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await OrderService.instance.reportDispute(
                                  orderId: o.orderId,
                                  type: 'WRONG_DELIVERY',
                                  note: 'Người mua báo giao hàng sai',
                                );
                              }),
                      icon: const Icon(Icons.warning_amber_outlined),
                      label:
                          const Text('Giao hàng sai (trừ điểm người bán)'),
                    ),
                  ],
                ],
                if (o.orderStatus != 'Completed' &&
                    o.orderStatus != 'Cancelled' &&
                    (_isBuyer(o) || _isSeller(o))) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await OrderService.instance.cancelOrder(
                                o.orderId,
                                reason: 'Hủy đơn (có thể bị trừ điểm nếu đã thanh toán)',
                              );
                            }),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy đơn hàng'),
                  ),
                ],
                if (o.orderStatus == 'Completed')
                  FutureBuilder<OrderReviewStatus>(
                    future:
                        ReviewService.instance.getOrderReviewStatus(o.orderId),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final status = snap.data!;
                      final reviewed = _isBuyer(o)
                          ? status.buyerReviewed
                          : status.sellerReviewed;
                      if (reviewed) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.trustGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppColors.trustGreen),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Bạn đã gửi đánh giá cho giao dịch này',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (!status.canReview) {
                        return const SizedBox.shrink();
                      }
                      final label = _isBuyer(o)
                          ? 'Đánh giá người bán'
                          : 'Đánh giá người mua';
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _showReviewDialog(o, status),
                          icon: const Icon(Icons.star_outline),
                          label: Text(label),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Quy tắc điểm tín nhiệm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• eKYC xong: +50 điểm (người mua & người bán)\n'
                  '• Giao dịch hoàn tất: +15 (mua), +20 (bán)\n'
                  '• Người mua không nhận hàng: người bán -80\n'
                  '• Giao hàng sai: người bán -60\n'
                  '• Hủy đơn sau thanh toán: -30 điểm',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
