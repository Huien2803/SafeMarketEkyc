import 'package:firebase_database/firebase_database.dart';
import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/product_service.dart';

/// Chat realtime qua Firebase Realtime Database.
///
/// Cấu trúc:
///   safemarket/threads/{threadKey}     — metadata hội thoại
///   safemarket/messages/{threadKey}/   — tin nhắn realtime
///   safemarket/userThreads/{userId}/   — danh sách chat của từng user
class FirebaseChatService {
  FirebaseChatService._();
  static final FirebaseChatService instance = FirebaseChatService._();

  DatabaseReference get _root =>
      FirebaseDatabase.instance.ref().child('safemarket');

  /// Khóa ổn định: buyer_seller_productId (sắp ID tăng dần)
  String threadKey(int buyerId, int sellerId, int? productId) {
    final lo = buyerId < sellerId ? buyerId : sellerId;
    final hi = buyerId < sellerId ? sellerId : buyerId;
    return '${lo}_${hi}_${productId ?? 0}';
  }

  /// Stream danh sách hội thoại của user hiện tại (cập nhật realtime).
  Stream<List<ChatThread>> watchUserThreads(int userId) {
    return _root.child('userThreads').child('$userId').onValue.map((event) {
      final snap = event.snapshot;
      if (!snap.exists || snap.value == null) return <ChatThread>[];

      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final threads = <ChatThread>[];

      for (final entry in map.entries) {
        final threadId = entry.key.toString();
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        threads.add(ChatThread.fromFirebase(threadId, data));
      }

      threads.sort((a, b) {
        final ta = a.updatedAt ?? a.createdAt;
        final tb = b.updatedAt ?? b.createdAt;
        return tb.compareTo(ta);
      });
      return threads;
    });
  }

  /// Tổng tin nhắn chưa đọc của user (realtime).
  Stream<int> watchTotalUnread(int userId) {
    if (userId <= 0) return Stream.value(0);
    return _root.child('userThreads').child('$userId').onValue.map((event) {
      final snap = event.snapshot;
      if (!snap.exists || snap.value == null) return 0;

      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      var total = 0;
      for (final entry in map.entries) {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        total += (data['unreadCount'] as num?)?.toInt() ?? 0;
      }
      return total;
    });
  }

  /// Đánh dấu đã đọc khi mở hội thoại.
  Future<void> markThreadRead(String threadId, int userId) async {
    if (userId <= 0) return;
    await _root
        .child('userThreads')
        .child('$userId')
        .child(threadId)
        .update({'unreadCount': 0});
  }

