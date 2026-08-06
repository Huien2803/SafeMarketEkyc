import 'dart:typed_data';

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
import 'package:safemarket_app/services/payment_service.dart';
import 'package:safemarket_app/services/review_service.dart';
import 'package:safemarket_app/widgets/purchase_method_dialog.dart';
import 'package:safemarket_app/widgets/review_submit_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  late Future<OrderItem> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
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
        final who = reviewingSeller ? 'Người bán' : 'Người mua';
        final impact = switch (result.rating) {
          5 => ' $who được +30 điểm tín nhiệm.',
          3 => ' $who bị −10 điểm tín nhiệm.',
          2 => ' $who bị −20 điểm tín nhiệm.',
          1 => ' $who bị −30 điểm tín nhiệm.',
          _ => '', // 4 sao: không đổi điểm
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cảm ơn bạn đã đánh giá!$impact')),
        );
      }
    });
  }

  /// Người mua xác nhận đã nhận hàng: bắt buộc chụp ảnh rồi mới gửi xác nhận.
  Future<void> _confirmReceivedWithProof(OrderItem o) async {
    if (_busy) return;
    final image = await showModalBottomSheet<XFile>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => const _ReceiptProofSheet(),
    );
    if (image == null || !mounted) return;

    await _run(() async {
      await OrderService.instance.markCompleted(o.orderId, proofImage: image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã xác nhận nhận hàng kèm ảnh. Người bán đã được thông báo.',
            ),
          ),
        );
      }
    });
  }

  /// Người mua đổi phương thức thanh toán khi đơn còn chờ xử lý.
  Future<void> _changePaymentMethod(OrderItem o) async {
    final result = await showPurchaseMethodDialog(
      context,
      productTitle: o.productTitle,
      defaultAddress: o.shippingAddress,
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await OrderService.instance.changePaymentMethod(
        o.orderId,
        paymentMethod: result.method.paymentMethod,
        deliveryMethod: result.method.deliveryMethod,
        shippingAddress: result.address,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật phương thức thanh toán')),
        );
      }
    });
  }

  /// Hủy đơn: xác nhận + cho nhập lý do. Cảnh báo hoàn tiền/trừ điểm nếu đã trả.
  Future<void> _cancelOrder(OrderItem o) async {
    if (_busy) return;
    final reasonCtrl = TextEditingController();
    final paid = o.orderStatus == 'Paid' || o.orderStatus == 'Shipped';
    final holdingEscrow = o.isOnlineEscrow && o.escrowStatus == 'Holding';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              holdingEscrow
                  ? 'Tiền escrow đang tạm giữ sẽ được hoàn lại cho người mua.'
                  : paid
                      ? 'Đơn đã thanh toán — hủy lúc này có thể bị trừ điểm tín nhiệm.'
                      : 'Bạn có chắc muốn hủy đơn hàng này? '
                          'Thao tác này không mở cổng thanh toán.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy (không bắt buộc)',
                hintText: 'VD: Đổi ý, tìm được sản phẩm khác...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ đơn'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || !mounted) return;

    // Khóa mọi nút NGAY (tránh tap xuyên dialog trúng "Thanh toán online").
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    try {
      await OrderService.instance.cancelOrder(
        o.orderId,
        reason: reason.isNotEmpty ? reason : 'Người dùng hủy đơn',
      );
      await ChatService.instance.releaseCancelledOrder(o.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              holdingEscrow
                  ? 'Đã hủy đơn. Tiền escrow sẽ được hoàn cho người mua.'
                  : 'Đã hủy đơn hàng.',
            ),
          ),
        );
        _reload();
      }
    } catch (e) {
      if (mounted) {
        final raw = '$e';
        final msg = raw
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .replaceFirst(RegExp(r'^AuthException\(\d+\):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payOnlineEscrow(OrderItem o) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thanh toán online'),
        content: const Text(
          'Bạn sẽ thanh toán escrow qua VNPay (hoặc demo nếu chưa cấu hình). '
          'Tiền được tạm giữ đến khi giao dịch hoàn tất.\n\n'
          'Nếu chỉ muốn hủy đơn, hãy đóng hộp thoại này và bấm «Hủy đơn hàng».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.trustGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tiếp tục thanh toán'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    try {
      final msg = await PaymentService.instance.payOrder(o.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg ??
                  'Mở cổng thanh toán. Nếu thoát giữa chừng, quay lại màn này '
                  'và bấm "Thanh toán online" lần nữa.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        _reload();
      }
    } catch (e) {
      if (mounted) {
        final raw = '$e';
        final msg = raw
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .replaceFirst(RegExp(r'^AuthException\(\d+\):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) {
        final raw = '$e';
        final msg = raw
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .replaceFirst(RegExp(r'^AuthException\(\d+\):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
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
                      if (o.escrowStatus != null || o.isOnlineEscrow)
                        _InfoRow('Escrow', o.escrowLabel),
                      if (o.isOnlineEscrow && o.escrowAmount > 0)
                        _InfoRow(
                          'Số tiền giữ',
                          o.productPriceFormatted,
                        ),
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
                if (o.isOnlineEscrow && o.orderStatus == 'Pending')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Thanh toán Escrow SafeMarket',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          o.isDirectDelivery
                              ? '1. Người mua thanh toán online → tiền tạm giữ\n'
                                  '2. Người bán bấm «Xác nhận bán cho khách» (chat)\n'
                                  '3. Người mua nhận hàng → chụp ảnh xác nhận\n'
                                  '4. Hệ thống giải ngân cho người bán'
                              : '1. Người mua thanh toán online → tiền tạm giữ\n'
                                  '2. Người bán bấm «Xác nhận bán» rồi giao ship\n'
                                  '3. Người mua nhận hàng → chụp ảnh xác nhận\n'
                                  '4. Hệ thống giải ngân cho người bán',
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                if (o.isShipOrder && o.orderStatus == 'Pending' && !o.isOnlineEscrow)
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
                      'Bước 1: Hẹn gặp — khách trả tiền mặt khi nhận\n'
                      'Bước 2: Người bán bấm xác nhận đã giao & nhận tiền\n'
                      'Bước 3: Người mua chụp ảnh xác nhận nhận hàng',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                if (_isBuyer(o) &&
                    o.orderStatus == 'Pending' &&
                    !o.needsOnlinePayment)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Đơn đã đặt. Đang chờ người bán xác nhận giao hàng '
                      '— bạn chưa thể tự xác nhận nhận hàng.',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                if (_isBuyer(o) &&
                    o.isShipOrder &&
                    o.orderStatus == 'Paid')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Người bán đã nhận tiền. Chờ người bán giao ship '
                      'rồi bạn mới xác nhận nhận hàng.',
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
                if (_isBuyer(o) && o.orderStatus == 'Pending') ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _changePaymentMethod(o),
                    icon: const Icon(Icons.swap_horiz_outlined),
                    label: const Text('Đổi phương thức thanh toán'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_isBuyer(o) && o.needsOnlinePayment) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _payOnlineEscrow(o),
                    icon: const Icon(Icons.payment_outlined),
                    label: const Text('Thanh toán online (Escrow)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.trustGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _cancelOrder(o),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy đơn (chưa thanh toán)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_isSeller(o) &&
                    o.isOnlineEscrow &&
                    o.isDirectDelivery &&
                    o.orderStatus == 'Paid')
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await OrderService.instance
                                  .markDirectHandover(o.orderId);
                            }),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Xác nhận đã giao hàng trực tiếp'),
                  ),
                if (_isSeller(o) && o.isShipOrder && o.orderStatus == 'Pending' && !o.isOnlineEscrow)
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
                    label: const Text('Xác nhận đã giao ship'),
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
                    label: const Text('Xác nhận đã giao & nhận tiền mặt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.trustGreen,
                    ),
                  ),
                if (_isBuyer(o) &&
                    o.isOnlineEscrow &&
                    o.isDirectDelivery &&
                    o.orderStatus == 'Paid')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Bạn đã thanh toán escrow. '
                      'Chờ người bán bấm «Xác nhận bán / đã giao» trong chat '
                      'rồi bạn mới được chụp ảnh xác nhận nhận hàng.',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                if (_isBuyer(o) && o.buyerCanConfirmReceived) ...[
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
                            'Bắt buộc: chụp ảnh sản phẩm khi nhận hàng, '
                            'rồi bấm xác nhận. Không có ảnh thì không hoàn tất đơn '
                            'và escrow chưa giải ngân.',
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
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã gửi khiếu nại. Admin sẽ xử lý hoàn/giải ngân.',
                                      ),
                                    ),
                                  );
                                }
                              }),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Không nhận được hàng — khiếu nại'),
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
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã gửi khiếu nại. Admin sẽ xử lý hoàn/giải ngân.',
                                      ),
                                    ),
                                  );
                                }
                              }),
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: const Text('Giao hàng sai — khiếu nại'),
                    ),
                  ],
                ],
                if (o.orderStatus == 'Disputed') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Đơn đang khiếu nại — chờ quản trị viên quyết định '
                      'hoàn tiền người mua hoặc giải ngân người bán. '
                      'Không thể tự hủy đơn ở bước này.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
                if (o.orderStatus != 'Completed' &&
                    o.orderStatus != 'Cancelled' &&
                    o.orderStatus != 'Disputed' &&
                    (_isBuyer(o) || _isSeller(o)) &&
                    // Buyer chưa trả escrow: đã có nút hủy ngay dưới nút thanh toán.
                    !(o.needsOnlinePayment && _isBuyer(o))) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _cancelOrder(o),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy đơn hàng'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
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
                  '• Giao dịch hoàn tất: +20 điểm mỗi bên\n'
                  '• Đánh giá 5★: +30 | 4★: không đổi\n'
                  '• Đánh giá 3★: −10 | 2★: −20 | 1★: −30\n'
                  '• Người mua không nhận hàng: người bán −80\n'
                  '• Giao hàng sai: người bán −60\n'
                  '• Hủy đơn sau thanh toán: −30 điểm',
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

/// Sheet bắt buộc: chọn/chụp ảnh → xem trước → mới được xác nhận nhận hàng.
class _ReceiptProofSheet extends StatefulWidget {
  const _ReceiptProofSheet();

  @override
  State<_ReceiptProofSheet> createState() => _ReceiptProofSheetState();
}

class _ReceiptProofSheetState extends State<_ReceiptProofSheet> {
  final _picker = ImagePicker();
  XFile? _image;
  Uint8List? _previewBytes;
  bool _picking = false;

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ảnh không hợp lệ — vui lòng chụp lại')),
          );
        }
        return;
      }
      setState(() {
        _image = file;
        _previewBytes = bytes;
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xác nhận đã nhận hàng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bước bắt buộc: phải có ảnh bằng chứng khi nhận hàng '
            'trước khi hoàn tất đơn.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _previewBytes!,
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 40, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có ảnh — chưa thể xác nhận',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _picking ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_image == null ? 'Chụp ảnh' : 'Chụp lại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _picking ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_image == null || _picking)
                ? null
                : () => Navigator.pop(context, _image),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _image == null
                  ? 'Chụp ảnh trước để xác nhận'
                  : 'Xác nhận đã nhận hàng',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.trustGreen,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
