import 'dart:convert';

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

class FollowUserItem {
  const FollowUserItem({
    required this.userId,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.kycStatus,
  });

  final int userId;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? kycStatus;

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : email;

  String get initials {
    final s = label.trim();
    if (s.isEmpty) return '?';
    return s.substring(0, 1).toUpperCase();
  }

  factory FollowUserItem.fromJson(Map<String, dynamic> json) {
    return FollowUserItem(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      kycStatus: json['kycStatus'] as String?,
    );
  }
}

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return ApiConfig.jsonHeaders(token: token);
  }

  Future<void> follow(int userId) async {
    final res = await ApiConfig.httpPost(
      '/follows/$userId',
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không theo dõi được người này');
    }
  }

  Future<void> unfollow(int userId) async {
    final res = await ApiConfig.httpDelete(
      '/follows/$userId',
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không bỏ theo dõi được');
    }
  }

  Future<FollowStatus> getStatus(int userId) async {
    final res = await ApiConfig.httpGet(
      '/follows/$userId/status',
      headers: _headers,
    );
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

  Future<List<FollowUserItem>> listFollowers(int userId) async {
    final res = await ApiConfig.httpGet(
      '/follows/$userId/followers',
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Không tải được danh sách người theo dõi');
    }
    final raw = jsonDecode(res.body);
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FollowUserItem.fromJson)
        .toList();
  }

  Future<List<FollowUserItem>> listFollowing(int userId) async {
    final res = await ApiConfig.httpGet(
      '/follows/$userId/following',
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Không tải được danh sách đang theo dõi');
    }
    final raw = jsonDecode(res.body);
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FollowUserItem.fromJson)
        .toList();
  }
}
