import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/screens/order_detail_screen.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/chat_service.dart';
import 'package:safemarket_app/services/chat_upload_service.dart';
import 'package:safemarket_app/widgets/chat_product_card.dart';
import 'package:safemarket_app/widgets/purchase_method_dialog.dart';
import 'package:safemarket_app/widgets/product_thumbnail.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.threadId,
    required this.peerName,
    this.subtitle,
  });

  final String threadId;
  final String peerName;
  final String? subtitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  ChatThreadDetail? _thread;
  bool _loadingThread = true;
  bool _busy = false;
  StreamSubscription<List<ChatMessage>>? _msgSub;
  List<ChatMessage> _messages = [];
  ChatMessage? _replyingTo;

  void _startReply(ChatMessage msg) {
    setState(() => _replyingTo = msg);
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  @override
  void initState() {
    super.initState();
    _loadThread();
    ChatService.instance.markThreadRead(widget.threadId);
    _msgSub = ChatService.instance
        .watchMessages(widget.threadId)
        .listen((list) {
      if (!mounted) return;
      setState(() => _messages = list);
      ChatService.instance.markThreadRead(widget.threadId);
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadThread({bool showLoading = true}) async {
    if (showLoading) setState(() => _loadingThread = true);
    try {
      final detail =
          await ChatService.instance.getThreadDetail(widget.threadId);
      if (mounted) setState(() => _thread = detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted && showLoading) setState(() => _loadingThread = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    final replyTo = _replyingTo;
    setState(() {
      _busy = true;
      _replyingTo = null;
    });
    _controller.clear();
    try {
      final result = await ChatService.instance
          .sendMessage(widget.threadId, text, replyTo: replyTo);
      if (result.scamWarning != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.scamWarning!),
            backgroundColor: AppColors.warning,
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

  Future<void> _pickAndSendImage() async {
    if (_busy) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final replyTo = _replyingTo;
    setState(() {
      _busy = true;
      _replyingTo = null;
    });
    try {
      final path = await ChatUploadService.instance.uploadChatImage(file);
      await ChatService.instance
          .sendImage(widget.threadId, path, replyTo: replyTo);
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
    if (t == null || !t.canPurchaseInChat) {
      if (mounted && AuthService.instance.currentUser?.isAdmin == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tài khoản quản trị không được mua sản phẩm.',
            ),
          ),
        );
      }
      return;
    }

    final choice = await showPurchaseMethodDialog(
      context,
      productTitle: t.productTitle ?? 'Sản phẩm',
      defaultAddress: t.productLocation,
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ChatService.instance.sendPurchaseRequest(
        widget.threadId,
        choice.address,
        paymentMethod: choice.method.paymentMethod,
        deliveryMethod: choice.method.deliveryMethod,
      );
      final detail =
          await ChatService.instance.getThreadDetail(widget.threadId);
      if (mounted) {
        setState(() => _thread = detail);
        final isOnline = choice.method.isOnlineEscrow;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Đã tạo đơn — vào chi tiết đơn để thanh toán online (escrow)'
                  : 'Đã gửi yêu cầu mua — chờ người bán xác nhận',
            ),
            backgroundColor: AppColors.trustGreen,
            action: isOnline && detail.orderId != null
                ? SnackBarAction(
                    label: 'Thanh toán',
                    onPressed: () {
                      _openOrderDetail(detail.orderId!);
                    },
                  )
                : null,
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
      await _loadThread(showLoading: false);
      await ChatService.instance.confirmSale(widget.threadId, msg.messageId);
      final detail =
          await ChatService.instance.getThreadDetail(widget.threadId);
      if (mounted) {
        setState(() => _thread = detail);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận bán / giao hàng'),
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

  Future<void> _openOrderDetail(int orderId) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ),
    );
    if (!mounted) return;
    await ChatService.instance.syncThreadOrderFromApi(widget.threadId, orderId);
    await _loadThread();
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
            Row(
              children: [
                Expanded(child: Text(widget.peerName)),
                if (!_loadingThread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.trustGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (t != null && t.showProductStrip)
            _ProductStrip(
              thread: t,
              busy: _busy,
              onPurchase: _purchaseInChat,
            ),
          Expanded(
            child: _loadingThread && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Bắt đầu trò chuyện — tin nhắn đồng bộ realtime qua Firebase',
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
                          onOpenOrder: _openOrderDetail,
                          onReply: _startReply,
                        ),
                      ),
          ),
          if (_replyingTo != null) _ReplyPreviewBar(
            message: _replyingTo!,
            onCancel: _cancelReply,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : _pickAndSendImage,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Gửi ảnh',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
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

// _ProductStrip, _MessageBubble, _SpecialCard — giữ nguyên từ bản cũ
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
          if (thread.canPurchaseInChat)
            FilledButton(
              onPressed: busy ? null : onPurchase,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Đặt mua'),
            )
          else if (thread.productTakenByOther)
            Chip(
              label: Text(
                thread.purchaseBlockedLabel,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: const Color(0xFFFEE2E2),
            )
          else if (thread.amSeller)
            Text(
              thread.productStatus == 'Reserved' ||
                      thread.productStatus == 'Sold'
                  ? thread.purchaseBlockedLabel
                  : 'Chờ khách đặt mua',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
    required this.onOpenOrder,
    required this.onReply,
  });

  final ChatMessage message;
  final ChatThreadDetail? thread;
  final bool busy;
  final void Function(ChatMessage) onConfirmSale;
  final void Function(int orderId) onOpenOrder;
  final void Function(ChatMessage) onReply;

  @override
  Widget build(BuildContext context) {
    if (message.isProductCard) {
      return Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChatProductCard(meta: message.meta, mine: message.mine),
        ),
      );
    }

    if (message.isImage) {
      final rawUrl = message.meta['imageUrl'] as String? ?? '';
      final url = ApiConfig.mediaUrl(rawUrl);
      return Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => onReply(message),
          child: Column(
            crossAxisAlignment: message.mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.replyTo != null)
                _ReplyQuote(reply: message.replyTo!, mine: message.mine),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.65,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: message.mine
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.textMuted.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 120,
                            width: 120,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 100,
                          width: 100,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      )
                    : const SizedBox(
                        height: 100,
                        width: 100,
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.isPurchaseRequest || message.isSaleConfirmed) {
      return _SpecialCard(
        message: message,
        thread: thread,
        busy: busy,
        onConfirmSale: onConfirmSale,
        onOpenOrder: onOpenOrder,
      );
    }

    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => onReply(message),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyTo != null) ...[
                _ReplyQuote(
                  reply: message.replyTo!,
                  mine: message.mine,
                  inBubble: true,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.body,
                style: TextStyle(
                  color: message.mine ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khối trích dẫn tin nhắn gốc, hiển thị bên trong/bên trên bong bóng.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    required this.mine,
    this.inBubble = false,
  });

  final ReplyInfo reply;
  final bool mine;
  final bool inBubble;

  @override
  Widget build(BuildContext context) {
    final onPrimary = mine && inBubble;
    final barColor = onPrimary ? AppColors.white : AppColors.primary;
    final nameColor = onPrimary
        ? AppColors.white
        : AppColors.primary;
    final textColor = onPrimary
        ? AppColors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;
    final bg = onPrimary
        ? AppColors.white.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.08);

    return Container(
      margin: inBubble
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.senderName.isEmpty ? 'Tin nhắn' : reply.senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: nameColor,
            ),
          ),
          Text(
            reply.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }
}

/// Thanh xem trước phía trên ô nhập khi đang soạn trả lời.
class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trả lời ${message.senderName.isEmpty ? '' : message.senderName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    message.replyPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
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
    required this.onOpenOrder,
  });

  final ChatMessage message;
  final ChatThreadDetail? thread;
  final bool busy;
  final void Function(ChatMessage) onConfirmSale;
  final void Function(int orderId) onOpenOrder;

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
    final orderId = (meta['orderId'] as num?)?.toInt() ?? thread?.orderId;
    final payMethod =
        thread?.paymentMethod ?? meta['paymentMethod'] as String?;
    final isOnlineEscrow = payMethod == 'ONLINE_ESCROW';
    final buyerNeedsPay = message.isPendingPurchase &&
        thread?.amBuyer == true &&
        (thread?.needsBuyerOnlinePayment ?? false);
    final sellerWaitingPay = message.isPendingPurchase &&
        thread?.amSeller == true &&
        isOnlineEscrow &&
        (thread?.needsBuyerOnlinePayment ?? false);
    final sellerCanConfirm = message.isPendingPurchase &&
        thread?.amSeller == true &&
        (thread?.sellerCanConfirmPurchase ?? !isOnlineEscrow);

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
                    message.isCancelledPurchase
                        ? 'Đã hủy yêu cầu mua'
                        : message.isSaleConfirmed
                            ? 'Đã xác nhận bán'
                            : 'Yêu cầu đặt mua',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: message.isCancelledPurchase
                          ? AppColors.textMuted
                          : isConfirmed
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
            if (sellerWaitingPay) ...[
              const SizedBox(height: 12),
              const Text(
                'Chờ khách thanh toán online (escrow). '
                'Sau khi khách trả xong bạn mới xác nhận bán được.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (orderId != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => onOpenOrder(orderId!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới / xem đơn'),
                ),
              ],
            ],
            if (sellerCanConfirm) ...[
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
            if (buyerNeedsPay) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => onOpenOrder(orderId!),
                  icon: const Icon(Icons.payment_outlined),
                  label: const Text('Thanh toán online (Escrow)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.trustGreen,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nếu bạn thoát giữa chừng, bấm lại nút này để tiếp tục thanh toán.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else if (message.isPendingPurchase &&
                thread?.amBuyer == true) ...[
              const SizedBox(height: 8),
              Text(
                isOnlineEscrow && !(thread?.needsBuyerOnlinePayment ?? true)
                    ? 'Đã thanh toán escrow — chờ người bán xác nhận...'
                    : 'Đang chờ người bán xác nhận...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (message.isCancelledPurchase) ...[
              const SizedBox(height: 8),
              const Text(
                'Yêu cầu mua này đã bị hủy. Bạn có thể đặt mua lại nếu sản phẩm còn.',
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
                onPressed: () => onOpenOrder(orderId),
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
