import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/screens/order_detail_screen.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/widgets/purchase_method_dialog.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.threadId,
    required this.peerName,
    this.subtitle,
  });

  final int threadId;
  final String peerName;
  final String? subtitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  List<ChatMessage> _messages = [];
  ChatThreadDetail? _thread;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await ChatService.instance.getThreadDetail(widget.threadId);
      final list = await ChatService.instance.getMessages(widget.threadId);
      if (mounted) {
        setState(() {
          _thread = detail;
          _messages = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    _controller.clear();
    try {
      final result =
          await ChatService.instance.sendMessage(widget.threadId, text);
      if (mounted) setState(() => _messages = result.messages);
      if (mounted && result.scamWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
            content: Text(result.scamWarning!),
          ),
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

  Future<void> _purchaseInChat() async {
    final t = _thread;
    if (t == null || !t.canPurchaseInChat) return;

    final choice = await showPurchaseMethodDialog(
      context,
      productTitle: t.productTitle ?? 'Sản phẩm',
      defaultAddress: t.productLocation,
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final list = await ChatService.instance.sendPurchaseRequest(
        widget.threadId,
        choice.address,
        paymentMethod: choice.method.paymentMethod,
        deliveryMethod: choice.method.deliveryMethod,
      );
      final detail =
          await ChatService.instance.getThreadDetail(widget.threadId);
      if (mounted) {
        setState(() {
          _messages = list;
          _thread = detail;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu mua — chờ người bán xác nhận'),
            backgroundColor: AppColors.trustGreen,
          ),
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

  Future<void> _confirmSale(ChatMessage msg) async {
    if (_busy || !msg.isPendingPurchase) return;
    setState(() => _busy = true);
    try {
      final list = await ChatService.instance.confirmSale(
        widget.threadId,
        msg.messageId,
      );
      final detail =
          await ChatService.instance.getThreadDetail(widget.threadId);
      if (mounted) {
        setState(() {
          _messages = list;
          _thread = detail;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận bán — đơn hàng đã tạo'),
            backgroundColor: AppColors.trustGreen,
          ),
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

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (t != null && t.productId != null) _ProductStrip(
            thread: t,
            busy: _busy,
            onPurchase: _purchaseInChat,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Bắt đầu trò chuyện — có thể đặt mua ngay trong chat',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _MessageBubble(
                          message: _messages[i],
                          thread: t,
                          busy: _busy,
                          onConfirmSale: _confirmSale,
                        ),
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
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

class _ProductStrip extends StatelessWidget {
  const _ProductStrip({
    required this.thread,
    required this.busy,
    required this.onPurchase,
  });

  final ChatThreadDetail thread;
  final bool busy;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final hasOrder = thread.orderId != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: ProductThumbnail(
                thumbnailUrl: thread.thumbnailUrl,
                iconSize: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.productTitle ?? 'Sản phẩm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  thread.productPriceFormatted ?? '',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (thread.conditionPct != null)
                  Text(
                    'Tình trạng ${thread.conditionPct}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (hasOrder)
            const Chip(
              label: Text('Đã đặt mua', style: TextStyle(fontSize: 11)),
              backgroundColor: AppColors.ekycVerifiedBg,
            )
          else if (thread.canPurchaseInChat)
            FilledButton(
              onPressed: busy ? null : onPurchase,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Đặt mua'),
            )
          else if (thread.amSeller)
            const Text(
              'Chờ khách đặt mua',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.thread,
    required this.busy,
    required this.onConfirmSale,
  });

  final ChatMessage message;
  final ChatThreadDetail? thread;
  final bool busy;
  final void Function(ChatMessage) onConfirmSale;

  @override
  Widget build(BuildContext context) {
    if (message.isPurchaseRequest || message.isSaleConfirmed) {
      return _SpecialCard(
        message: message,
        thread: thread,
        busy: busy,
        onConfirmSale: onConfirmSale,
      );
    }

    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.mine ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            color: message.mine ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SpecialCard extends StatelessWidget {
  const _SpecialCard({
    required this.message,
    required this.thread,
    required this.busy,
    required this.onConfirmSale,
  });

  final ChatMessage message;
  final ChatThreadDetail? thread;
  final bool busy;
  final void Function(ChatMessage) onConfirmSale;

  @override
  Widget build(BuildContext context) {
    final meta = message.meta;
    final title = meta['title'] as String? ?? message.body;
    final price = meta['priceFormatted'] as String? ?? '';
    final address = meta['shippingAddress'] as String?;
    final condition = meta['conditionPct'];
    final payLabel = meta['paymentMethodLabel'] as String?;
    final delLabel = meta['deliveryMethodLabel'] as String?;
    final thumbnailUrl = meta['thumbnailUrl'] as String? ?? thread?.thumbnailUrl;
    final isDirect = meta['deliveryMethod'] == 'DIRECT';
    final isConfirmed = message.isSaleConfirmed ||
        (message.isPurchaseRequest && !message.isPendingPurchase);
    final orderId = (meta['orderId'] as num?)?.toInt();

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.88,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConfirmed ? AppColors.trustGreen : AppColors.primary,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.shopping_cart_outlined,
                  color: isConfirmed ? AppColors.trustGreen : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.isSaleConfirmed
                        ? 'Đã xác nhận bán'
                        : 'Yêu cầu đặt mua',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isConfirmed
                          ? AppColors.trustGreen
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: ProductThumbnail(
                      thumbnailUrl: thumbnailUrl,
                      iconSize: 28,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (condition != null)
              Text(
                'Tình trạng $condition%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (payLabel != null && delLabel != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(payLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.sellerCardBg,
                  ),
                  Chip(
                    label: Text(delLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.sellerCardBg,
                  ),
                ],
              ),
            ],
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDirect ? Icons.place_outlined : Icons.location_on_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isDirect ? 'Hẹn giao: $address' : 'Giao đến: $address',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (message.isPendingPurchase && thread?.amSeller == true) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => onConfirmSale(message),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Xác nhận bán cho khách'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.trustGreen,
                  ),
                ),
              ),
            ],
            if (message.isPendingPurchase && thread?.amBuyer == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Đang chờ người bán xác nhận...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (isConfirmed && orderId != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => OrderDetailScreen(orderId: orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: Text('Xem đơn hàng #$orderId'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
