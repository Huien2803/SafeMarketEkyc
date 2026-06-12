class SoldListing {
  const SoldListing({
    required this.productId,
    required this.title,
    required this.price,
    required this.priceFormatted,
    required this.productStatus,
    this.thumbnailUrl,
    this.orderId,
    this.orderStatus,
    this.buyerName,
    required this.hasBuyer,
  });

  final int productId;
  final String title;
  final int price;
  final String priceFormatted;
  final String productStatus;
  final int? orderId;
  final String? orderStatus;
  final String? buyerName;
  final bool hasBuyer;
  final String? thumbnailUrl;

  bool get isSold => productStatus == 'Sold';
  bool get isActive =>
      productStatus == 'Available' || productStatus == 'Reserved';

  factory SoldListing.fromJson(Map<String, dynamic> json) {
    return SoldListing(
      productId: (json['productId'] as num).toInt(),
      title: json['title'] as String,
      price: (json['price'] as num).toInt(),
      priceFormatted: json['priceFormatted'] as String? ?? '',
      productStatus: json['productStatus'] as String? ?? 'Available',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      orderStatus: json['orderStatus'] as String?,
      buyerName: json['buyerName'] as String?,
      hasBuyer: json['hasBuyer'] as bool? ?? false,
    );
  }

  String get buyerStatusLabel {
    if (!hasBuyer) return 'Chưa có người mua';
    switch (orderStatus) {
      case 'Pending':
        return 'Có người đặt — chờ xử lý';
      case 'Paid':
        return 'Đã có người mua — chờ giao';
      case 'Shipped':
        return 'Đang giao cho ${buyerName ?? 'người mua'}';
      case 'Completed':
        return 'Đã bán cho ${buyerName ?? 'người mua'}';
      case 'Disputed':
        return 'Tranh chấp — ${buyerName ?? ''}';
      default:
        return 'Có người mua';
    }
  }
}
