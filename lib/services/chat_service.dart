import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/models/order.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/firebase_chat_service.dart';
import 'package:safemarket_app/services/order_service.dart';
import 'package:safemarket_app/services/user_service.dart';

/// Chat realtime (Firebase) + đơn hàng (NestJS API).
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _firebase = FirebaseChatService.instance;

  Stream<List<ChatThread>> watchThreads() {
    final userId = AuthService.instance.currentUser?.userId ?? 0;
    return _firebase.watchUserThreads(userId);
  }

  Stream<int> watchTotalUnread() {
    final userId = AuthService.instance.currentUser?.userId ?? 0;
    return _firebase.watchTotalUnread(userId);
  }

  Future<void> markThreadRead(String threadId) {
    final userId = AuthService.instance.currentUser?.userId ?? 0;
    return _firebase.markThreadRead(threadId, userId);
  }

  Stream<List<ChatMessage>> watchMessages(String threadId) {
    final userId = AuthService.instance.currentUser?.userId ?? 0;
    return _firebase.watchMessages(threadId, userId);
  }

  Future<String> openThread({
    required int sellerId,
    int? productId,
    int? orderId,
    String? sellerName,
  }) async {
    return _firebase.openThread(
      sellerId: sellerId,
      productId: productId,
      orderId: orderId,
      sellerName: sellerName,
    );
  }

  Future<ChatThreadDetail> getThreadDetail(String threadId) {
    return _firebase.getThreadDetail(threadId);
  }

  /// @deprecated Dùng [watchThreads] cho realtime
  Future<List<ChatThread>> getThreads() async {
    final userId = AuthService.instance.currentUser?.userId ?? 0;
    return _firebase.watchUserThreads(userId).first;
  }

  Future<void> sendProductCard(String threadId, ProductDetail product) {
    final thumbnail = product.thumbnailUrl ??
        (product.imageUrls.isNotEmpty ? product.imageUrls.first : null);
    return _firebase.sendProductCardMessage(
      threadId: threadId,
      productMeta: {
        'productId': product.id,
        'title': product.title,
        'price': product.price,
        'priceFormatted': product.priceFormatted,
        'conditionPct': product.conditionPct,
        'thumbnailUrl': thumbnail,
        'location': product.location,
        'status': product.status,
      },
    );
  }

  Future<void> sendImage(
    String threadId,
    String imageUrl, {
    ChatMessage? replyTo,
  }) {
    return _firebase.sendImageMessage(
      threadId,
      imageUrl,
      replyTo: _replyMap(replyTo),
    );
  }

  Map<String, dynamic>? _replyMap(ChatMessage? replyTo) {
    if (replyTo == null) return null;
    return ReplyInfo(
      messageId: replyTo.messageId,
      senderName: replyTo.senderName,
      preview: replyTo.replyPreview,
      type: replyTo.messageType,
    ).toMap();
  }

  Future<SendMessageResult> sendMessage(
    String threadId,
    String body, {
    ChatMessage? replyTo,
  }) async {
    final detail = await getThreadDetail(threadId);
    final myId = AuthService.instance.currentUser?.userId ?? 0;
    final peerId = myId == detail.buyerId ? detail.sellerId : detail.buyerId;

    String? scamWarning;
    try {
      final peerProfile = await UserService.instance.getProfile(peerId);
      final score = peerProfile.trustScore?.currentPoint ?? 500;
      if (score < 300) {
        scamWarning =
            'Cảnh báo: Người này có điểm tín nhiệm thấp ($score/1000). '
            'Nên giao dịch qua escrow SafeMarket.';
      }
    } catch (_) {}

    await _firebase.sendTextMessage(threadId, body, replyTo: _replyMap(replyTo));

    final messages = await _firebase.watchMessages(threadId, myId).first;
    return SendMessageResult(messages: messages, scamWarning: scamWarning);
  }

  Future<void> sendPurchaseRequest(
    String threadId,
    String shippingAddress, {
    String paymentMethod = 'CASH',
    String deliveryMethod = 'DIRECT',
  }) async {
    final thread = await getThreadDetail(threadId);
    if (thread.productId == null) {
      throw Exception('Hội thoại không gắn sản phẩm');
    }

    OrderItem order;
    try {
      order = await OrderService.instance.createOrder(
        productId: thread.productId!,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        deliveryMethod: deliveryMethod,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('đã có đơn') ||
          msg.contains('Conflict') ||
          msg.contains('409')) {
        throw Exception(
          'Sản phẩm đã có đơn đặt mua. Hủy đơn cũ hoặc chọn sản phẩm khác.',
        );
      }
      if (msg.contains('không còn khả dụng') ||
          msg.contains('Reserved') ||
          msg.contains('Sold')) {
        throw Exception('Sản phẩm không còn khả dụng để đặt mua.');
      }
      rethrow;
    }

    final payLabel = order.paymentMethodLabel;
    final delLabel = order.deliveryMethodLabel;

    await _firebase.sendPurchaseRequestMessage(
      threadId: threadId,
      orderId: order.orderId,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      deliveryMethod: deliveryMethod,
      thread: thread,
      paymentLabel: payLabel,
      deliveryLabel: delLabel,
    );
  }

  Future<void> confirmSale(String threadId, String messageId) async {
    final thread = await getThreadDetail(threadId);
    final orderId = thread.orderId;
    if (orderId == null) {
      throw Exception('Chưa có đơn hàng để xác nhận');
    }

    final order = await OrderService.instance.getOrder(orderId);
    if (order.isOnlineEscrow) {
      if (order.orderStatus == 'Pending') {
        throw Exception(
          'Chờ người mua thanh toán online (escrow) trước khi xác nhận giao hàng.',
        );
      }
      if (order.isDirectDelivery) {
        await OrderService.instance.markDirectHandover(orderId);
      } else if (order.orderStatus == 'Paid') {
        await OrderService.instance.markShipped(orderId);
      }
    } else if (order.isDirectOrder) {
      await OrderService.instance.markDirectHandover(orderId);
    } else {
      await OrderService.instance.markPaymentReceived(orderId);
    }

    await _firebase.confirmSaleMessage(
      threadId: threadId,
      messageId: messageId,
      orderId: orderId,
    );
  }
}

class SendMessageResult {
  const SendMessageResult({required this.messages, this.scamWarning});

  final List<ChatMessage> messages;
  final String? scamWarning;
}
