import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Cấu hình base URL của backend NestJS, tự động chọn theo platform.
///
/// LƯU Ý KHI DEMO:
/// - Android Emulator KHÔNG thấy `localhost` của máy host → phải dùng `10.0.2.2`
/// - iOS Simulator dùng `localhost` được
/// - Web (Chrome) dùng `localhost`
/// - Điện thoại thật → đổi `_lanHost` thành IP máy tính (vd 192.168.1.10)
class ApiConfig {
  ApiConfig._();

  /// Port backend NestJS (khớp với PORT trong backend/.env)
  static const int _port = 3000;

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

  /// Dùng khi test trên điện thoại thật (gọi `ApiConfig.lanUrl` thay vì `baseUrl`)
  static String get lanUrl => 'http://$_lanHost:$_port/api';

  static Duration get timeout => const Duration(seconds: 15);
}
