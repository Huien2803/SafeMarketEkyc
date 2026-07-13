import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:safemarket_app/models/app_notification.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> load() async {
    if (AuthService.instance.isLoggedIn) {
      await syncFromApi();
      return;
    }
    _items.clear();
    notifyListeners();
  }

  Future<void> syncFromApi() async {
    if (!AuthService.instance.isLoggedIn) return;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/notifications');
      final res = await AuthService.instance.authorizedRequest(
        (h) => http.get(uri, headers: h).timeout(ApiConfig.timeout),
      );

      if (res.statusCode != 200) return;

      final list = jsonDecode(res.body) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map(
            (e) => AppNotification.fromApi(e as Map<String, dynamic>),
          ),
        );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    _items[i] = _items[i].copyWith(read: true);
    notifyListeners();

    if (!AuthService.instance.isLoggedIn) return;
    try {
      await AuthService.instance.authorizedRequest(
        (h) => http.patch(
          Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
          headers: h,
        ),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
      }
    }
    notifyListeners();

    if (!AuthService.instance.isLoggedIn) return;
    try {
      await AuthService.instance.authorizedRequest(
        (h) => http.post(
          Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
          headers: h,
        ),
      );
    } catch (_) {}
  }
}
