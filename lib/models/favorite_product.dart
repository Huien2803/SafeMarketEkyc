/// Sản phẩm đã lưu yêu thích (lưu local qua SharedPreferences).
class FavoriteProduct {
  const FavoriteProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.seller,
    required this.location,
    this.trustScore = 0,
  });

  final String id;
  final String name;
  final String price;
  final String seller;
  final String location;
  final int trustScore;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'seller': seller,
        'location': location,
        'trustScore': trustScore,
      };

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) {
    return FavoriteProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as String,
      seller: json['seller'] as String,
      location: json['location'] as String,
      trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,
    );
  }
}
