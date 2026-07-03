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
    this.updatedAt,
    this.unreadCount = 0,
  });

  final String threadId;
  final int buyerId;
  final int sellerId;
  final String sellerName;
  final String buyerName;
  final int? productId;
  final String? productTitle;
  final int? orderId;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      threadId: json['threadId']?.toString() ?? '',
      buyerId: (json['buyerId'] as num).toInt(),
      sellerId: (json['sellerId'] as num).toInt(),
      sellerName: json['sellerName'] as String? ?? '',
      buyerName: json['buyerName'] as String? ?? '',
      productId: (json['productId'] as num?)?.toInt(),
      productTitle: json['productTitle'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      createdAt: _parseTime(json['createdAt']),
      lastMessage: json['lastMessage'] as String?,
      updatedAt: json['updatedAt'] != null ? _parseTime(json['updatedAt']) : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory ChatThread.fromFirebase(String threadId, Map<dynamic, dynamic> data) {
    return ChatThread(
      threadId: threadId,
      buyerId: (data['buyerId'] as num).toInt(),
      sellerId: (data['sellerId'] as num).toInt(),
      sellerName: data['sellerName'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? '',
      productId: (data['productId'] as num?)?.toInt(),
      productTitle: data['productTitle'] as String?,
      orderId: (data['orderId'] as num?)?.toInt(),
      createdAt: _parseTime(data['createdAt']),
      lastMessage: data['lastMessage'] as String?,
      updatedAt: data['updatedAt'] != null ? _parseTime(data['updatedAt']) : null,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  String peerName(int myUserId) =>
      myUserId == buyerId ? sellerName : buyerName;

  static DateTime _parseTime(dynamic v) {
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }
}

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

  final String threadId;
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

  factory ChatThreadDetail.fromJson(Map<String, dynamic> json) {
    return ChatThreadDetail(
      threadId: json['threadId']?.toString() ?? '',
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

  factory ChatThreadDetail.fromThread(ChatThread t, int myUserId) {
    return ChatThreadDetail(
      threadId: t.threadId,
      buyerId: t.buyerId,
      sellerId: t.sellerId,
      sellerName: t.sellerName,
      buyerName: t.buyerName,
      productId: t.productId,
      productTitle: t.productTitle,
      orderId: t.orderId,
      amBuyer: myUserId == t.buyerId,
      amSeller: myUserId == t.sellerId,
    );
  }
}

/// Thông tin tin nhắn được trích dẫn khi trả lời (reply).
class ReplyInfo {
  const ReplyInfo({
    required this.messageId,
    required this.senderName,
    required this.preview,
    required this.type,
  });

  final String messageId;
  final String senderName;

  /// Đoạn xem trước nội dung tin nhắn gốc.
  final String preview;
  final String type;

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderName': senderName,
        'preview': preview,
        'type': type,
      };

  static ReplyInfo? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<dynamic, dynamic>.from(raw);
    final id = m['messageId']?.toString() ?? '';
    if (id.isEmpty) return null;
    return ReplyInfo(
      messageId: id,
      senderName: m['senderName']?.toString() ?? '',
      preview: m['preview']?.toString() ?? '',
      type: m['type']?.toString() ?? 'TEXT',
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
    this.replyTo,
  });

  final String messageId;
  final String threadId;
  final int senderId;
  final String senderName;
  final String body;
  final String messageType;
  final Map<String, dynamic> meta;
  final DateTime createdAt;
  final bool mine;
  final ReplyInfo? replyTo;

  /// Đoạn xem trước dùng khi tin nhắn này được trích dẫn để trả lời.
  String get replyPreview {
    if (isImage) return '📷 Hình ảnh';
    if (isProductCard) return 'Sản phẩm';
    if (isPurchaseRequest) return 'Yêu cầu đặt mua';
    if (isSaleConfirmed) return 'Đã xác nhận bán';
    return body;
  }

  bool get isProductCard => messageType == 'PRODUCT_CARD';
  bool get isImage => messageType == 'IMAGE';
  bool get isPurchaseRequest => messageType == 'PURCHASE_REQUEST';
  bool get isSaleConfirmed => messageType == 'SALE_CONFIRMED';
  bool get isPendingPurchase =>
      isPurchaseRequest && (meta['status'] as String? ?? 'pending') == 'pending';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta'];
    return ChatMessage(
      messageId: json['messageId']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
      senderId: (json['senderId'] as num).toInt(),
      senderName: json['senderName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'TEXT',
      meta: _parseMeta(rawMeta),
      createdAt: ChatThread._parseTime(json['createdAt']),
      mine: json['mine'] as bool? ?? false,
      replyTo: ReplyInfo.fromMap(json['replyTo']),
    );
  }

  factory ChatMessage.fromFirebase(
    String messageId,
    String threadId,
    Map<dynamic, dynamic> data,
    int myUserId,
  ) {
    return ChatMessage(
      messageId: messageId,
      threadId: threadId,
      senderId: (data['senderId'] as num).toInt(),
      senderName: data['senderName'] as String? ?? '',
      body: data['body'] as String? ?? '',
      messageType: data['messageType'] as String? ?? 'TEXT',
      meta: _parseMeta(data['meta']),
      createdAt: ChatThread._parseTime(data['createdAt']),
      mine: (data['senderId'] as num).toInt() == myUserId,
      replyTo: ReplyInfo.fromMap(data['replyTo']),
    );
  }

  static Map<String, dynamic> _parseMeta(dynamic rawMeta) {
    if (rawMeta is Map<String, dynamic>) return rawMeta;
    if (rawMeta is Map) return Map<String, dynamic>.from(rawMeta);
    return {};
  }
}
