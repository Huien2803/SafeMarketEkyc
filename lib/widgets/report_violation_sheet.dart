import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/report_reasons.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/report_service.dart';
import 'package:safemarket_app/widgets/login_required.dart';

/// Bottom sheet báo cáo vi phạm sản phẩm hoặc người dùng.
Future<bool> showReportViolationSheet(
  BuildContext context, {
  required int reportedUserId,
  required String targetLabel,
  int? productId,
  String? productTitle,
}) async {
  final ok = await ensureLoggedIn(
    context,
    message: 'Đăng nhập để gửi báo cáo vi phạm.',
  );
  if (!ok || !context.mounted) return false;

  if (AuthService.instance.currentUser?.userId == reportedUserId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bạn không thể báo cáo chính mình')),
    );
    return false;
  }

  final isProduct = productId != null;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReportViolationSheetBody(
      reportedUserId: reportedUserId,
      targetLabel: targetLabel,
      productId: productId,
      productTitle: productTitle,
      isProduct: isProduct,
    ),
  );
  return result == true;
}

class _ReportViolationSheetBody extends StatefulWidget {
  const _ReportViolationSheetBody({
    required this.reportedUserId,
    required this.targetLabel,
    required this.isProduct,
    this.productId,
    this.productTitle,
  });

  final int reportedUserId;
  final String targetLabel;
  final bool isProduct;
  final int? productId;
  final String? productTitle;

  @override
  State<_ReportViolationSheetBody> createState() =>
      _ReportViolationSheetBodyState();
}

class _ReportViolationSheetBodyState extends State<_ReportViolationSheetBody> {
  String _category = kReportCategories.first.code;
  final _detailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final detail = _detailCtrl.text.trim();
    if (detail.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mô tả vi phạm tối thiểu 10 ký tự')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ReportService.instance.createReport(
        reportedId: widget.reportedUserId,
        category: _category,
        detail: detail,
        productId: widget.productId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.isProduct
                      ? 'Báo cáo sản phẩm vi phạm'
                      : 'Báo cáo người dùng vi phạm',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.isProduct
                ? 'Sản phẩm: ${widget.productTitle ?? widget.targetLabel}'
                : 'Người dùng: ${widget.targetLabel}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loại vi phạm',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kReportCategories.map((c) {
              final selected = _category == c.code;
              return ChoiceChip(
                label: Text(c.label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _category = c.code),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Mô tả chi tiết',
              hintText: widget.isProduct
                  ? 'Mô tả hành vi lừa đảo, hàng giả, nội dung xấu...'
                  : 'Mô tả hành vi quấy rối, lừa đảo, spam...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Báo cáo sẽ được gửi tới admin SafeMarket để kiểm duyệt.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}
