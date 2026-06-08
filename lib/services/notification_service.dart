import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safemarket_app/models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _key = 'safemarket.notifications';
  final List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _items.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          _items.add(_fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        await prefs.remove(_key);
        _seedDefaults();
        await _persist();
      }
    } else {
      _seedDefaults();
      await _persist();
    }
    notifyListeners();
  }

  void _seedDefaults() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: '1',
        title: 'Chào mừng đến SafeMarket',
        body: 'Hoàn tất xác thực eKYC để tăng điểm tin cậy và được ưu tiên giao dịch.',
        createdAt: now.subtract(const Duration(hours: 2)),
        icon: 'shield',
      ),
      AppNotification(
        id: '2',
        title: 'Tin đăng mới gần bạn',
        body: 'iPhone 13 Pro Max vừa được đăng tại Quận 1, TP.HCM.',
        createdAt: now.subtract(const Duration(hours: 5)),
        icon: 'product',
      ),
      AppNotification(
        id: '3',
        title: 'Nhắc nhở bảo mật',
        body: 'Không chia sẻ mật khẩu và mã OTP với bất kỳ ai.',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
        icon: 'info',
      ),
    ]);
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    _items[i] = _items[i].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map(_toJson).toList());
    await prefs.setString(_key, encoded);
  }

  static Map<String, dynamic> _toJson(AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'createdAt': n.createdAt.toIso8601String(),
        'read': n.read,
        'icon': n.icon,
      };

  static AppNotification _fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] as bool? ?? false,
      icon: json['icon'] as String? ?? 'info',
    );
  }
}
