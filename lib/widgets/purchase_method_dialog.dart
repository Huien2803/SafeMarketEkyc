import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Phương thức mua hàng.
class PurchaseMethodChoice {
  const PurchaseMethodChoice({
    required this.paymentMethod,
    required this.deliveryMethod,
    required this.title,
    required this.subtitle,
    required this.addressLabel,
    required this.addressHint,
    required this.icon,
    this.recommended = false,
  });

  final String paymentMethod;
  final String deliveryMethod;
  final String title;
  final String subtitle;
  final String addressLabel;
  final String addressHint;
  final IconData icon;
  final bool recommended;

  bool get isOnlineEscrow => paymentMethod == 'ONLINE_ESCROW';
  bool get isDirect => deliveryMethod == 'DIRECT';

  static const cashDirect = PurchaseMethodChoice(
    paymentMethod: 'CASH',
    deliveryMethod: 'DIRECT',
    title: 'Tiền mặt + Giao trực tiếp',
    subtitle: 'Hẹn gặp người bán, trả tiền mặt khi nhận hàng',
    addressLabel: 'Địa điểm hẹn giao',
    addressHint: 'Quán cà phê, Bến xe, Quận 3...',
    icon: Icons.handshake_outlined,
  );

  static const onlineEscrowDirect = PurchaseMethodChoice(
    paymentMethod: 'ONLINE_ESCROW',
    deliveryMethod: 'DIRECT',
    title: 'Thanh toán online + Giao trực tiếp',
    subtitle:
        'Trả qua VNPay — SafeMarket giữ tiền tạm (escrow) đến khi bạn xác nhận nhận hàng',
    addressLabel: 'Địa điểm hẹn giao',
    addressHint: 'Quán cà phê, Bến xe, Quận 3...',
    icon: Icons.account_balance_wallet_outlined,
    recommended: true,
  );

  static const onlineEscrowShip = PurchaseMethodChoice(
    paymentMethod: 'ONLINE_ESCROW',
    deliveryMethod: 'SHIP',
    title: 'Thanh toán online + Giao ship',
    subtitle:
        'Trả qua VNPay — tiền tạm giữ tại app, giải ngân cho người bán khi hoàn tất',
    addressLabel: 'Địa chỉ nhận hàng',
    addressHint: '123 Nguyễn Huệ, Q1, TP.HCM',
    icon: Icons.local_shipping_outlined,
    recommended: true,
  );

  static const all = [
    onlineEscrowDirect,
    onlineEscrowShip,
    cashDirect,
  ];
}

class PurchaseMethodResult {
  const PurchaseMethodResult({
    required this.method,
    required this.address,
  });

  final PurchaseMethodChoice method;
  final String address;
}

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
  PurchaseMethodChoice _method = PurchaseMethodChoice.onlineEscrowDirect;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(
      text: widget.defaultAddress ?? 'Quận 3, TP.HCM',
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onMethodChanged(PurchaseMethodChoice m) {
    setState(() {
      _method = m;
      if (m.deliveryMethod == 'SHIP' &&
          _addressCtrl.text.trim() == 'Quận 3, TP.HCM') {
        _addressCtrl.text = '123 Nguyễn Huệ, Q1, TP.HCM';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đặt mua hàng'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thanh toán online: tiền vào escrow SafeMarket, '
                      'chỉ giải ngân khi giao dịch hoàn tất.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...PurchaseMethodChoice.all.map((m) {
              final selected = _method == m;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _onMethodChanged(m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? AppColors.sellerCardBg
                          : Colors.transparent,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m.icon,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (m.recommended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.trustGreen
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Khuyên dùng',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.trustGreen,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                labelText: _method.addressLabel,
                hintText: _method.addressHint,
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
              PurchaseMethodResult(method: _method, address: addr),
            );
          },
          child: const Text('Tiếp tục'),
        ),
      ],
    );
  }
}
