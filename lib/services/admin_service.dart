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

  });



  final int totalUsers;

  final int verifiedUsers;

  final int openReports;

  final int lockedUsers;



  factory AdminStats.fromJson(Map<String, dynamic> json) {

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



  Future<AdminStats> getStats() async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/stats');

    final res = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode != 200) throw Exception('Lỗi tải thống kê');

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

      throw Exception('Không phê duyệt được eKYC');

    }

  }



  Future<void> rejectEkyc(int userId, String reason) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/ekyc/$userId/reject');

    final res = await http

        .post(uri, headers: _headers, body: jsonEncode({'reason': reason}))

        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception('Không từ chối được eKYC');

    }

  }



  Future<void> lockUser(int userId, {String reason = 'Vi phạm'}) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/lock');

    final res = await http

        .post(uri, headers: _headers, body: jsonEncode({'reason': reason}))

        .timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception('Không khóa được tài khoản');

    }

  }



  Future<void> unlockUser(int userId) async {

    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId/unlock');

    final res = await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {

      throw Exception('Không mở khóa được tài khoản');

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

