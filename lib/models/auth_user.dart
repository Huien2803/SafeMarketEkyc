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
  });

  final int userId;
  final String email;
  final String phoneNumber;
  final String? displayName;
  final String kycStatus;
  final String accountStatus;
  final bool isAdmin;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String?,
      kycStatus: json['kycStatus'] as String? ?? 'Unverified',
      accountStatus: json['accountStatus'] as String? ?? 'Active',
      isAdmin: json['isAdmin'] as bool? ?? false,
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

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
