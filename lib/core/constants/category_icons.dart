import 'package:flutter/material.dart';

/// Icon Material theo tên danh mục (kiểu Chợ Tốt).
IconData categoryIconFor(String name) {
  final key = name.trim().toLowerCase();

  const icons = <String, IconData>{
    'điện tử': Icons.smartphone_outlined,
    'thời trang': Icons.checkroom_outlined,
    'đồ gia dụng': Icons.kitchen_outlined,
    'xe cộ': Icons.directions_car_outlined,
    'sách': Icons.menu_book_outlined,
    'nhà cửa': Icons.home_outlined,
    'bất động sản': Icons.apartment_outlined,
    'việc làm': Icons.work_outline,
    'dịch vụ': Icons.handyman_outlined,
    'thú cưng': Icons.pets_outlined,
    'đồ chơi': Icons.toys_outlined,
    'mẹ và bé': Icons.child_care_outlined,
    'thể thao': Icons.sports_soccer_outlined,
    'làm đẹp': Icons.spa_outlined,
  };

  if (icons.containsKey(key)) return icons[key]!;

  if (key.contains('điện') || key.contains('phone') || key.contains('laptop')) {
    return Icons.devices_outlined;
  }
  if (key.contains('thời') || key.contains('quần') || key.contains('áo')) {
    return Icons.checkroom_outlined;
  }
  if (key.contains('gia dụng') || key.contains('nhà')) {
    return Icons.kitchen_outlined;
  }
  if (key.contains('xe') || key.contains('ô tô') || key.contains('moto')) {
    return Icons.directions_car_outlined;
  }
  if (key.contains('sách')) return Icons.menu_book_outlined;

  return Icons.category_outlined;
}

/// Icon tab "Tất cả".
const IconData kAllCategoriesIcon = Icons.apps_rounded;
