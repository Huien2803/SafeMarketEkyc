import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cấu hình base URL backend NestJS (SafeMarket API).
///
/// Kiến trúc: Flutter → NestJS (port 3000) → SQL Server
///
/// CHẠY MƯỢT TRÊN MỌI THIẾT BỊ:
/// - App tự DÒ địa chỉ server lúc khởi động (gọi [resolveBaseUrl]) bằng cách
///   thử lần lượt các ứng viên và chọn cái nào phản hồi.
///   • Máy ảo Android → 10.0.2.2
///   • Điện thoại thật → IP LAN của máy tính (cùng WiFi)
///   • Web / iOS / Desktop → localhost / 127.0.0.1
/// - Có thể ÉP địa chỉ khi chạy:
///     flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/api
///   hoặc chỉ đổi host:
///     flutter run --dart-define=API_HOST=192.168.1.5
class ApiConfig {
  ApiConfig._();

  /// Port NestJS (`backend/.env`: PORT=3000)
  static const int _port = 3000;

  /// IP máy tính trong LAN khi test trên điện thoại thật (cùng WiFi).
  /// Mở CMD gõ `ipconfig` → IPv4 Address. Có thể override bằng --dart-define.
  static const String _lanHost =
      String.fromEnvironment('API_HOST', defaultValue: '192.168.1.5');

  /// Ép hẳn base URL (ưu tiên cao nhất) qua --dart-define=API_BASE_URL=...
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base URL đã dò được (cache sau lần [resolveBaseUrl] đầu tiên).
  static String? _resolved;

  static String _url(String host) => 'http://$host:$_port/api';

  /// Danh sách host ứng viên theo nền tảng (thử theo thứ tự).
  static List<String> get _candidateHosts {
    if (kIsWeb) return const ['localhost'];
    if (Platform.isAndroid) return ['10.0.2.2', _lanHost, 'localhost'];
    if (Platform.isIOS) return ['127.0.0.1', _lanHost, 'localhost'];
    return ['localhost', _lanHost];
  }

  /// Base URL hiện dùng (đồng bộ). Trả về giá trị đã dò nếu có,
  /// nếu chưa thì đoán ứng viên đầu tiên (hoặc override).
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (_resolved != null) return _resolved!;
    return _url(_candidateHosts.first);
  }

  /// Dò server lúc khởi động: thử từng host, chọn host phản hồi đầu tiên.
  /// Gọi 1 lần trong `main()` trước khi runApp.
  static Future<String> resolveBaseUrl() async {
    if (_override.isNotEmpty) {
      _resolved = _override;
      return _override;
    }
    for (final host in _candidateHosts) {
      final url = _url(host);
      if (await _ping(url)) {
        _resolved = url;
        debugPrint('ApiConfig: dùng server $url');
        return url;
      }
    }
    // Không host nào phản hồi — giữ ứng viên đầu tiên để báo lỗi rõ ràng sau.
    _resolved = _url(_candidateHosts.first);
    debugPrint('ApiConfig: không dò được server, tạm dùng $_resolved');
    return _resolved!;
  }

  /// Kiểm tra nhanh 1 base URL có sống không (bất kỳ phản hồi HTTP nào = sống).
  static Future<bool> _ping(String base) async {
    try {
      // GET /api — kể cả 404 vẫn chứng tỏ server phản hồi.
      final res = await http
          .get(Uri.parse(base))
          .timeout(const Duration(milliseconds: 1500));
      return res.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  /// URL đầy đủ cho media (ảnh sản phẩm, ảnh bằng chứng…).
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final origin = baseUrl.replaceAll('/api', '');
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }

  static Duration get timeout => const Duration(seconds: 15);
}