  /// Stream tin nhắn trong một hội thoại.
  Stream<List<ChatMessage>> watchMessages(String threadId, int myUserId) {
    return _root.child('messages').child(threadId).onValue.map((event) {
      final snap = event.snapshot;
      if (!snap.exists || snap.value == null) return <ChatMessage>[];

      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) {
        final data = Map<dynamic, dynamic>.from(e.value as Map);
        return ChatMessage.fromFirebase(
          e.key.toString(),
          threadId,
          data,
          myUserId,
        );
      }).toList();

      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// Mở hoặc tạo hội thoại; trả về threadId (Firebase key).
  Future<String> openThread({
    required int sellerId,
    int? productId,
    int? orderId,
    String? sellerName,
    String? buyerName,
  }) async {
    final buyer = AuthService.instance.currentUser;
    if (buyer == null) throw Exception('Cần đăng nhập để chat');

    final buyerId = buyer.userId;
    if (buyerId == sellerId) {
      throw Exception('Không thể chat với chính mình');
    }

    final key = threadKey(buyerId, sellerId, productId);
    final threadRef = _root.child('threads').child(key);
    final existing = await threadRef.get();

    ProductDetail? product;
    if (productId != null) {
      try {
        product = await ProductService.instance.getProductDetail(productId);
      } catch (_) {
        // Tiếp tục không có chi tiết SP
      }
    }

    if (existing.exists && existing.value != null) {
      if (product != null) {
        await _attachProductToThread(threadRef, product);
      }
      return key;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final bName = buyerName ?? buyer.displayName ?? buyer.email;
    final sName = sellerName ??
        product?.seller.displayName ??
        product?.seller.email ??
        'Người bán';

    final threadData = <String, dynamic>{
      'buyerId': buyerId,
      'sellerId': sellerId,
      'buyerName': bName,
      'sellerName': sName,
      'productId': productId,
      'orderId': orderId,
      'productTitle': product?.title,
      'productPrice': product?.price,
      'productPriceFormatted': product?.priceFormatted,
      'conditionPct': product?.conditionPct,
      'productStatus': product?.status,
      'productLocation': product?.location,
      'thumbnailUrl': product?.thumbnailUrl,
      'createdAt': now,
      'updatedAt': now,
      'lastMessage': 'Bắt đầu trò chuyện',
    };

    await threadRef.set(threadData);
    await _syncUserThreadIndex(
      key: key,
      buyerId: buyerId,
      sellerId: sellerId,
      buyerName: bName,
      sellerName: sName,
      productId: productId,
      productTitle: product?.title,
      orderId: orderId,
      lastMessage: 'Bắt đầu trò chuyện',
      updatedAt: now,
    );

    return key;
  }

  Future<ChatThreadDetail> getThreadDetail(String threadId) async {
    final myId = AuthService.instance.currentUser?.userId ?? 0;
    final snap = await _root.child('threads').child(threadId).get();
    if (!snap.exists || snap.value == null) {
      throw Exception('Hội thoại không tồn tại');
    }
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    return ChatThreadDetail(
      threadId: threadId,
      buyerId: (data['buyerId'] as num).toInt(),
      sellerId: (data['sellerId'] as num).toInt(),
      sellerName: data['sellerName'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? '',
      productId: (data['productId'] as num?)?.toInt(),
      productTitle: data['productTitle'] as String?,
      productPrice: (data['productPrice'] as num?)?.toInt(),
      productPriceFormatted: data['productPriceFormatted'] as String?,
      conditionPct: (data['conditionPct'] as num?)?.toInt(),
      productStatus: data['productStatus'] as String?,
      productLocation: data['productLocation'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      orderId: (data['orderId'] as num?)?.toInt(),
      orderStatus: data['orderStatus'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      amBuyer: myId == (data['buyerId'] as num).toInt(),
      amSeller: myId == (data['sellerId'] as num).toInt(),
    );
  }

  Future<String?> sendTextMessage(
    String threadId,
    String body, {
    Map<String, dynamic>? replyTo,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _root.child('messages').child(threadId).push();
    await msgRef.set({
      'senderId': user.userId,
      'senderName': user.displayName ?? user.email,
      'body': body,
      'messageType': 'TEXT',
      'meta': null,
      'replyTo': replyTo,
      'createdAt': now,
    });

    await _touchThread(threadId, body, now, senderId: user.userId);
    return null;
  }

  Future<void> sendImageMessage(
    String threadId,
    String imageUrl, {
    Map<String, dynamic>? replyTo,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _root.child('messages').child(threadId).push();
    await msgRef.set({
      'senderId': user.userId,
      'senderName': user.displayName ?? user.email,
      'body': '[Ảnh]',
      'messageType': 'IMAGE',
      'meta': {'imageUrl': imageUrl},
      'replyTo': replyTo,
      'createdAt': now,
    });

    await _touchThread(threadId, '[Ảnh]', now, senderId: user.userId);
  }

  /// Thẻ sản phẩm trong chat (kiểu Shopee) khi người mua nhấn "Đặt mua".
  Future<void> sendProductCardMessage({
    required String threadId,
    required Map<String, dynamic> productMeta,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập');

    final title = productMeta['title'] as String? ?? 'Sản phẩm';
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _root.child('messages').child(threadId).push();
    await msgRef.set({
      'senderId': user.userId,
      'senderName': user.displayName ?? user.email,
      'body': 'Tôi quan tâm sản phẩm này',
      'messageType': 'PRODUCT_CARD',
      'meta': productMeta,
      'createdAt': now,
    });

    await _touchThread(
      threadId,
      'Quan tâm: $title',
      now,
      senderId: user.userId,
    );
  }

  Future<void> _attachProductToThread(
    DatabaseReference threadRef,
    ProductDetail product,
  ) async {
    final snap = await threadRef.get();
    if (!snap.exists || snap.value == null) return;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final updates = <String, dynamic>{
      'productId': product.id,
      'productTitle': product.title,
      'productPrice': product.price,
      'productPriceFormatted': product.priceFormatted,
      'conditionPct': product.conditionPct,
      'productStatus': product.status,
      'productLocation': product.location,
      'thumbnailUrl': product.thumbnailUrl ??
          (product.imageUrls.isNotEmpty ? product.imageUrls.first : null),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await threadRef.update(updates);

    final key = threadRef.key;
    if (key == null) return;
    await _syncUserThreadIndex(
      key: key,
      buyerId: (data['buyerId'] as num).toInt(),
      sellerId: (data['sellerId'] as num).toInt(),
      buyerName: data['buyerName'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      productId: product.id,
      productTitle: product.title,
      orderId: (data['orderId'] as num?)?.toInt(),
      lastMessage: data['lastMessage'] as String? ?? 'Bắt đầu trò chuyện',
      updatedAt: updates['updatedAt'] as int,
    );
  }

  Future<void> sendPurchaseRequestMessage({
    required String threadId,
    required int orderId,
    required String shippingAddress,
    required String paymentMethod,
    required String deliveryMethod,
    required ChatThreadDetail thread,
    required String paymentLabel,
    required String deliveryLabel,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập');

    final now = DateTime.now().millisecondsSinceEpoch;
    final meta = {
      'status': 'pending',
      'orderId': orderId,
      'title': thread.productTitle,
      'priceFormatted': thread.productPriceFormatted,
      'conditionPct': thread.conditionPct,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'deliveryMethod': deliveryMethod,
      'paymentMethodLabel': paymentLabel,
      'deliveryMethodLabel': deliveryLabel,
      'thumbnailUrl': thread.thumbnailUrl,
    };

    final msgRef = _root.child('messages').child(threadId).push();
    await msgRef.set({
      'senderId': user.userId,
      'senderName': user.displayName ?? user.email,
      'body': 'Đã gửi yêu cầu mua hàng',
      'messageType': 'PURCHASE_REQUEST',
      'meta': meta,
      'createdAt': now,
    });

    await _root.child('threads').child(threadId).update({
      'orderId': orderId,
      'orderStatus': 'Pending',
      'paymentMethod': paymentMethod,
      'updatedAt': now,
    });

    await _touchThread(
      threadId,
      'Yêu cầu đặt mua',
      now,
      orderId: orderId,
      senderId: user.userId,
    );
  }

  Future<void> confirmSaleMessage({
    required String threadId,
    required String messageId,
    required int orderId,
    String orderStatus = 'Shipped',
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _root.child('messages').child(threadId).child(messageId);
    final snap = await msgRef.get();
    if (!snap.exists) throw Exception('Tin nhắn không tồn tại');

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final meta = data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : <String, dynamic>{};
    meta['status'] = 'confirmed';
    meta['orderId'] = orderId;

    await msgRef.update({
      'messageType': 'SALE_CONFIRMED',
      'body': 'Đã xác nhận bán',
      'meta': meta,
    });

    await _root.child('threads').child(threadId).update({
      'orderId': orderId,
      'orderStatus': orderStatus,
      'updatedAt': now,
    });

    await _touchThread(
      threadId,
      'Đã xác nhận bán',
      now,
      orderId: orderId,
      senderId: user.userId,
    );
  }

  /// Khi seller xác nhận từ màn đơn (không qua nút chat) — cập nhật mọi thẻ PURCHASE_REQUEST.
  Future<void> confirmPurchaseRequestsForOrder({
    required String threadId,
    required int orderId,
    required String orderStatus,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final snap = await _root.child('messages').child(threadId).get();
    if (snap.exists && snap.value != null) {
      final raw = Map<dynamic, dynamic>.from(snap.value as Map);
      for (final entry in raw.entries) {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['messageType'] != 'PURCHASE_REQUEST') continue;
        final meta = data['meta'] is Map
            ? Map<String, dynamic>.from(data['meta'] as Map)
            : <String, dynamic>{};
        final metaOrderId = (meta['orderId'] as num?)?.toInt();
        if (metaOrderId != orderId) continue;
        meta['status'] = 'confirmed';
        await _root
            .child('messages')
            .child(threadId)
            .child(entry.key.toString())
            .update({
          'messageType': 'SALE_CONFIRMED',
          'body': 'Đã xác nhận bán',
          'meta': meta,
        });
      }
    }

    await syncThreadOrderStatus(
      threadId: threadId,
      orderId: orderId,
      orderStatus: orderStatus,
    );
    await _touchThread(
      threadId,
      'Đã xác nhận bán',
      DateTime.now().millisecondsSinceEpoch,
      orderId: orderId,
      senderId: user.userId,
    );
  }

  /// Đồng bộ trạng thái đơn lên Firebase (sau thanh toán / hủy).
  Future<void> syncThreadOrderStatus({
    required String threadId,
    required int orderId,
    required String orderStatus,
    String? paymentMethod,
  }) async {
    if (orderStatus == 'Cancelled') {
      await clearThreadOrder(threadId);
      await markPurchaseRequestsCancelled(threadId, orderId);
      return;
    }
    final updates = <String, dynamic>{
      'orderId': orderId,
      'orderStatus': orderStatus,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (paymentMethod != null) {
      updates['paymentMethod'] = paymentMethod;
    }
    await _root.child('threads').child(threadId).update(updates);
  }

  /// Hủy đơn → gỡ orderId để chat hiện lại «Đặt mua».
  Future<void> clearThreadOrder(String threadId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _root.child('threads').child(threadId).update({
      'orderId': null,
      'orderStatus': 'Cancelled',
      'productStatus': 'Available',
      'updatedAt': now,
    });
  }

  /// Đánh dấu các thẻ yêu cầu mua của đơn đã hủy.
  Future<void> markPurchaseRequestsCancelled(
    String threadId,
    int orderId,
  ) async {
    final snap = await _root.child('messages').child(threadId).get();
    if (!snap.exists || snap.value == null) return;
    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    for (final entry in raw.entries) {
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      if (data['messageType'] != 'PURCHASE_REQUEST') continue;
      final meta = data['meta'] is Map
          ? Map<String, dynamic>.from(data['meta'] as Map)
          : <String, dynamic>{};
      final metaOrderId = (meta['orderId'] as num?)?.toInt();
      if (metaOrderId != orderId) continue;
      if ((meta['status'] as String?) == 'cancelled') continue;
      meta['status'] = 'cancelled';
      await _root
          .child('messages')
          .child(threadId)
          .child(entry.key.toString())
          .update({
        'meta': meta,
        'body': 'Đã hủy yêu cầu mua hàng',
      });
    }
  }

  Future<void> _touchThread(
    String threadId,
    String lastMessage,
    int updatedAt, {
    int? orderId,
    int? senderId,
  }) async {
    final threadSnap = await _root.child('threads').child(threadId).get();
    if (!threadSnap.exists) return;

    final data = Map<dynamic, dynamic>.from(threadSnap.value as Map);
    final updates = <String, dynamic>{
      'lastMessage': lastMessage,
      'updatedAt': updatedAt,
    };
    if (orderId != null) updates['orderId'] = orderId;
    await _root.child('threads').child(threadId).update(updates);

    final buyerId = (data['buyerId'] as num).toInt();
    final sellerId = (data['sellerId'] as num).toInt();

    await _syncUserThreadIndex(
      key: threadId,
      buyerId: buyerId,
      sellerId: sellerId,
      buyerName: data['buyerName'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      productId: (data['productId'] as num?)?.toInt(),
      productTitle: data['productTitle'] as String?,
      orderId: orderId ?? (data['orderId'] as num?)?.toInt(),
      lastMessage: lastMessage,
      updatedAt: updatedAt,
    );

    if (senderId != null) {
      final recipientId = senderId == buyerId ? sellerId : buyerId;
      await _incrementUnread(threadId, recipientId);
    }
  }

  Future<void> _incrementUnread(String threadId, int recipientId) async {
    final ref = _root
        .child('userThreads')
        .child('$recipientId')
        .child(threadId)
        .child('unreadCount');
    await ref.runTransaction((current) {
      final count = (current as int?) ?? 0;
      return Transaction.success(count + 1);
    });
  }

  Future<void> _syncUserThreadIndex({
    required String key,
    required int buyerId,
    required int sellerId,
    required String buyerName,
    required String sellerName,
    int? productId,
    String? productTitle,
    int? orderId,
    required String lastMessage,
    required int updatedAt,
  }) async {
    final entry = {
      'threadId': key,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'buyerName': buyerName,
      'sellerName': sellerName,
      'productId': productId,
      'productTitle': productTitle,
      'orderId': orderId,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt,
    };

    await Future.wait([
      _upsertUserThreadEntry('$buyerId', key, entry),
      _upsertUserThreadEntry('$sellerId', key, entry),
    ]);
  }

  Future<void> _upsertUserThreadEntry(
    String userId,
    String key,
    Map<String, dynamic> entry,
  ) async {
    final ref = _root.child('userThreads').child(userId).child(key);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update(entry);
    } else {
      await ref.set({...entry, 'unreadCount': 0});
    }
  }
}
