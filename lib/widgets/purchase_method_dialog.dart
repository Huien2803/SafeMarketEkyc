import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Hai phương thức mua hàng của SafeMarket.
class PurchaseMethodChoice {
  const PurchaseMethodChoice({
    required this.paymentMethod,
    required this.deliveryMethod,
    required this.title,
    required this.subtitle,
    required this.addressLabel,
    required this.addressHint,
    required this.icon,
  });

  final String paymentMethod;
  final String deliveryMethod;
  final String title;
  final String subtitle;
  final String addressLabel;
  final String addressHint;
  final IconData icon;

  static const bankTransferShip = PurchaseMethodChoice(
    paymentMethod: 'BANK_TRANSFER',
    deliveryMethod: 'SHIP',
    title: 'Chuyển khoản + Giao ship',
    subtitle: 'Chuyển khoản cho người bán, nhận hàng qua đơn vị vận chuyển',
    addressLabel: 'Địa chỉ nhận hàng',
    addressHint: 'Quận 1, TP.HCM',
    icon: Icons.local_shipping_outlined,
  );

  static const cashDirect = PurchaseMethodChoice(
    paymentMethod: 'CASH',
    deliveryMethod: 'DIRECT',
    title: 'Tiền mặt + Giao trực tiếp',
    subtitle: 'Hẹn gặp người bán, trả tiền mặt khi nhận hàng',
    addressLabel: 'Địa điểm hẹn giao',
    addressHint: 'Quán cà phê, Bến xe, Quận 3...',
    icon: Icons.handshake_outlined,
  );

  static const all = [bankTransferShip, cashDirect];

  bool get isDirect => deliveryMethod == 'DIRECT';
}

class PurchaseMethodResult {
  const PurchaseMethodResult({
    required this.method,
    required this.address,
  });

  final PurchaseMethodChoice method;
  final String address;
}

/// Dialog chọn phương thức mua (dùng chung trang chi tiết SP & chat).
Future<PurchaseMethodResult?> showPurchaseMethodDialog(
  BuildContext context, {
  required String productTitle,
  String? defaultAddress,
}) {
  return showDialog<PurchaseMethodResult>(
    context: context,
    builder: (ctx) => _PurchaseMethodDialog(
      productTitle: productTitle,
      defaultAddress: defaultAddress,
    ),
  );
}

class _PurchaseMethodDialog extends StatefulWidget {
  const _PurchaseMethodDialog({
    required this.productTitle,
    this.defaultAddress,
  });

  final String productTitle;
  final String? defaultAddress;

  @override
  State<_PurchaseMethodDialog> createState() => _PurchaseMethodDialogState();
}

class _PurchaseMethodDialogState extends State<_PurchaseMethodDialog> {
  PurchaseMethodChoice _selected = PurchaseMethodChoice.bankTransferShip;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(
      text: widget.defaultAddress ?? 'Quận 1, TP.HCM',
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onSelect(PurchaseMethodChoice m) {
    setState(() {
      _selected = m;
      if (m.isDirect && _addressCtrl.text == 'Quận 1, TP.HCM') {
        _addressCtrl.text = widget.defaultAddress ?? 'Quận 3, TP.HCM';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn phương thức mua'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...PurchaseMethodChoice.all.map((m) {
              final selected = _selected == m;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _onSelect(m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted.withValues(alpha: 0.3),
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? AppColors.sellerCardBg
                          : AppColors.white,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m.icon, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: _selected.addressLabel,
                hintText: _selected.addressHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () {
            final addr = _addressCtrl.text.trim();
            if (addr.isEmpty) return;
            Navigator.pop(
              context,
              PurchaseMethodResult(method: _selected, address: addr),
            );
          },
          child: const Text('Tiếp tục'),
        ),
      ],
    );
  }
}
