import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safemarket_app/models/favorite_product.dart';

class FavoritesService extends ChangeNotifier {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  static const _key = 'safemarket.favorites';
  final List<FavoriteProduct> _items = [];

  List<FavoriteProduct> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _items.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          _items.add(FavoriteProduct.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        await prefs.remove(_key);
      }
    }
    notifyListeners();
  }

  bool isFavorite(String id) => _items.any((e) => e.id == id);

  Future<void> toggle(FavoriteProduct product) async {
    final idx = _items.indexWhere((e) => e.id == product.id);
    if (idx >= 0) {
      _items.removeAt(idx);
    } else {
      _items.add(product);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
