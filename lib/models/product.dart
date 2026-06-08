import 'package:safemarket_app/models/auth_user.dart';

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
  final String? thumbnailUrl;

  factory ProductListItem.fromJson(Map<String, dynamic> json) {
    return ProductListItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      price: (json['price'] as num).toInt(),
      priceFormatted: json['priceFormatted'] as String? ?? '',
      location: json['location'] as String? ?? '',
      conditionPct: (json['conditionPct'] as num?)?.toInt() ?? 100,
      sellerName: json['sellerName'] as String? ?? 'Người bán',
      trustScore: (json['trustScore'] as num?)?.toInt() ?? 500,
      sellerVerified: json['sellerVerified'] as bool? ?? false,
      categoryName: json['categoryName'] as String? ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
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
  final String? thumbnailUrl;
  final List<String> imageUrls;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final sellerJson = json['seller'] as Map<String, dynamic>? ?? {};
    final rawImages = json['imageUrls'];
    return ProductDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toInt(),
      priceFormatted: json['priceFormatted'] as String? ?? '',
      location: json['location'] as String? ?? '',
      conditionPct: (json['conditionPct'] as num?)?.toInt() ?? 100,
      status: json['status'] as String? ?? 'Available',
      seller: AuthUser.fromJson(sellerJson),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageUrls: rawImages is List
          ? rawImages.map((e) => e.toString()).toList()
          : const [],
    );
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
