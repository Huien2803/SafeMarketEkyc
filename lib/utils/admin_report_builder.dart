import 'package:intl/intl.dart';
import 'package:safemarket_app/services/admin_service.dart';

/// Tạo nội dung báo cáo admin (CSV mở được bằng Excel).
class AdminReportBuilder {
  AdminReportBuilder._();

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  static String buildCsv({
    AdminStats? stats,
    List<AdminUserRow> users = const [],
    List<Map<String, dynamic>> reports = const [],
    List<Map<String, dynamic>> pendingEkyc = const [],
    List<Map<String, dynamic>> lockedUsers = const [],
  }) {
    final now = DateTime.now();
    final buf = StringBuffer('\uFEFF'); // BOM UTF-8 cho Excel

    buf.writeln('BÁO CÁO HỆ THỐNG SAFEMARKET');
    buf.writeln('Ngày xuất,${_cell(_dateFmt.format(now))}');
    buf.writeln();

    buf.writeln('TỔNG QUAN');
    buf.writeln('Chỉ số,Giá trị');
    final s = stats;
    buf.writeln('Tổng người dùng,${_cell(s?.totalUsers ?? 0)}');
    buf.writeln('Đã xác thực eKYC,${_cell(s?.verifiedUsers ?? 0)}');
    buf.writeln('eKYC chờ duyệt,${_cell(s?.pendingEkyc ?? 0)}');
    buf.writeln('Báo cáo vi phạm (mở),${_cell(s?.openReports ?? 0)}');
    buf.writeln('Tài khoản bị khóa,${_cell(s?.lockedUsers ?? 0)}');
    buf.writeln('Tổng sản phẩm,${_cell(s?.totalProducts ?? 0)}');
    buf.writeln('Tổng đơn hàng,${_cell(s?.totalOrders ?? 0)}');
    buf.writeln('Giao dịch hoàn tất,${_cell(s?.completedOrders ?? 0)}');
    buf.writeln();

    if (s != null && s.ekycTrend.isNotEmpty) {
      buf.writeln('eKYC DUYỆT 7 NGÀY');
      buf.writeln('Ngày,Số hồ sơ');
      for (final p in s.ekycTrend) {
        buf.writeln('${_cell(p.label)},${_cell(p.count)}');
      }
      buf.writeln();
    }

    buf.writeln('DANH SÁCH NGƯỜI DÙNG');
    buf.writeln(
      'ID,Tên hiển thị,Email,Trạng thái eKYC,Trạng thái TK,Điểm tín nhiệm,Hạng,Giao dịch',
    );
    if (users.isEmpty) {
      buf.writeln('(Không có dữ liệu)');
    } else {
      for (final u in users) {
        buf.writeln([
          _cell(u.userId),
          _cell(u.displayName ?? ''),
          _cell(u.email),
          _cell(u.kycStatus),
          _cell(u.accountStatus),
          _cell(u.trustScore),
          _cell(u.rankLevel),
          _cell(u.orders),
        ].join(','));
      }
    }
    buf.writeln();

    buf.writeln('BÁO CÁO VI PHẠM (ĐANG MỞ)');
    buf.writeln('ID,Người bị báo cáo,Lý do,Mức độ,Điểm');
    if (reports.isEmpty) {
      buf.writeln('(Không có báo cáo mở)');
    } else {
      for (final r in reports) {
        buf.writeln([
          _cell(r['reportId']),
          _cell(r['name']),
          _cell(r['reason']),
          _cell(r['severity']),
          _cell(r['score']),
        ].join(','));
      }
    }
    buf.writeln();

    buf.writeln('eKYC CHỜ DUYỆT');
    buf.writeln('ID,Tên,CMND/CCCD,Họ tên trên giấy tờ');
    if (pendingEkyc.isEmpty) {
      buf.writeln('(Không có hồ sơ chờ duyệt)');
    } else {
      for (final e in pendingEkyc) {
        buf.writeln([
          _cell(e['userId']),
          _cell(e['displayName']),
          _cell(e['idNumber']),
          _cell(e['fullName']),
        ].join(','));
      }
    }
    buf.writeln();

    buf.writeln('TÀI KHOẢN BỊ KHÓA');
    buf.writeln('ID,Tên,Trạng thái,Lý do khóa');
    if (lockedUsers.isEmpty) {
      buf.writeln('(Không có tài khoản bị khóa)');
    } else {
      for (final u in lockedUsers) {
        buf.writeln([
          _cell(u['userId']),
          _cell(u['displayName']),
          _cell(u['accountStatus']),
          _cell(u['lockReason']),
        ].join(','));
      }
    }

    return buf.toString();
  }

  static String fileName() {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    return 'safemarket-bao-cao-$stamp.csv';
  }

  static String _cell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }
}
