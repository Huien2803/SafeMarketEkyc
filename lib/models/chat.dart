class ChatThread {
  const ChatThread({
    required this.threadId,
    required this.buyerId,
    required this.sellerId,
    required this.sellerName,
    required this.buyerName,
    this.productId,
    this.productTitle,
    this.orderId,
    required this.createdAt,
    this.lastMessage,
  });

  final int threadId;
  final int buyerId;
  final int sellerId;
  final String sellerName;
  final String buyerName;
  final int? productId;
  final String? productTitle;
  final int? orderId;
  final DateTime createdAt;
  final String? lastMessage;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      threadId: (json['threadId'] as num).toInt(),
      buyerId: (json['buyerId'] as num).toInt(),
      sellerId: (json['sellerId'] as num).toInt(),
      sellerName: json['sellerName'] as String? ?? '',
      buyerName: json['buyerName'] as String? ?? '',
      productId: (json['productId'] as num?)?.toInt(),
      productTitle: json['productTitle'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessage: json['lastMessage'] as String?,
    );
  }

  String peerName(int myUserId) =>
      myUserId == buyerId ? sellerName : buyerName;
}

/// Chi tiết hội thoại kèm sản phẩm (mua bán trong chat).
class ChatThreadDetail {
  const ChatThreadDetail({
    required this.threadId,
    required this.buyerId,
    required this.sellerId,
    required this.sellerName,
    required this.buyerName,
    this.productId,
    this.productTitle,
    this.productPrice,
    this.productPriceFormatted,
    this.conditionPct,
    this.productStatus,
    this.productLocation,
    this.thumbnailUrl,
    this.orderId,
    this.orderStatus,
    required this.amBuyer,
    required this.amSeller,
  });

  final int threadId;
  final int buyerId;
  final int sellerId;
  final String sellerName;
  final String buyerName;
  final int? productId;
  final String? productTitle;
  final int? productPrice;
  final String? productPriceFormatted;
  final int? conditionPct;
  final String? productStatus;
  final String? productLocation;
  final String? thumbnailUrl;
  final int? orderId;
  final String? orderStatus;
  final bool amBuyer;
  final bool amSeller;

  bool get canPurchaseInChat =>
      amBuyer &&
      productId != null &&
      orderId == null &&
      (productStatus == null || productStatus == 'Available');

  bool get awaitingSellerConfirm =>
      amSeller && orderId == null && productId != null;

  factory ChatThreadDetail.fromJson(Map<String, dynamic> json) {
    return ChatThreadDetail(
      threadId: (json['threadId'] as num).toInt(),
      buyerId: (json['buyerId'] as num).toInt(),
      sellerId: (json['sellerId'] as num).toInt(),
      sellerName: json['sellerName'] as String? ?? '',
      buyerName: json['buyerName'] as String? ?? '',
      productId: (json['productId'] as num?)?.toInt(),
      productTitle: json['productTitle'] as String?,
      productPrice: (json['productPrice'] as num?)?.toInt(),
      productPriceFormatted: json['productPriceFormatted'] as String?,
      conditionPct: (json['conditionPct'] as num?)?.toInt(),
      productStatus: json['productStatus'] as String?,
      productLocation: json['productLocation'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      orderStatus: json['orderStatus'] as String?,
      amBuyer: json['amBuyer'] as bool? ?? false,
      amSeller: json['amSeller'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.messageType,
    required this.meta,
    required this.createdAt,
    required this.mine,
  });

  final int messageId;
  final int threadId;
  final int senderId;
  final String senderName;
  final String body;
  final String messageType;
  final Map<String, dynamic> meta;
  final DateTime createdAt;
  final bool mine;

  bool get isPurchaseRequest => messageType == 'PURCHASE_REQUEST';
  bool get isSaleConfirmed => messageType == 'SALE_CONFIRMED';
  bool get isPendingPurchase =>
      isPurchaseRequest && (meta['status'] as String? ?? 'pending') == 'pending';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta'];
    return ChatMessage(
      messageId: (json['messageId'] as num).toInt(),
      threadId: (json['threadId'] as num).toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderName: json['senderName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'TEXT',
      meta: rawMeta is Map<String, dynamic>
          ? rawMeta
          : (rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      mine: json['mine'] as bool? ?? false,
    );
  }
}
