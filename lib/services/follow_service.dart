import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';

class FollowStatus {
  const FollowStatus({
    required this.following,
    required this.followerCount,
    required this.followingCount,
  });

  final bool following;
  final int followerCount;
  final int followingCount;

  factory FollowStatus.fromJson(Map<String, dynamic> json) {
    return FollowStatus(
      following: json['following'] as bool? ?? false,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> follow(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/follows/$userId');
    final res =
        await http.post(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không theo dõi được người này');
    }
  }

  Future<void> unfollow(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/follows/$userId');
    final res =
        await http.delete(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không bỏ theo dõi được');
    }
  }

  Future<FollowStatus> getStatus(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/follows/$userId/status');
    final res =
        await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      return const FollowStatus(
        following: false,
        followerCount: 0,
        followingCount: 0,
      );
    }
    return FollowStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
