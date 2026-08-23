import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cấu hình base URL backend NestJS (SafeMarket API).
///
/// Điện thoại thật + Wireless debugging: dùng IP LAN của PC (cùng WiFi).
/// USB + `adb reverse`: có thể dùng `127.0.0.1`.
class ApiConfig {
  ApiConfig._();

  static const int _port = 3000;

  /// IP LAN hiện tại của PC — đổi khi `ipconfig` đổi IPv4.
  static const String _lanHost =
      String.fromEnvironment('API_HOST', defaultValue: '192.168.1.64');

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String? _resolved;
  static String? _serverLanHost;

  static String _url(String host) => 'http://$host:$_port/api';

  static String get _effectiveLanHost => _serverLanHost ?? _lanHost;

  static List<String> get _candidateHosts {
    if (kIsWeb) return const ['localhost'];
    if (Platform.isAndroid) {
      return ['127.0.0.1', _effectiveLanHost, '10.0.2.2', 'localhost'];
    }
    if (Platform.isIOS) return [_effectiveLanHost, '127.0.0.1', 'localhost'];
    return ['localhost', '127.0.0.1', _effectiveLanHost];
  }

  static List<String> get _basesToTry {
    if (_override.isNotEmpty) return [_override];
    final bases = <String>[];
    if (_resolved != null) bases.add(_resolved!);
    for (final h in _candidateHosts) {
      final u = _url(h);
      if (!bases.contains(u)) bases.add(u);
    }
    return bases;
  }

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (_resolved != null) return _resolved!;
    if (!kIsWeb && Platform.isAndroid) return _url('127.0.0.1');
    return _url(_lanHost);
  }

  static void resetCache() {
    _resolved = null;
    _serverLanHost = null;
  }

  /// Lấy IP LAN thật từ backend `/dev/client-config` (sau CHAY-BACKEND.bat).
  static Future<void> _syncDevConfig(String workingBase) async {
    try {
      final res = await http
          .get(Uri.parse('$workingBase/dev/client-config'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final api = j['apiBaseUrl'] as String?;
      final lan = j['lanHost'] as String?;
      if (lan != null && lan.isNotEmpty) _serverLanHost = lan;
      if (api != null && api.isNotEmpty) {
        _resolved = api;
        debugPrint('ApiConfig: sync từ backend → $_resolved');
      }
    } catch (_) {}
  }

  static Future<String> resolveBaseUrl({bool force = false}) async {
    if (_override.isNotEmpty) {
      _resolved = _override;
      return _override;
    }
    if (!force && _resolved != null) return _resolved!;
    if (force) _resolved = null;

    final hosts = _candidateHosts;
    final results = await Future.wait(
      hosts.map((h) => _ping(_url(h), const Duration(milliseconds: 1500))),
    );
    for (var i = 0; i < hosts.length; i++) {
      if (results[i]) {
        _resolved = _url(hosts[i]);
        await _syncDevConfig(_resolved!);
        debugPrint('ApiConfig: dùng server $_resolved');
        return _resolved!;
      }
    }
    // Không dò được: Android ưu tiên 127.0.0.1 (adb reverse), còn lại dùng LAN.
    _resolved = null;
    final fallback = (!kIsWeb && Platform.isAndroid)
        ? _url('127.0.0.1')
        : _url(_lanHost);
    debugPrint('ApiConfig: chưa dò được server, tạm dùng $fallback');
    return fallback;
  }

  /// Thử lần lượt mọi host — dùng cho GET/POST/multipart.
  static Future<T> withFailover<T>(
    Future<T> Function(String base) run,
  ) async {
    Object? lastError;
    for (final base in _basesToTry) {
      try {
        final result = await run(base);
        _resolved = base;
        await _syncDevConfig(base);
        return result;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('ApiConfig: timeout $base — thử host khác');
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('ApiConfig: socket $base — thử host khác');
      } on http.ClientException catch (e) {
        lastError = e;
        debugPrint('ApiConfig: client $base — thử host khác');
      }
    }
    throw Exception(
      'Không kết nối được backend NestJS.\n'
      '1) PC: chạy CHAY-BACKEND.bat\n'
      '2) Điện thoại cùng WiFi với PC (IP $_effectiveLanHost)\n'
      '3) Hoặc USB + KET-NOI-DIEN-THOAI.bat\n'
      'Đã thử: ${_basesToTry.join(', ')}\n$lastError',
    );
  }

  static Future<http.Response> httpGet(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return withFailover((base) => _getOnce(base, path, query, headers));
  }

  static Future<http.Response> httpPost(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return withFailover((base) => _postOnce(base, path, headers, body));
  }

  static Future<http.Response> httpPut(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return withFailover((base) {
      final p = path.startsWith('/') ? path : '/$path';
      return http
          .put(Uri.parse('$base$p'), headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    });
  }

  static Future<http.Response> httpPatch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return withFailover((base) {
      final p = path.startsWith('/') ? path : '/$path';
      return http
          .patch(Uri.parse('$base$p'), headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    });
  }

  static Future<http.Response> httpDelete(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return withFailover((base) {
      final p = path.startsWith('/') ? path : '/$path';
      return http
          .delete(Uri.parse('$base$p'), headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    });
  }

  static Future<http.Response> _postOnce(
    String base,
    String path,
    Map<String, String>? headers,
    Object? body,
  ) {
    final p = path.startsWith('/') ? path : '/$path';
    return http
        .post(Uri.parse('$base$p'), headers: headers, body: body)
        .timeout(const Duration(seconds: 12));
  }

  static Future<http.Response> _getOnce(
    String base,
    String path,
    Map<String, String>? query,
    Map<String, String>? headers,
  ) {
    final p = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$p').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    return http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
  }

  static Future<bool> _ping(String base, Duration wait) async {
    try {
      final res = await http
          .get(Uri.parse('$base/products/categories'))
          .timeout(wait);
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final origin = baseUrl.replaceAll('/api', '');
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }

  static Map<String, String> jsonHeaders({String? token}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static String? encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  static Duration get timeout => const Duration(seconds: 20);
}
