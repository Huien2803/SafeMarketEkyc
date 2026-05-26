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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String?,
      location: json['location'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      accountStatus: json['accountStatus'] as String,
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      trustScore: json['trustScore'] != null
          ? TrustScore.fromJson(json['trustScore'] as Map<String, dynamic>)
          : null,
      ekyc: EkycSummary.fromJson(json['ekyc'] as Map<String, dynamic>),
    );
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
      currentPoint: (json['currentPoint'] as num).toInt(),
      maxPoint: (json['maxPoint'] as num).toInt(),
      rankLevel: json['rankLevel'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
    );
  }
}
