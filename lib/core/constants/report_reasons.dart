/// Loại vi phạm khi báo cáo sản phẩm / người dùng.
class ReportCategoryOption {
  const ReportCategoryOption({
    required this.code,
    required this.label,
    required this.severity,
  });

  final String code;
  final String label;
  final String severity;
}

const kReportCategories = [
  ReportCategoryOption(
    code: 'SCAM',
    label: 'Lừa đảo / chiếm đoạt',
    severity: 'high',
  ),
  ReportCategoryOption(
    code: 'FAKE_OR_BANNED',
    label: 'Hàng giả / hàng cấm',
    severity: 'high',
  ),
  ReportCategoryOption(
    code: 'MISLEADING',
    label: 'Thông tin sai lệch',
    severity: 'medium',
  ),
  ReportCategoryOption(
    code: 'OFFENSIVE_SPAM',
    label: 'Nội dung phản cảm / spam',
    severity: 'medium',
  ),
  ReportCategoryOption(
    code: 'HARASSMENT',
    label: 'Quấy rối / đe dọa',
    severity: 'high',
  ),
  ReportCategoryOption(
    code: 'OTHER',
    label: 'Vi phạm khác',
    severity: 'medium',
  ),
];

ReportCategoryOption? reportCategoryByCode(String code) {
  for (final c in kReportCategories) {
    if (c.code == code) return c;
  }
  return null;
}
