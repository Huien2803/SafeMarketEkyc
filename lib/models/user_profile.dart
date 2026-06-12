/// Profile đầy đủ của user — khớp với UserProfileDto trong backend.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.accountStatus,
    required this.isAdmin,
    required this.createdAt,
    required this.ekyc,
    this.activeListingCount = 0,
    this.soldCount = 0,
    this.boughtCount = 0,
    this.reviewCount = 0,
    this.averageRating = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.displayName,
    this.location,
    this.avatarUrl,
    this.trustScore,
  });

  final int userId;
  final String email;
  final String phoneNumber;
  final String? displayName;
  final String? location;
  final String? avatarUrl;
  final String accountStatus;
  final bool isAdmin;
  final DateTime createdAt;
  final TrustScore? trustScore;
  final EkycSummary ekyc;
  final int activeListingCount;
  final int soldCount;
  final int boughtCount;
  final int reviewCount;
  final double averageRating;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String?,
      location: json['location'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      accountStatus: json['accountStatus'] as String? ?? 'Active',
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      trustScore: json['trustScore'] != null
          ? TrustScore.fromJson(json['trustScore'] as Map<String, dynamic>)
          : null,
      ekyc: json['ekyc'] != null
          ? EkycSummary.fromJson(json['ekyc'] as Map<String, dynamic>)
          : EkycSummary(status: json['kycStatus'] as String? ?? 'Unverified'),
      activeListingCount: (json['activeListingCount'] as num?)?.toInt() ?? 0,
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
      boughtCount: (json['boughtCount'] as num?)?.toInt() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 2 ký tự đầu của tên (cho avatar placeholder).
  String get initials {
    final source = (displayName ?? email).trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class TrustScore {
  const TrustScore({
    required this.currentPoint,
    required this.maxPoint,
    required this.rankLevel,
    required this.updatedAt,
  });

  final int currentPoint;
  final int maxPoint;
  final String rankLevel;
  final DateTime updatedAt;

  double get progress =>
      maxPoint == 0 ? 0.0 : (currentPoint / maxPoint).clamp(0.0, 1.0);

  /// Map rank tiếng Anh → label tiếng Việt cho UI.
  String get rankLabel {
    switch (rankLevel) {
      case 'Bronze':
        return 'ĐỒNG';
      case 'Silver':
        return 'BẠC';
      case 'Gold':
        return 'VÀNG';
      case 'Diamond':
        return 'KIM CƯƠNG';
      default:
        return rankLevel.toUpperCase();
    }
  }

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      currentPoint: (json['currentPoint'] as num?)?.toInt() ?? 500,
      maxPoint: (json['maxPoint'] as num?)?.toInt() ?? 1000,
      rankLevel: json['rankLevel'] as String? ?? 'Bronze',
      updatedAt: UserProfile._parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class EkycSummary {
  const EkycSummary({
    required this.status,
    this.fullName,
    this.idNumber,
    this.verifiedAt,
  });

  final String status;
  final String? fullName;
  final String? idNumber;
  final DateTime? verifiedAt;

  bool get isVerified => status == 'Verified';
  bool get isPending => status == 'Pending';
  bool get isRejected => status == 'Rejected';

  factory EkycSummary.fromJson(Map<String, dynamic> json) {
    return EkycSummary(
      status: json['status'] as String? ?? 'Unverified',
      fullName: json['fullName'] as String?,
      idNumber: json['idNumber'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? UserProfile._parseDate(json['verifiedAt'])
          : null,
    );
  }
}
