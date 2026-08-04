/// Models cho luồng eKYC (khớp với DTO của backend NestJS).
class IdCardFront {
  IdCardFront({
    required this.idNumber,
    required this.fullName,
    required this.dob,
    required this.sex,
    required this.nationality,
    required this.home,
    required this.address,
    required this.doe,
    required this.type,
  });

  final String idNumber;
  final String fullName;

  /// Định dạng dd/MM/yyyy do FPT.AI trả về.
  final String dob;
  final String sex;
  final String nationality;
  final String home;
  final String address;
  final String doe;
  final String type;

  factory IdCardFront.fromJson(Map<String, dynamic> json) => IdCardFront(
        idNumber: (json['idNumber'] ?? '').toString(),
        fullName: (json['fullName'] ?? '').toString(),
        dob: (json['dob'] ?? '').toString(),
        sex: (json['sex'] ?? '').toString(),
        nationality: (json['nationality'] ?? '').toString(),
        home: (json['home'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
        doe: (json['doe'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
      );

  IdCardFront copyWith({
    String? idNumber,
    String? fullName,
    String? dob,
    String? sex,
    String? nationality,
    String? home,
    String? address,
    String? doe,
    String? type,
  }) {
    return IdCardFront(
      idNumber: idNumber ?? this.idNumber,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      sex: sex ?? this.sex,
      nationality: nationality ?? this.nationality,
      home: home ?? this.home,
      address: address ?? this.address,
      doe: doe ?? this.doe,
      type: type ?? this.type,
    );
  }

  /// Chuyển dd/MM/yyyy -> yyyy-MM-dd cho backend SubmitEkycDto.
  String get dobIso {
    final trimmed = dob.trim();
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
    if (m == null) return trimmed;
    return '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
  }

  /// Địa chỉ gửi backend: ưu tiên thường trú, không có thì dùng quê quán.
  String get resolvedAddress {
    final a = address.trim();
    if (a.isNotEmpty) return a;
    return home.trim();
  }

  /// null = hợp lệ; ngược lại là thông báo lỗi tiếng Việt.
  /// Quê quán không bắt buộc (QR CCCD thường không có quê quán).
  String? validateProfile() {
    final d = dob.trim();
    if (d.isEmpty) {
      return 'Thiếu ngày sinh. Nhập ngày sinh dạng dd/MM/yyyy (ví dụ 04/07/2005).';
    }
    final okDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').hasMatch(d) ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d);
    if (!okDate) {
      return 'Ngày sinh sai định dạng. Dùng dd/MM/yyyy (ví dụ 04/07/2005).';
    }
    if (resolvedAddress.length < 2) {
      return 'Thiếu địa chỉ thường trú (ít nhất 2 ký tự). Nhập địa chỉ bên dưới.';
    }
    return null;
  }
}

class IdCardBack {
  IdCardBack({
    required this.features,
    required this.issueDate,
    required this.issueLoc,
  });

  final String features;
  final String issueDate;
  final String issueLoc;

  factory IdCardBack.fromJson(Map<String, dynamic> json) => IdCardBack(
        features: (json['features'] ?? '').toString(),
        issueDate: (json['issueDate'] ?? '').toString(),
        issueLoc: (json['issueLoc'] ?? '').toString(),
      );

  String? validateBack() {
    if (issueDate.trim().isEmpty) {
      return 'Thiếu ngày cấp mặt sau CCCD. Chụp lại rõ hơn.';
    }
    if (issueLoc.trim().isEmpty) {
      return 'Thiếu nơi cấp mặt sau CCCD. Chụp lại rõ hơn.';
    }
    return null;
  }
}

class FaceMatchResult {
  FaceMatchResult({
    required this.isMatch,
    required this.similarity,
    required this.message,
  });

  final bool isMatch;
  final double similarity;
  final String message;

  factory FaceMatchResult.fromJson(Map<String, dynamic> json) => FaceMatchResult(
        isMatch: json['isMatch'] == true,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
        message: (json['message'] ?? '').toString(),
      );
}

class EkycStatus {
  EkycStatus({
    required this.status,
    required this.fullName,
    required this.idNumber,
    required this.dob,
    required this.address,
    required this.submittedAt,
    required this.verifiedAt,
    required this.rejectionReason,
  });

  /// 'Unverified' | 'Pending' | 'Verified' | 'Rejected'
  final String status;
  final String? fullName;
  final String? idNumber;
  final String? dob;
  final String? address;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  bool get isVerified => status == 'Verified';

  factory EkycStatus.fromJson(Map<String, dynamic> json) => EkycStatus(
        status: (json['status'] ?? 'Unverified').toString(),
        fullName: json['fullName'] as String?,
        idNumber: json['idNumber'] as String?,
        dob: json['dob'] as String?,
        address: json['address'] as String?,
        submittedAt: _parseDate(json['submittedAt']),
        verifiedAt: _parseDate(json['verifiedAt']),
        rejectionReason: json['rejectionReason'] as String?,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
