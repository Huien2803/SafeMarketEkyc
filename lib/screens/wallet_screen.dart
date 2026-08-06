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

class _BankInfo {
  const _BankInfo({
    required this.code,
    required this.shortName,
    required this.fullName,
    required this.color,
  });

  final String code;
  final String shortName;
  final String fullName;
  final Color color;

  String get displayName => '$shortName ($code)';
}

const _kBanks = <_BankInfo>[
  _BankInfo(
    code: 'MB',
    shortName: 'MBBank',
    fullName: 'Ngân hàng TMCP Quân đội',
    color: Color(0xFF141ED2),
  ),
  _BankInfo(
    code: 'MBV',
    shortName: 'Việt Nam Hiện Đại',
    fullName: 'Ngân hàng TNHH MTV Việt Nam Hiện Đại (MBV)',
    color: Color(0xFFE30613),
  ),
  _BankInfo(
    code: 'VBA',
    shortName: 'Agribank',
    fullName: 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam',
    color: Color(0xFFC8102E),
  ),
  _BankInfo(
    code: 'VCB',
    shortName: 'Vietcombank',
    fullName: 'Ngân hàng TMCP Ngoại thương Việt Nam',
    color: Color(0xFF007A33),
  ),
  _BankInfo(
    code: 'CTG',
    shortName: 'VietinBank',
    fullName: 'Ngân hàng TMCP Công thương Việt Nam',
    color: Color(0xFF0055A5),
  ),
  _BankInfo(
    code: 'BIDV',
    shortName: 'BIDV',
    fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'TCB',
    shortName: 'Techcombank',
    fullName: 'Ngân hàng TMCP Kỹ thương Việt Nam',
    color: Color(0xFFED1C24),
  ),
  _BankInfo(
    code: 'ACB',
    shortName: 'ACB',
    fullName: 'Ngân hàng TMCP Á Châu',
    color: Color(0xFF003D7C),
  ),
  _BankInfo(
    code: 'VPB',
    shortName: 'VPBank',
    fullName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng',
    color: Color(0xFF00A651),
  ),
  _BankInfo(
    code: 'TPB',
    shortName: 'TPBank',
    fullName: 'Ngân hàng TMCP Tiên Phong',
    color: Color(0xFF7B2D8E),
  ),
  _BankInfo(
    code: 'STB',
    shortName: 'Sacombank',
    fullName: 'Ngân hàng TMCP Sài Gòn Thương Tín',
    color: Color(0xFF003B7A),
  ),
  _BankInfo(
    code: 'VIB',
    shortName: 'VIB',
    fullName: 'Ngân hàng TMCP Quốc tế Việt Nam',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'MSB',
    shortName: 'MSB',
    fullName: 'Ngân hàng TMCP Hàng Hải Việt Nam',
    color: Color(0xFF003366),
  ),
  _BankInfo(
    code: 'SHB',
    shortName: 'SHB',
    fullName: 'Ngân hàng TMCP Sài Gòn – Hà Nội',
    color: Color(0xFFEE1C25),
  ),
  _BankInfo(
    code: 'OCB',
    shortName: 'OCB',
    fullName: 'Ngân hàng TMCP Phương Đông',
    color: Color(0xFF00A651),
  ),
  _BankInfo(
    code: 'HDB',
    shortName: 'HDBank',
    fullName: 'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh',
    color: Color(0xFFE30613),
  ),
  _BankInfo(
    code: 'LPB',
    shortName: 'LienVietPostBank',
    fullName: 'Ngân hàng TMCP Bưu điện Liên Việt',
    color: Color(0xFF00843D),
  ),
  _BankInfo(
    code: 'SEAB',
    shortName: 'SeABank',
    fullName: 'Ngân hàng TMCP Đông Nam Á',
    color: Color(0xFF003DA5),
  ),
  _BankInfo(
    code: 'ABB',
    shortName: 'ABBank',
    fullName: 'Ngân hàng TMCP An Bình',
    color: Color(0xFF0054A6),
  ),
  _BankInfo(
    code: 'BVB',
    shortName: 'BaoVietBank',
    fullName: 'Ngân hàng TMCP Bảo Việt',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'NAB',
    shortName: 'NamABank',
    fullName: 'Ngân hàng TMCP Nam Á',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'PGB',
    shortName: 'PGBank',
    fullName: 'Ngân hàng TMCP Xăng dầu Petrolimex',
    color: Color(0xFFEE1C25),
  ),
  _BankInfo(
    code: 'VAB',
    shortName: 'VietABank',
    fullName: 'Ngân hàng TMCP Việt Á',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'BAB',
    shortName: 'BacABank',
    fullName: 'Ngân hàng TMCP Bắc Á',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'PVCB',
    shortName: 'PVcomBank',
    fullName: 'Ngân hàng TMCP Đại Chúng Việt Nam',
    color: Color(0xFFEE7623),
  ),
  _BankInfo(
    code: 'SCB',
    shortName: 'SCB',
    fullName: 'Ngân hàng TMCP Sài Gòn',
    color: Color(0xFF0066B3),
  ),
  _BankInfo(
    code: 'EXIM',
    shortName: 'Eximbank',
    fullName: 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam',
    color: Color(0xFF003DA5),
  ),
  _BankInfo(
    code: 'KLB',
    shortName: 'KienlongBank',
    fullName: 'Ngân hàng TMCP Kiên Long',
    color: Color(0xFF00A651),
  ),
];

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.wallet});
  final WalletInfo wallet;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  _BankInfo? _selectedBank;
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
    _accountCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final bank = await showModalBottomSheet<_BankInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BankPickerSheet(),
    );
    if (bank != null && mounted) {
      setState(() => _selectedBank = bank);
    }
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
    if (_selectedBank == null ||
        _accountCtrl.text.trim().isEmpty ||
        _holderCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập đầy đủ thông tin ngân hàng');
      return;
    }
    setState(() => _submitting = true);
    try {
      final msg = await WalletService.instance.requestWithdrawal(
        amount: amount,
        bankName: _selectedBank!.displayName,
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
    final bank = _selectedBank;
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
          InkWell(
            onTap: _pickBank,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _dec('Ngân hàng', Icons.account_balance_outlined)
                  .copyWith(
                suffixIcon: const Icon(Icons.keyboard_arrow_down),
              ),
              child: Text(
                bank?.displayName ?? 'Chọn ngân hàng',
                style: TextStyle(
                  fontSize: 16,
                  color: bank == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
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

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet();

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_BankInfo> get _filtered {
    final q = _normalize(_query);
    if (q.isEmpty) return _kBanks;
    return _kBanks.where((b) {
      return _normalize(b.shortName).contains(q) ||
          _normalize(b.fullName).contains(q) ||
          _normalize(b.code).contains(q) ||
          _normalize(b.displayName).contains(q);
    }).toList();
  }

  String _normalize(String s) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final banks = _filtered;
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Chọn ngân hàng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B4C),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên ngân hàng',
                suffixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: banks.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy ngân hàng',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: banks.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final b = banks[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: b.color,
                          child: Text(
                            b.code.length <= 3
                                ? b.code
                                : b.code.substring(0, 3),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        title: Text(
                          b.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D1B4C),
                          ),
                        ),
                        subtitle: Text(
                          b.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, b),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
