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

  /// Chuyển dd/MM/yyyy -> yyyy-MM-dd cho backend SubmitEkycDto.
  String get dobIso {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(dob);
    if (m == null) return dob;
    return '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
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
