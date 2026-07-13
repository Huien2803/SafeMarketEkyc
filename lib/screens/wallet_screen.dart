import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/wallet.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<WalletInfo> _walletFuture;
  late Future<List<WithdrawalItem>> _withdrawalsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _walletFuture = WalletService.instance.getWallet();
      _withdrawalsFuture = WalletService.instance.getWithdrawals();
    });
  }

  Future<void> _openWithdrawSheet(WalletInfo wallet) async {
    if (wallet.balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số dư ví đang trống, chưa thể rút tiền')),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WithdrawSheet(wallet: wallet),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ví của tôi'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<WalletInfo>(
          future: _walletFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('${snap.error ?? "Lỗi tải ví"}')),
                ],
              );
            }
            final wallet = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _BalanceCard(
                  wallet: wallet,
                  onWithdraw: () => _openWithdrawSheet(wallet),
                ),
                const SizedBox(height: 24),
                const Text(
                  'LỊCH SỬ RÚT TIỀN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<WithdrawalItem>>(
                  future: _withdrawalsFuture,
                  builder: (context, wSnap) {
                    final items = wSnap.data ?? [];
                    if (items.isEmpty) {
                      return _emptyBox('Chưa có lệnh rút tiền nào');
                    }
                    return Column(
                      children: items.map(_withdrawalTile).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'GIAO DỊCH VÍ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (wallet.transactions.isEmpty)
                  _emptyBox('Chưa có giao dịch nào')
                else
                  Column(
                    children: wallet.transactions.map(_txnTile).toList(),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyBox(String text) => Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: Center(
          child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
        ),
      );

  Widget _txnTile(WalletTxn t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (t.isCredit ? AppColors.trustGreen : AppColors.danger)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              t.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: t.isCredit ? AppColors.trustGreen : AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.typeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (t.note != null && t.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _formatDate(t.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            t.amountFormatted,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: t.isCredit ? AppColors.trustGreen : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawalTile(WithdrawalItem w) {
    final color = switch (w.status) {
      'Completed' => AppColors.trustGreen,
      'Rejected' => AppColors.danger,
      _ => Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined,
              color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${w.bankName} • ${w.bankAccount}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${w.accountHolder} · ${_formatDate(w.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                w.amountFormatted,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  w.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mi';
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.wallet,
    required this.onWithdraw,
  });

  final WalletInfo wallet;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.trustCardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SỐ DƯ KHẢ DỤNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wallet.balanceFormatted,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tiền bán hàng được giải ngân từ escrow sau khi giao dịch hoàn tất.',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWithdraw,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Rút tiền về ngân hàng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.wallet});
  final WalletInfo wallet;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.wallet.balance.toString();
    final name = AuthService.instance.currentUser?.displayName;
    if (name != null) _holderCtrl.text = name.toUpperCase();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 10000) {
      _snack('Số tiền rút tối thiểu 10.000đ');
      return;
    }
    if (amount > widget.wallet.balance) {
      _snack('Số tiền vượt quá số dư (${widget.wallet.balanceFormatted})');
      return;
    }
    if (_bankCtrl.text.trim().isEmpty ||
        _accountCtrl.text.trim().isEmpty ||
        _holderCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập đầy đủ thông tin ngân hàng');
      return;
    }
    setState(() => _submitting = true);
    try {
      final msg = await WalletService.instance.requestWithdrawal(
        amount: amount,
        bankName: _bankCtrl.text.trim(),
        bankAccount: _accountCtrl.text.trim(),
        accountHolder: _holderCtrl.text.trim(),
      );
      if (!mounted) return;
      _snack(msg);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
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
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rút tiền về ngân hàng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Số dư khả dụng: ${widget.wallet.balanceFormatted}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('Số tiền (VND)', Icons.payments_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bankCtrl,
            decoration: _dec('Ngân hàng', Icons.account_balance_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Số tài khoản', Icons.numbers_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _holderCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: _dec('Chủ tài khoản', Icons.person_outline),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Xác nhận rút tiền'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
