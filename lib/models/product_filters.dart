/// Bộ lọc danh sách sản phẩm (đồng bộ query API `GET /products`).
enum ProductSort {
  newest('newest', 'Mới nhất'),
  oldest('oldest', 'Cũ nhất'),
  priceAsc('price_asc', 'Giá thấp → cao'),
  priceDesc('price_desc', 'Giá cao → thấp');

  const ProductSort(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ProductSort fromApi(String? value) {
    return ProductSort.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => ProductSort.newest,
    );
  }
}

class ProductFilters {
  const ProductFilters({
    this.minPrice,
    this.maxPrice,
    this.location,
    this.sort = ProductSort.newest,
  });

  final int? minPrice;
  final int? maxPrice;
  final String? location;
  final ProductSort sort;

  static const empty = ProductFilters();

  int get activeCount {
    var n = 0;
    if (minPrice != null) n++;
    if (maxPrice != null) n++;
    if (location != null && location!.isNotEmpty) n++;
    if (sort != ProductSort.newest) n++;
    return n;
  }

  bool get hasActiveFilters => activeCount > 0;

  ProductFilters copyWith({
    int? Function()? minPrice,
    int? Function()? maxPrice,
    String? Function()? location,
    ProductSort? sort,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearLocation = false,
  }) {
    return ProductFilters(
      minPrice: clearMinPrice ? null : (minPrice != null ? minPrice() : this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice != null ? maxPrice() : this.maxPrice),
      location: clearLocation ? null : (location != null ? location() : this.location),
      sort: sort ?? this.sort,
    );
  }

  ProductFilters cleared() => ProductFilters.empty;
}
