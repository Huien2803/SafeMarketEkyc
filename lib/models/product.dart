import 'package:safemarket_app/models/auth_user.dart';
import 'package:safemarket_app/services/auth_service.dart';

class ProductListItem {
  const ProductListItem({
    required this.id,
    required this.title,
    required this.price,
    required this.priceFormatted,
    required this.location,
    required this.conditionPct,
    required this.sellerName,
    required this.trustScore,
    required this.sellerVerified,
    required this.categoryName,
    required this.categoryId,
    this.sellerId,
    this.thumbnailUrl,
  });

  final int id;
  final String title;
  final int price;
  final String priceFormatted;
  final String location;
  final int conditionPct;
  final String sellerName;
  final int trustScore;
  final bool sellerVerified;
  final String categoryName;
  final int categoryId;
  final int? sellerId;
  final String? thumbnailUrl;

  factory ProductListItem.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    final price = (json['price'] as num).toInt();
    final id = (json['id'] as num?)?.toInt() ??
        (json['productId'] as num?)?.toInt() ??
        0;
    final sellerName = json['sellerName'] as String? ??
        seller?['displayName'] as String? ??
        seller?['email'] as String? ??
        'Người bán';
    final trustScore = (json['trustScore'] as num?)?.toInt() ??
        (seller?['trustScore'] as num?)?.toInt() ??
        500;
    final kyc = seller?['kycStatus'] as String?;
    final sellerId = (json['sellerId'] as num?)?.toInt() ??
        (seller?['userId'] as num?)?.toInt();
    return ProductListItem(
      id: id,
      title: json['title'] as String,
      price: price,
      priceFormatted: json['priceFormatted'] as String? ??
          _formatVnd(price),
      location: json['location'] as String? ?? '',
      conditionPct: (json['conditionPct'] as num?)?.toInt() ?? 100,
      sellerName: sellerName,
      trustScore: trustScore,
      sellerVerified: json['sellerVerified'] as bool? ??
          (kyc == 'Verified'),
      categoryName: json['categoryName'] as String? ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      sellerId: sellerId,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  static String _formatVnd(int amount) {
    final s = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$s đ';
  }
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceFormatted,
    required this.location,
    required this.conditionPct,
    required this.status,
    required this.seller,
    this.categoryId,
    this.thumbnailUrl,
    this.imageUrls = const [],
  });

  final int id;
  final String title;
  final String description;
  final int price;
  final String priceFormatted;
  final String location;
  final int conditionPct;
  final String status;
  final AuthUser seller;
  final int? categoryId;
  final String? thumbnailUrl;
  final List<String> imageUrls;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final sellerJson = json['seller'] as Map<String, dynamic>? ?? {};
    final rawImages = json['imageUrls'];
    final price = (json['price'] as num).toInt();
    final id = (json['id'] as num?)?.toInt() ??
        (json['productId'] as num?)?.toInt() ??
        0;
    return ProductDetail(
      id: id,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      price: price,
      priceFormatted: json['priceFormatted'] as String? ??
          ProductListItem._formatVnd(price),
      location: json['location'] as String? ?? '',
      conditionPct: (json['conditionPct'] as num?)?.toInt() ?? 100,
      status: json['status'] as String? ?? 'Available',
      seller: AuthUser.fromJson(sellerJson),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageUrls: rawImages is List
          ? rawImages.map((e) => e.toString()).toList()
          : const [],
    );
  }

  bool get isAvailable => status == 'Available';
  bool get isSold => status == 'Sold';
  bool get isReserved => status == 'Reserved';

  /// Có thể đặt mua (Available + không phải tài khoản admin).
  bool get isPurchasable {
    if (AuthService.instance.currentUser?.isAdmin == true) return false;
    return status == 'Available';
  }

  /// Nhãn nút mua / thông báo khi không mua được.
  String get purchaseBlockedLabel {
    if (AuthService.instance.currentUser?.isAdmin == true) {
      return 'Admin không mua hàng';
    }
    if (isSold) return 'Đã bán';
    if (isReserved) return 'Đã có người đặt';
    if (status == 'Hidden') return 'Không khả dụng';
    return 'Không khả dụng';
  }
}

class ProductCategory {
  const ProductCategory({required this.categoryId, required this.name});

  final int categoryId;
  final String name;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      categoryId: (json['categoryId'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}
