import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Cấu hình base URL backend Java Spring Boot (SafeMarket.JavaApi).
///
/// Kiến trúc đồ án: Flutter → Java API (port 5214) → SQL Server.
/// Thư mục `backend/` (NestJS) trong repo GitHub là tùy chọn — không bắt buộc Node.js.
///
/// LƯU Ý KHI DEMO:
/// - Android Emulator KHÔNG thấy `localhost` của máy host → phải dùng `10.0.2.2`
/// - iOS Simulator dùng `localhost` được
/// - Web (Chrome) dùng `localhost`
/// - Điện thoại thật → đổi `_lanHost` thành IP máy tính (vd 192.168.1.10)
class ApiConfig {
  ApiConfig._();

  /// Port Java API (`application.properties`: server.port=5214)
  static const int _port = 5214;

  /// IP máy tính trong LAN khi test trên điện thoại thật.
  /// Mở CMD gõ `ipconfig` → IPv4 Address (vd: 192.168.1.10)
  static const String _lanHost = '192.168.1.10';

  /// Tự động sinh base URL phù hợp với platform đang chạy.
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
