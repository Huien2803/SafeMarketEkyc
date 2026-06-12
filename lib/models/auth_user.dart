/// Thông tin người dùng đăng nhập (khớp với AuthUserDto của backend).
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.kycStatus,
    required this.accountStatus,
    required this.isAdmin,
    this.displayName,
    this.trustScore,
    this.reviewCount = 0,
    this.averageRating = 0,
  });

  final int userId;
  final String email;
  final String phoneNumber;
  final String? displayName;
  final String kycStatus;
  final String accountStatus;
  final bool isAdmin;
  final int? trustScore;
  final int reviewCount;
  final double averageRating;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String?,
      kycStatus: json['kycStatus'] as String? ?? 'Unverified',
      accountStatus: json['accountStatus'] as String? ?? 'Active',
      isAdmin: json['isAdmin'] as bool? ?? false,
      trustScore: (json['trustScore'] as num?)?.toInt(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'kycStatus': kycStatus,
        'accountStatus': accountStatus,
        'isAdmin': isAdmin,
      };
}

/// Response trả về từ `POST /auth/register` hoặc `/auth/login`.
class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;

  /// Hỗ trợ JSON Java API `{ success, message, user }` và NestJS `{ accessToken, user }`.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('success')) {
      final ok = json['success'] as bool? ?? false;
      if (!ok) {
        throw FormatException(json['message'] as String? ?? 'Đăng nhập thất bại');
      }
      final userMap = json['user'] as Map<String, dynamic>?;
      if (userMap == null) {
        throw const FormatException('Phản hồi API thiếu user');
      }
      final user = AuthUser.fromJson(userMap);
      return AuthResponse(
        accessToken: 'java-session-${user.userId}',
        tokenType: 'Session',
        expiresIn: 0,
        user: user,
      );
    }
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
