import 'dart:convert';



import 'package:http/http.dart' as http;

import 'package:safemarket_app/services/api_config.dart';

import 'package:safemarket_app/services/auth_service.dart';



class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.verifiedUsers,
    required this.openReports,
    required this.lockedUsers,
    this.pendingEkyc = 0,
    this.totalProducts = 0,
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.ekycTrend = const [],
  });

  final int totalUsers;
  final int verifiedUsers;
  final int openReports;
  final int lockedUsers;
  final int pendingEkyc;
  final int totalProducts;
  final int totalOrders;
  final int completedOrders;
  final List<EkycTrendPoint> ekycTrend;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final trendRaw = json['ekycTrend'] as List<dynamic>? ?? [];
    return AdminStats(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      verifiedUsers: (json['verifiedUsers'] as num?)?.toInt()
          ?? (json['ekycVerifiedCount'] as num?)?.toInt()
          ?? 0,
      openReports: (json['openReports'] as num?)?.toInt()
          ?? (json['openReportsCount'] as num?)?.toInt()
          ?? 0,
      lockedUsers: (json['lockedUsers'] as num?)?.toInt()
          ?? (json['lockedAccountsCount'] as num?)?.toInt()
          ?? 0,
      pendingEkyc: (json['pendingEkyc'] as num?)?.toInt() ?? 0,
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completedOrders'] as num?)?.toInt() ?? 0,
      ekycTrend: trendRaw
          .map((e) => EkycTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String toReportText() {
    return '''
BÁO CÁO HỆ THỐNG SAFEMARKET
────────────────────────────
Tổng người dùng: $totalUsers
Đã xác thực eKYC: $verifiedUsers
eKYC chờ duyệt: $pendingEkyc
Báo cáo vi phạm (mở): $openReports
Tài khoản bị khóa: $lockedUsers
Tổng sản phẩm: $totalProducts
Tổng đơn hàng: $totalOrders
Giao dịch hoàn tất: $completedOrders
''';
  }
}

class EkycTrendPoint {
  const EkycTrendPoint({required this.label, required this.count});

  final String label;
  final int count;

  factory EkycTrendPoint.fromJson(Map<String, dynamic> json) {
    return EkycTrendPoint(
      label: json['label'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}



class AdminUserRow {

  const AdminUserRow({

    required this.userId,

    required this.email,

    required this.displayName,

    required this.kycStatus,

    required this.accountStatus,

    required this.trustScore,

    required this.rankLevel,

    this.orders = 0,

  });



  final int userId;

  final String email;

  final String? displayName;

  final String kycStatus;

  final String accountStatus;

  final int trustScore;

  final String rankLevel;

  final int orders;



  factory AdminUserRow.fromJson(Map<String, dynamic> json) {

    return AdminUserRow(

      userId: (json['userId'] as num).toInt(),

      email: json['email'] as String,

      displayName: json['displayName'] as String? ?? json['name'] as String?,

      kycStatus: json['kycStatus'] as String? ?? 'Unverified',

      accountStatus: json['accountStatus'] as String? ?? 'Active',

      trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,

      rankLevel: json['rankLevel'] as String? ?? 'Bronze',

      orders: (json['orders'] as num?)?.toInt() ?? 0,

    );

  }

}



class AdminRankRow {
  const AdminRankRow({
    required this.rank,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.kycStatus,
    required this.accountStatus,
    required this.trustScore,
    required this.rankLevel,
    required this.verified,
    this.orders = 0,
  });

  final int rank;
  final int userId;
  final String email;
  final String? displayName;
  final String kycStatus;
  final String accountStatus;
  final int trustScore;
  final String rankLevel;
  final bool verified;
  final int orders;

  factory AdminRankRow.fromJson(Map<String, dynamic> json) {
    return AdminRankRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      kycStatus: json['kycStatus'] as String? ?? 'Unverified',
      accountStatus: json['accountStatus'] as String? ?? 'Active',
      trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,
      rankLevel: json['rankLevel'] as String? ?? 'Bronze',
      verified: json['verified'] as bool? ?? (json['kycStatus'] == 'Verified'),
      orders: (json['orders'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminService {

  AdminService._();

  static final AdminService instance = AdminService._();



  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _errorFromResponse(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        final msg = body['message'];
        if (msg is String) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }



  Future<AdminStats> getStats() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/stats');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode == 401) {
      throw Exception('Phiên đăng nhập hết hạn — vui lòng đăng nhập lại');
    }
    if (res.statusCode == 403) {
      throw Exception('Tài khoản không có quyền admin');
    }
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải thống kê (${res.statusCode})');
    }
    return AdminStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }



  Future<List<AdminUserRow>> getUsers() async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users');

    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode != 200) return [];

    final list = jsonDecode(res.body) as List<dynamic>;

    return list

        .map((e) => AdminUserRow.fromJson(e as Map<String, dynamic>))

        .toList();

  }



  /// Xếp hạng người dùng theo điểm tín nhiệm.
  /// [descending] = true: cao → thấp (mặc định); false: thấp → cao.
  /// Người đã xác thực eKYC luôn xếp trên người chưa xác thực.
  Future<List<AdminRankRow>> getUserRanking({bool descending = true}) async {
    final order = descending ? 'desc' : 'asc';
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/ranking?order=$order');
    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      throw Exception(_errorFromResponse(res, 'Không tải được bảng xếp hạng'));
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => AdminRankRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getReports() async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/reports');

    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode != 200) return [];

    return (jsonDecode(res.body) as List<dynamic>)

        .map((e) => e as Map<String, dynamic>)

        .toList();

  }



  Future<List<Map<String, dynamic>>> getPendingEkyc() async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/ekyc/pending');

    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode != 200) return [];

    return (jsonDecode(res.body) as List<dynamic>)

        .map((e) => e as Map<String, dynamic>)

        .toList();

  }



  Future<List<Map<String, dynamic>>> getLockedUsers() async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/locked');

    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode != 200) return [];

    return (jsonDecode(res.body) as List<dynamic>)

        .map((e) => e as Map<String, dynamic>)

        .toList();

  }



  Future<void> approveEkyc(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/ekyc/$userId/approve');
    final res = await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không phê duyệt được eKYC'));
    }
  }

  Future<void> rejectEkyc(int userId, String reason) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/ekyc/$userId/reject');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode({'reason': reason}))
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không từ chối được eKYC'));
    }
  }



  Future<void> lockUser(int userId, {String reason = 'Vi phạm'}) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/lock');

    final res = await http

        .post(uri, headers: _headers, body: jsonEncode({'reason': reason}))

        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception(_errorFromResponse(res, 'Không khóa được tài khoản'));

    }

  }

  Future<void> banUser(int userId, {String reason = 'Cấm vĩnh viễn'}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/ban');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode({'reason': reason}))
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không cấm được tài khoản'));
    }
  }

  Future<void> punishUser(
    int userId, {
    required int points,
    String reason = 'Vi phạm quy định',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/punish');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'points': points, 'reason': reason}),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không trừ điểm được'));
    }
  }

  Future<void> deleteUser(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/delete');
    final res = await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không xóa được tài khoản'));
    }
  }



  Future<void> unlockUser(int userId) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/unlock');

    final res = await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception('Không mở khóa được tài khoản');

    }

  }



  Future<void> hideProduct(int productId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/products/$productId/hide');
    final res = await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorFromResponse(res, 'Không ẩn được sản phẩm'));
    }
  }

  Future<void> resolveReport(int reportId, {String status = 'Resolved'}) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/reports/$reportId/resolve');

    final res = await http

        .post(uri, headers: _headers, body: jsonEncode({'status': status}))

        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception('Không xử lý được báo cáo');

    }

  }

}

