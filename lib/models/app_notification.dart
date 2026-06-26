class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.icon = 'info',
    this.type = 'INFO',
    this.productId,
    this.sellerId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String icon;
  final String type;
  final int? productId;
  final int? sellerId;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      icon: icon,
      type: type,
      productId: productId,
      sellerId: sellerId,
    );
  }

  factory AppNotification.fromApi(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'INFO';
    final payload = json['payload'] as Map<String, dynamic>?;
    return AppNotification(
      id: '${json['id']}',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
      icon: _iconForType(type),
      type: type,
      productId: (payload?['productId'] as num?)?.toInt(),
      sellerId: (payload?['sellerId'] as num?)?.toInt(),
    );
  }

  static String _iconForType(String type) {
    switch (type) {
      case 'NEW_PRODUCT':
      case 'PRODUCT_SOLD':
        return 'product';
      case 'ORDER_RECEIVED':
        return 'received';
      default:
        return 'info';
    }
  }
}
