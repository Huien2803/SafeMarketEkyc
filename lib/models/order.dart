class OrderItem {
  const OrderItem({
    required this.orderId,
    required this.orderStatus,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.deliveryMethod,
    required this.paymentMethodLabel,
    required this.deliveryMethodLabel,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productTitle,
    required this.productPrice,
    required this.productPriceFormatted,
    this.disputeType,
    this.disputeNote,
    required this.createdAt,
    this.completedAt,
    this.escrowStatus,
    this.escrowAmount = 0,
    this.buyerReviewed = false,
    this.sellerReviewed = false,
  });

  final int orderId;
  final String orderStatus;
  final String shippingAddress;
  final String paymentMethod;
  final String deliveryMethod;
  final String paymentMethodLabel;
  final String deliveryMethodLabel;
  final int buyerId;
  final String buyerName;
  final int sellerId;
  final String sellerName;
  final int productId;
  final String productTitle;
  final int productPrice;
  final String productPriceFormatted;
  final String? disputeType;
  final String? disputeNote;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? escrowStatus;
  final int escrowAmount;
  final bool buyerReviewed;
  final bool sellerReviewed;

  bool get isShipOrder =>
      paymentMethod == 'BANK_TRANSFER' && deliveryMethod == 'SHIP';

  bool get isDirectOrder => paymentMethod == 'CASH' && deliveryMethod == 'DIRECT';

  String get methodSummary => '$paymentMethodLabel · $deliveryMethodLabel';

  String get addressLabel =>
      isDirectOrder ? 'Địa điểm hẹn giao' : 'Địa chỉ nhận hàng';

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final pay = json['paymentMethod'] as String? ?? 'BANK_TRANSFER';
    final del = json['deliveryMethod'] as String? ?? 'SHIP';
    return OrderItem(
      orderId: (json['orderId'] as num).toInt(),
      orderStatus: json['orderStatus'] as String? ?? 'Pending',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      paymentMethod: pay,
      deliveryMethod: del,
      paymentMethodLabel:
          json['paymentMethodLabel'] as String? ??
              (pay == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản'),
      deliveryMethodLabel:
          json['deliveryMethodLabel'] as String? ??
              (del == 'DIRECT' ? 'Giao trực tiếp' : 'Giao ship'),
      buyerId: (json['buyerId'] as num).toInt(),
      buyerName: json['buyerName'] as String? ?? '',
      sellerId: (json['sellerId'] as num).toInt(),
      sellerName: json['sellerName'] as String? ?? '',
      productId: (json['productId'] as num).toInt(),
      productTitle: json['productTitle'] as String? ?? '',
      productPrice: (json['productPrice'] as num?)?.toInt() ?? 0,
      productPriceFormatted: json['productPriceFormatted'] as String? ?? '',
      disputeType: json['disputeType'] as String?,
      disputeNote: json['disputeNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      escrowStatus: json['escrowStatus'] as String?,
      escrowAmount: (json['escrowAmount'] as num?)?.toInt() ?? 0,
      buyerReviewed: json['buyerReviewed'] as bool? ?? false,
      sellerReviewed: json['sellerReviewed'] as bool? ?? false,
    );
  }

  String get escrowLabel {
    switch (escrowStatus) {
      case 'Holding':
        return 'Đang tạm giữ';
      case 'Released':
        return 'Đã giải ngân cho người bán';
      case 'Refunded':
        return 'Đã hoàn tiền';
      default:
        return 'Chưa có escrow';
    }
  }

  String get statusLabel {
    switch (orderStatus) {
      case 'Pending':
        return isDirectOrder ? 'Chờ giao trực tiếp' : 'Chờ chuyển khoản';
      case 'Paid':
        return isDirectOrder ? 'Đã giao — chờ xác nhận' : 'Đã thanh toán';
      case 'Shipped':
        return 'Đang giao ship';
      case 'Completed':
        return 'Hoàn tất';
      case 'Cancelled':
        return 'Đã hủy';
      case 'Disputed':
        if (disputeType == 'NO_RECEIVE') return 'Khiếu nại: không nhận hàng';
        if (disputeType == 'WRONG_DELIVERY') return 'Khiếu nại: giao sai';
        return 'Đang tranh chấp';
      default:
        return orderStatus;
    }
  }
}
