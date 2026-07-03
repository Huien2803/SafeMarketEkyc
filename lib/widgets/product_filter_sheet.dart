import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safemarket_app/core/constants/vn_provinces.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/product_filters.dart';

/// Bottom sheet lọc giá, khu vực, sắp xếp (kiểu Chợ Tốt).
Future<ProductFilters?> showProductFilterSheet(
  BuildContext context, {
  required ProductFilters initial,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ProductFilterSheetBody(initial: initial),
  );
}

class _ProductFilterSheetBody extends StatefulWidget {
  const _ProductFilterSheetBody({required this.initial});

  final ProductFilters initial;

  @override
  State<_ProductFilterSheetBody> createState() =>
      _ProductFilterSheetBodyState();
}

class _ProductFilterSheetBodyState extends State<_ProductFilterSheetBody> {
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  String? _location;
  late ProductSort _sort;

  @override
  void initState() {
    super.initState();
    _minPriceCtrl = TextEditingController(
      text: _formatPrice(widget.initial.minPrice),
    );
    _maxPriceCtrl = TextEditingController(
      text: _formatPrice(widget.initial.maxPrice),
    );
    _location = widget.initial.location;
    _sort = widget.initial.sort;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(int? value) {
    if (value == null) return '';
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int? _parsePrice(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  ProductFilters _buildResult() {
    return ProductFilters(
      minPrice: _parsePrice(_minPriceCtrl.text),
      maxPrice: _parsePrice(_maxPriceCtrl.text),
      location: _location,
      sort: _sort,
    );
  }

  void _apply() {
    final minP = _parsePrice(_minPriceCtrl.text);
    final maxP = _parsePrice(_maxPriceCtrl.text);
    if (minP != null && maxP != null && minP > maxP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá tối thiểu không được lớn hơn giá tối đa')),
      );
      return;
    }
    Navigator.pop(context, _buildResult());
  }

  void _reset() {
    Navigator.pop(context, ProductFilters.empty);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
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
            const Text(
              'Bộ lọc tìm kiếm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Khu vực',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _location,
                  isExpanded: true,
                  hint: const Text('Tất cả khu vực'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tất cả khu vực'),
                    ),
                    ...kVietnamProvinces.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p,
                        child: Text(p),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _location = v),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Khoảng giá (VNĐ)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Từ',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('—'),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxPriceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Đến',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Sắp xếp',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ProductSort.values.map((s) {
                final selected = _sort == s;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _sort = s),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Xóa lọc'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
