import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:safemarket_app/services/admin_service.dart';

/// PDF báo cáo — bám sát nội dung tab Tổng quan trên Dashboard admin.
class AdminReportPdf {
  AdminReportPdf._();

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static pw.Font? _regular;
  static pw.Font? _bold;

  static String fileName() {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    return 'safemarket-bao-cao-$stamp.pdf';
  }

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
  }

  /// Xuất báo cáo tổng hợp giống Dashboard: KPI + bảng chỉ số + biểu đồ + báo cáo mới + users.
  static Future<Uint8List> buildDashboardReport({
    AdminStats? stats,
    List<AdminUserRow> users = const [],
    List<Map<String, dynamic>> reports = const [],
    List<Map<String, dynamic>> pendingEkyc = const [],
    List<Map<String, dynamic>> lockedUsers = const [],
  }) async {
    await _ensureFonts();
    final regular = _regular!;
    final bold = _bold!;
    final exportedAt = _dateFmt.format(DateTime.now());
    final s = stats;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'SafeAdmin — SafeMarket',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              exportedAt,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Trang ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.Text(
            'BÁO CÁO TỔNG QUAN HỆ THỐNG',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Tổng hợp chỉ số Dashboard SafeAdmin — dữ liệu thời gian thực từ SQL Server',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),

          _sectionTitle('Chỉ số KPI (Dashboard)'),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiBox('Tổng người dùng', '${s?.totalUsers ?? 0}'),
              _kpiBox('Đã định danh eKYC', '${s?.verifiedUsers ?? 0}'),
              _kpiBox('eKYC chờ duyệt', '${s?.pendingEkyc ?? 0}'),
              _kpiBox('Báo cáo vi phạm', '${s?.openReports ?? 0}'),
              _kpiBox('Tài khoản bị khóa', '${s?.lockedUsers ?? 0}'),
              _kpiBox('Giao dịch hoàn tất', '${s?.completedOrders ?? 0}'),
            ],
          ),

          pw.SizedBox(height: 18),
          _sectionTitle('Bảng tổng hợp chỉ số hệ thống'),
          pw.SizedBox(height: 8),
          _summaryTable([
            ['Chỉ số', 'Giá trị', 'Ghi chú'],
            ['Tổng người dùng', '${s?.totalUsers ?? 0}', 'Không tính admin'],
            ['Đã xác thực eKYC', '${s?.verifiedUsers ?? 0}', 'kyc_status = Verified'],
            ['eKYC chờ duyệt', '${s?.pendingEkyc ?? 0}', 'Cần admin duyệt'],
            ['Báo cáo vi phạm (mở)', '${s?.openReports ?? 0}', 'status = Open'],
            ['Tài khoản bị khóa', '${s?.lockedUsers ?? 0}', 'Locked / Banned'],
            ['Tổng sản phẩm', '${s?.totalProducts ?? 0}', 'Market.Products'],
            ['Tổng đơn hàng', '${s?.totalOrders ?? 0}', 'Finance.Orders'],
            ['Giao dịch hoàn tất', '${s?.completedOrders ?? 0}', 'order_status = Completed'],
            ['Hồ sơ eKYC pending (chi tiết)', '${pendingEkyc.length}', 'Danh sách chờ duyệt'],
            ['Tài khoản khóa (chi tiết)', '${lockedUsers.length}', 'Danh sách đen'],
          ]),

          pw.SizedBox(height: 18),
          _sectionTitle('Biểu đồ eKYC được duyệt (7 ngày)'),
          pw.SizedBox(height: 8),
          if (s == null || s.ekycTrend.isEmpty)
            _empty('Chưa có dữ liệu biểu đồ')
          else
            _barChart(s.ekycTrend),

          pw.SizedBox(height: 18),
          _sectionTitle('Báo cáo vi phạm mới nhất'),
          pw.SizedBox(height: 8),
          if (reports.isEmpty)
            _empty('Không có báo cáo mở')
          else
            _dataTable(
              headers: ['Người dùng', 'Lý do', 'Mức độ', 'Điểm TN'],
              rows: reports
                  .take(5)
                  .map(
                    (r) => [
                      '${r['name'] ?? ''}',
                      '${r['reason'] ?? ''}',
                      '${r['severity'] ?? ''}',
                      '${r['score'] ?? ''}',
                    ],
                  )
                  .toList(),
            ),

          pw.SizedBox(height: 18),
          _sectionTitle('Quản lý người dùng gần đây'),
          pw.SizedBox(height: 8),
          if (users.isEmpty)
            _empty('Không có dữ liệu người dùng')
          else
            _dataTable(
              headers: ['Người dùng', 'Email', 'eKYC', 'Điểm TN', 'Hạng', 'GD'],
              rows: users
                  .map(
                    (u) => [
                      u.displayName ?? u.email,
                      u.email,
                      u.kycStatus,
                      '${u.trustScore}',
                      u.rankLevel,
                      '${u.orders}',
                    ],
                  )
                  .toList(),
              fontSize: 8,
            ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  static pw.Widget _kpiBox(String title, String value) {
    return pw.Container(
      width: 168,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryTable(List<List<String>> rows) {
    final header = rows.first;
    final body = rows.skip(1).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: header
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...body.asMap().entries.map(
              (entry) => pw.TableRow(
                decoration: entry.key.isOdd
                    ? const pw.BoxDecoration(color: PdfColors.grey100)
                    : null,
                children: entry.value
                    .map(
                      (c) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(c, style: const pw.TextStyle(fontSize: 9)),
                      ),
                    )
                    .toList(),
              ),
            ),
      ],
    );
  }

  static pw.Widget _barChart(List<EkycTrendPoint> trend) {
    final maxCount = trend.map((e) => e.count).fold(0, math.max);
    const chartHeight = 90.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: trend.map((p) {
          final barH = maxCount > 0
              ? chartHeight * p.count / maxCount
              : (p.count > 0 ? 8.0 : 2.0);
          return pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('${p.count}', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    height: barH.clamp(2.0, chartHeight),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue700,
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(4),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(p.label, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _dataTable({
    required List<String> headers,
    required List<List<String>> rows,
    double fontSize = 9,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: fontSize,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(fontSize: fontSize),
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.Widget _empty(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    );
  }
}
