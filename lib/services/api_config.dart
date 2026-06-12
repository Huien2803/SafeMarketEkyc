import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Cấu hình base URL backend NestJS (SafeMarket API).
///
/// Kiến trúc: Flutter → NestJS (port 3000) → SQL Server
///
/// LƯU Ý KHI DEMO:
/// - Android Emulator: dùng `10.0.2.2` (localhost của máy host)
/// - iOS Simulator: `127.0.0.1`
/// - Web (Chrome): `localhost`
/// - Điện thoại thật → đổi `_lanHost` thành IP máy tính (vd 192.168.1.10)
class ApiConfig {
  ApiConfig._();

  /// Port NestJS (`backend/.env`: PORT=3000)
  static const int _port = 3000;

  /// IP máy tính trong LAN khi test trên điện thoại thật.
  /// Mở CMD gõ `ipconfig` → IPv4 Address
  static const String _lanHost = '192.168.1.10';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_port/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_port/api';
    }
    if (Platform.isIOS) {
      return 'http://127.0.0.1:$_port/api';
    }
    return 'http://localhost:$_port/api';
  }

  /// URL đầy đủ cho media (ảnh sản phẩm).
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final origin = baseUrl.replaceAll('/api', '');
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }

  /// Dùng khi test trên điện thoại thật (gọi `ApiConfig.lanUrl` thay vì `baseUrl`)
  static String get lanUrl => 'http://$_lanHost:$_port/api';

  static Duration get timeout => const Duration(seconds: 15);
}
