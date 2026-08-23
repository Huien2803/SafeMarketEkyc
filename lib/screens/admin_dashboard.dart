import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/marketplace_home.dart';
import 'package:safemarket_app/services/admin_service.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:printing/printing.dart';
import 'package:safemarket_app/utils/admin_report_pdf.dart';
import 'package:safemarket_app/widgets/trust_score_bar.dart';

/// Màn hình SafeAdmin — dashboard quản trị Web/Tablet responsive.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedMenu = 0;
  AdminStats? _stats;
  List<AdminUserRow> _users = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _pendingEkyc = [];
  List<Map<String, dynamic>> _lockedUsers = [];
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _withdrawals = [];
  List<AdminRankRow> _ranking = [];
  bool _rankingDesc = true;
  bool _rankingLoading = false;
  bool _loading = true;
  String? _loadError;
  String _searchQuery = '';

  static const _menuItems = [
    _MenuItem('Tổng quan', Icons.dashboard_outlined),
    _MenuItem('Người dùng', Icons.people_outline),
    _MenuItem('Xếp hạng tín nhiệm', Icons.leaderboard_outlined),
    _MenuItem('Phê duyệt eKYC', Icons.verified_user_outlined),
    _MenuItem('Báo cáo vi phạm', Icons.report_outlined),
    _MenuItem('Khiếu nại đơn', Icons.gavel_outlined),
    _MenuItem('Duyệt rút tiền', Icons.account_balance_wallet_outlined),
    _MenuItem('Danh sách đen', Icons.block_outlined),
    _MenuItem('Báo cáo hệ thống', Icons.analytics_outlined),
  ];

  @override
  void initState() {
    super.initState();
    if (!(AuthService.instance.currentUser?.isAdmin ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chỉ tài khoản admin mới truy cập được')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }
    _load();
  }

  List<AdminUserRow> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final name = (u.displayName ?? '').toLowerCase();
      final email = u.email.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        AdminService.instance.getStats(),
        AdminService.instance.getUsers(),
        AdminService.instance.getReports(),
        AdminService.instance.getPendingEkyc(),
        AdminService.instance.getLockedUsers(),
        AdminService.instance.getUserRanking(descending: _rankingDesc),
        AdminService.instance.getDisputes(),
        AdminService.instance.getWithdrawals(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _users = results[1] as List<AdminUserRow>;
        _reports = results[2] as List<Map<String, dynamic>>;
        _pendingEkyc = results[3] as List<Map<String, dynamic>>;
        _lockedUsers = results[4] as List<Map<String, dynamic>>;
        _ranking = results[5] as List<AdminRankRow>;
        _disputes = results[6] as List<Map<String, dynamic>>;
        _withdrawals = results[7] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // Thử tải từng phần nếu stats lỗi — vẫn hiển thị user/báo cáo
      try {
        final users = await AdminService.instance.getUsers();
        final reports = await AdminService.instance.getReports();
        final pending = await AdminService.instance.getPendingEkyc();
        final locked = await AdminService.instance.getLockedUsers();
        final ranking =
            await AdminService.instance.getUserRanking(descending: _rankingDesc);
        final disputes = await AdminService.instance.getDisputes();
        final withdrawals = await AdminService.instance.getWithdrawals();
        if (!mounted) return;
        setState(() {
          _users = users;
          _reports = reports;
          _pendingEkyc = pending;
          _lockedUsers = locked;
          _ranking = ranking;
          _disputes = disputes;
          _withdrawals = withdrawals;
          _loadError = '$e';
        });
      } catch (_) {
        setState(() => _loadError = '$e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được dữ liệu admin: $e')),
      );
    }
  }

  Future<void> _setRankingOrder(bool descending) async {
    if (_rankingLoading || descending == _rankingDesc) return;
    setState(() {
      _rankingDesc = descending;
      _rankingLoading = true;
    });
    try {
      final ranking =
          await AdminService.instance.getUserRanking(descending: descending);
      if (!mounted) return;
      setState(() {
        _ranking = ranking;
        _rankingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _rankingLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được bảng xếp hạng: $e')),
      );
    }
  }

  Future<void> _exportReport() async {
    if (!mounted) return;

    if (_stats == null) {
      await _load();
      if (!mounted) return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang tạo báo cáo PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bytes = await AdminReportPdf.buildDashboardReport(
        stats: _stats,
        users: _users,
        reports: _reports,
        pendingEkyc: _pendingEkyc,
        lockedUsers: _lockedUsers,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final fileName = AdminReportPdf.fileName();
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xuất $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không xuất được PDF: $e')),
      );
    }
  }

  void _goToApp() {
    // Luôn về trang chủ Marketplace và xoá toàn bộ stack admin, tránh trường
    // hợp Drawer (mobile) thêm local history entry khiến canPop()=true (khi đó
    // pop() chỉ đóng Drawer chứ không rời màn admin).
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MarketplaceHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _AdminSidebar(
                selectedIndex: _selectedMenu,
                items: _menuItems,
                onSelect: (i) => setState(() => _selectedMenu = i),
                onBackToApp: _goToApp,
              ),
            Expanded(
              child: Column(
                children: [
                  _AdminHeader(
                    showMenuButton: !isWide,
                    searchQuery: _searchQuery,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onRefresh: _load,
                    onBackToApp: _goToApp,
                  ),
                  if (_loadError != null)
                    MaterialBanner(
                      content: Text(_loadError!),
                      actions: [
                        TextButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 24 : 16,
                          16,
                          isWide ? 24 : 16,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PageTitleRow(
                              menuIndex: _selectedMenu,
                              onExport: _exportReport,
                              onRefresh: _load,
                            ),
                            const SizedBox(height: 16),
                            _buildMenuContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: _AdminSidebar(
                  selectedIndex: _selectedMenu,
                  items: _menuItems,
                  onSelect: (i) {
                    setState(() => _selectedMenu = i);
                    Navigator.pop(context);
                  },
                  onBackToApp: () {
                    Navigator.pop(context);
                    _goToApp();
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildMenuContent() {
    switch (_selectedMenu) {
      case 1:
        return _UsersTableCard(
          users: _filteredUsers,
          loading: _loading,
          onWarn: _warnUser,
          onLock: _lockUser,
          onSuspend: _suspendUser,
          onUnlock: _unlockUser,
          onBan: _banUser,
          onPunish: _punishUser,
          onDelete: _deleteUser,
        );
      case 2:
        return _RankingCard(
          ranking: _ranking,
          descending: _rankingDesc,
          loading: _loading || _rankingLoading,
          onOrderChanged: _setRankingOrder,
        );
      case 3:
        return _PendingEkycCard(
          items: _pendingEkyc,
          loading: _loading,
          onApprove: _approveEkyc,
          onReject: _rejectEkyc,
        );
      case 4:
        return _ReportsManageCard(
          reports: _reports,
          loading: _loading,
          onResolve: _resolveReport,
          onHideProduct: _hideReportedProduct,
          onLockUser: _lockUserById,
          onPunishUser: _punishUserById,
        );
      case 5:
        return _DisputesManageCard(
          disputes: _disputes,
          loading: _loading,
          onResolve: _resolveDispute,
        );
      case 6:
        return _WithdrawalsManageCard(
          withdrawals: _withdrawals,
          loading: _loading,
          onApprove: _approveWithdrawal,
          onReject: _rejectWithdrawal,
        );
      case 7:
        return _LockedUsersCard(
          users: _lockedUsers,
          loading: _loading,
          onUnlock: _unlockUser,
        );
      case 8:
        return _SystemReportCard(stats: _stats);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsCardsRow(stats: _stats, loading: _loading),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _EkycChartCard(trend: _stats?.ekycTrend ?? []),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _RecentReportsCard(reports: _reports)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _EkycChartCard(trend: _stats?.ekycTrend ?? []),
                    const SizedBox(height: 16),
                    _RecentReportsCard(reports: _reports),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _UsersTableCard(
              users: _filteredUsers,
              loading: _loading,
              onWarn: _warnUser,
              onLock: _lockUser,
              onSuspend: _suspendUser,
              onUnlock: _unlockUser,
              onBan: _banUser,
              onPunish: _punishUser,
              onDelete: _deleteUser,
            ),
          ],
        );
    }
  }

  Future<void> _approveEkyc(int userId) async {
    try {
      await AdminService.instance.approveEkyc(userId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _rejectEkyc(int userId) async {
    try {
      await AdminService.instance.rejectEkyc(userId, 'Không đạt yêu cầu xác minh');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    // Dispose sau frame để tránh lỗi controller khi dialog đang đóng.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    return result;
  }

  Future<void> _lockUser(AdminUserRow user) async {
    final reason = await _promptText(
      title: 'Khóa tài khoản',
      hint: 'Lý do khóa...',
      initial: 'Vi phạm quy định',
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await AdminService.instance.lockUser(user.userId, reason: reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã khóa ${user.displayName ?? user.email}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _banUser(AdminUserRow user) async {
    final reason = await _promptText(
      title: 'Cấm vĩnh viễn',
      hint: 'Lý do cấm...',
      initial: 'Cấm vĩnh viễn',
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận cấm'),
        content: Text(
          'Cấm vĩnh viễn ${user.displayName ?? user.email}?\nLý do: $reason',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cấm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AdminService.instance.banUser(user.userId, reason: reason);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _punishUser(AdminUserRow user) async {
    final pointsStr = await _promptText(
      title: 'Trừ điểm tín nhiệm',
      hint: 'Số điểm trừ (1–500)...',
      initial: '50',
    );
    if (pointsStr == null || !mounted) return;
    final points = int.tryParse(pointsStr);
    if (points == null || points < 1 || points > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số điểm trừ phải từ 1 đến 500')),
      );
      return;
    }
    final reason = await _promptText(
      title: 'Lý do trừ điểm',
      hint: 'Mô tả vi phạm...',
      initial: 'Vi phạm quy định',
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await AdminService.instance.punishUser(
        user.userId,
        points: points,
        reason: reason,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã trừ $points điểm — ${user.displayName ?? user.email}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _warnUser(AdminUserRow user) async {
    final reason = await _promptText(
      title: 'Cảnh cáo người dùng',
      hint: 'Nội dung cảnh cáo...',
      initial: 'Vi phạm quy định cộng đồng',
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await AdminService.instance.warnUser(user.userId, reason: reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi cảnh cáo tới ${user.displayName ?? user.email}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _suspendUser(AdminUserRow user) async {
    final result = await _promptSuspend(user);
    if (result == null || !mounted) return;
    try {
      await AdminService.instance.suspendUser(
        user.userId,
        days: result.days,
        reason: result.reason,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã đình chỉ ${user.displayName ?? user.email} trong ${result.days} ngày',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<_SuspendResult?> _promptSuspend(AdminUserRow user) async {
    final reasonCtrl = TextEditingController(text: 'Vi phạm quy định');
    int days = 7;
    const options = [3, 7, 14, 30];
    final result = await showDialog<_SuspendResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Đình chỉ tạm thời'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản ${user.displayName ?? user.email} sẽ bị khóa và tự mở lại khi hết hạn.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text('Thời hạn', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: options
                    .map(
                      (d) => ChoiceChip(
                        label: Text('$d ngày'),
                        selected: days == d,
                        onSelected: (_) => setLocal(() => days = d),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lý do đình chỉ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(ctx, _SuspendResult(days: days, reason: reason));
              },
              child: const Text('Đình chỉ'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    return result;
  }

  Future<void> _deleteUser(AdminUserRow user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: Text(
          'Xóa tài khoản ${user.displayName ?? user.email}?\n\n'
          'Nếu người dùng đã có sản phẩm hoặc đơn hàng, hệ thống sẽ '
          'ẩn danh tài khoản và ẩn toàn bộ sản phẩm (giữ lại lịch sử giao dịch '
          'để đối soát). Nếu chưa phát sinh dữ liệu, tài khoản sẽ bị xóa hoàn toàn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final mode = await AdminService.instance.deleteUser(user.userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode == 'soft'
                  ? 'Đã xóa tài khoản (ẩn danh, không đăng nhập được; giữ lịch sử nếu có)'
                  : 'Đã xóa tài khoản hoàn toàn',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _unlockUser(int userId) async {
    try {
      await AdminService.instance.unlockUser(userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã mở khóa tài khoản')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _resolveDispute(
    int orderId,
    String decision, {
    String? note,
    int penaltyPoints = 50,
    bool skipPenalty = false,
  }) async {
    try {
      await AdminService.instance.resolveDispute(
        orderId,
        decision: decision,
        note: note,
        penaltyPoints: penaltyPoints,
        skipPenalty: skipPenalty,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'REFUND_BUYER'
                  ? 'Đã hoàn tiền người mua — đơn #$orderId'
                  : 'Đã giải ngân người bán — đơn #$orderId',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _approveWithdrawal(int id) async {
    try {
      await AdminService.instance.approveWithdrawal(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã duyệt lệnh rút tiền')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _rejectWithdrawal(int id) async {
    final note = await _promptText(
      title: 'Từ chối rút tiền',
      hint: 'Lý do từ chối...',
      initial: 'Thông tin ngân hàng không hợp lệ',
    );
    if (note == null || note.isEmpty || !mounted) return;
    try {
      await AdminService.instance.rejectWithdrawal(id, note: note);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối — tiền hoàn về ví')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _resolveReport(int reportId) async {
    try {
      await AdminService.instance.resolveReport(reportId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _hideReportedProduct(int productId) async {
    try {
      await AdminService.instance.hideProduct(productId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ẩn sản phẩm vi phạm')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _lockUserById(int userId, String name) async {
    final reason = await _promptText(
      title: 'Khóa người bị báo cáo',
      hint: 'Lý do khóa...',
      initial: 'Vi phạm quy định — báo cáo từ cộng đồng',
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await AdminService.instance.lockUser(userId, reason: reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã khóa $name')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _punishUserById(int userId, String name) async {
    AdminUserRow user;
    try {
      user = _users.firstWhere((u) => u.userId == userId);
    } catch (_) {
      user = AdminUserRow(
        userId: userId,
        email: name,
        displayName: name,
        kycStatus: 'Unverified',
        accountStatus: 'Active',
        trustScore: 500,
        rankLevel: 'Silver',
      );
    }
    await _punishUser(user);
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Sidebar trái — logo SafeAdmin + menu.
class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onBackToApp,
  });

  final int selectedIndex;
  final List<_MenuItem> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onBackToApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SafeAdmin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onSelect(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? AppColors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onBackToApp,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Về SafeMarket'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header: tìm kiếm + thông báo + avatar admin.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.showMenuButton,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onBackToApp,
  });

  final bool showMenuButton;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onBackToApp;

  @override
  Widget build(BuildContext context) {
    final admin = AuthService.instance.currentUser;
    final adminName = admin?.displayName ?? admin?.email ?? 'Admin';
    final initials = adminName.trim().isNotEmpty
        ? adminName.trim().substring(0, 1).toUpperCase()
        : 'A';

    // showMenuButton == true nghĩa là màn hình hẹp (mobile). Khi đó ẩn bớt
    // các thành phần phụ (tên admin, chuông thông báo) để tránh tràn ngang.
    final narrow = showMenuButton;

    return Material(
      color: AppColors.white,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(narrow ? 4 : 20, 8, narrow ? 8 : 20, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            if (narrow)
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Về SafeMarket',
                onPressed: onBackToApp,
              ),
            Expanded(
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: narrow
                      ? 'Tìm người dùng...'
                      : 'Tìm kiếm người dùng theo tên hoặc email...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              onPressed: onRefresh,
            ),
            if (!narrow) ...[
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    adminName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'HỆ THỐNG SAFEMARKET',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            CircleAvatar(
              radius: narrow ? 16 : 18,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTitleRow extends StatelessWidget {
  const _PageTitleRow({
    required this.menuIndex,
    required this.onExport,
    required this.onRefresh,
  });
  final int menuIndex;
  final VoidCallback onExport;
  final VoidCallback onRefresh;

  String get _title {
    switch (menuIndex) {
      case 1:
        return 'Quản lý người dùng';
      case 2:
        return 'Xếp hạng tín nhiệm';
      case 3:
        return 'Phê duyệt eKYC';
      case 4:
        return 'Báo cáo vi phạm';
      case 5:
        return 'Khiếu nại đơn hàng';
      case 6:
        return 'Duyệt rút tiền';
      case 7:
        return 'Danh sách đen';
      case 8:
        return 'Báo cáo hệ thống';
      default:
        return 'Tổng quan hệ thống';
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: TextStyle(
            fontSize: narrow ? 22 : 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          narrow
              ? 'Quản trị SafeMarket — thao tác bên dưới.'
              : 'Chào mừng trở lại, đây là những gì đang diễn ra hôm nay.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    final exportBtn = ElevatedButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(narrow ? 'PDF' : 'Xuất PDF'),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? 14 : 20,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: exportBtn),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Làm mới dữ liệu',
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            exportBtn,
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới dữ liệu',
            ),
          ],
        );
      },
    );
  }
}

/// 4 thẻ thống kê trên cùng.
class _StatsCardsRow extends StatelessWidget {
  const _StatsCardsRow({this.stats, this.loading = false});

  final AdminStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = stats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;

        final cards = [
          _StatCardData(
            title: 'Tổng người dùng',
            value: '${s?.totalUsers ?? 0}',
            icon: Icons.people,
            iconColor: AppColors.primary,
            change: 'Live',
            changePositive: true,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Đã định danh eKYC',
            value: '${s?.verifiedUsers ?? 0}',
            icon: Icons.shield,
            iconColor: AppColors.primary,
            change: 'Verified',
            changePositive: true,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'eKYC chờ duyệt',
            value: '${s?.pendingEkyc ?? 0}',
            icon: Icons.pending_actions,
            iconColor: AppColors.warning,
            change: 'Pending',
            changePositive: false,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Báo cáo vi phạm',
            value: '${s?.openReports ?? 0}',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            change: 'Open',
            changePositive: false,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Tài khoản bị khóa',
            value: '${s?.lockedUsers ?? 0}',
            icon: Icons.person_off_outlined,
            iconColor: AppColors.danger,
            change: 'Locked',
            changePositive: false,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Giao dịch hoàn tất',
            value: '${s?.completedOrders ?? 0}',
            icon: Icons.check_circle_outline,
            iconColor: AppColors.trustGreen,
            change: '${s?.totalOrders ?? 0} đơn',
            changePositive: true,
            isNeutralChange: true,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            // Chiều cao cố định để nội dung không bị tràn đáy trên mọi bề rộng.
            mainAxisExtent: 150,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => _StatCard(data: cards[index]),
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.change,
    required this.changePositive,
    this.isNeutralChange = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String change;
  final bool changePositive;
  final bool isNeutralChange;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final changeColor = data.isNeutralChange
        ? AppColors.textSecondary
        : data.changePositive
            ? AppColors.trustGreen
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 24),
              ),
              Text(
                data.change,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột eKYC — CustomPainter không dùng thư viện ngoài.
class _EkycChartCard extends StatelessWidget {
  const _EkycChartCard({required this.trend});

  final List<EkycTrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final points = trend.isNotEmpty
        ? trend
        : const [
            EkycTrendPoint(label: 'T2', count: 0),
            EkycTrendPoint(label: 'T3', count: 0),
            EkycTrendPoint(label: 'T4', count: 0),
            EkycTrendPoint(label: 'T5', count: 0),
            EkycTrendPoint(label: 'T6', count: 0),
            EkycTrendPoint(label: 'T7', count: 0),
            EkycTrendPoint(label: 'CN', count: 0),
          ];
    final maxCount = points.map((p) => p.count).fold(0, (a, b) => a > b ? a : b);
    final scale = maxCount > 0 ? maxCount.toDouble() : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'eKYC được duyệt (7 ngày)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tổng: ${points.fold<int>(0, (s, p) => s + p.count)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(points.length, (i) {
                final p = points[i];
                final heightFactor = p.count / scale;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (p.count > 0)
                          Text(
                            '${p.count}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor.clamp(0.05, 1.0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Danh sách báo cáo vi phạm mới nhất.
class _RecentReportsCard extends StatelessWidget {
  const _RecentReportsCard({required this.reports});

  final List<Map<String, dynamic>> reports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Báo cáo mới nhất',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Text('Không có báo cáo mở', style: TextStyle(color: AppColors.textMuted))
          else
            ...reports.take(5).map((r) {
              final severity = r['severity'] as String? ?? 'medium';
              final color = severity == 'high'
                  ? Colors.red
                  : severity == 'low'
                      ? Colors.green
                      : Colors.orange;
              return _ReportRow(
                item: _ReportItem(
                  r['name'] as String? ?? 'User',
                  r['reason'] as String? ?? '',
                  (r['score'] as num?)?.toInt() ?? 0,
                  color,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReportItem {
  const _ReportItem(this.name, this.reason, this.score, this.barColor);
  final String name;
  final String reason;
  final int score;
  final Color barColor;
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.item});

  final _ReportItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: item.barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.score} điểm',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng quản lý người dùng gần đây.
class _UsersTableCard extends StatelessWidget {
  const _UsersTableCard({
    required this.users,
    this.loading = false,
    this.onWarn,
    this.onLock,
    this.onSuspend,
    this.onUnlock,
    this.onBan,
    this.onPunish,
    this.onDelete,
  });

  final List<AdminUserRow> users;
  final bool loading;
  final void Function(AdminUserRow user)? onWarn;
  final void Function(AdminUserRow user)? onLock;
  final void Function(AdminUserRow user)? onSuspend;
  final void Function(int userId)? onUnlock;
  final void Function(AdminUserRow user)? onBan;
  final void Function(AdminUserRow user)? onPunish;
  final void Function(AdminUserRow user)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final narrow = MediaQuery.sizeOf(context).width < 700;

    return Container(
      padding: EdgeInsets.all(narrow ? 14 : 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quản lý người dùng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${users.length} tài khoản',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn “Thao tác quản trị” trên từng tài khoản để cảnh cáo, trừ điểm, khóa, cấm hoặc xóa.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          if (narrow)
            ...users.map(
              (u) => _UserMobileTile(
                user: u,
                onWarn: onWarn,
                onLock: onLock,
                onSuspend: onSuspend,
                onUnlock: onUnlock,
                onBan: onBan,
                onPunish: onPunish,
                onDelete: onDelete,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
                columns: const [
                  DataColumn(label: Text('NGƯỜI DÙNG')),
                  DataColumn(label: Text('TRẠNG THÁI')),
                  DataColumn(label: Text('TRẠNG THÁI EKYC')),
                  DataColumn(label: Text('ĐIỂM TÍN NHIỆM')),
                  DataColumn(label: Text('GIAO DỊCH')),
                  DataColumn(label: Text('HÀNH ĐỘNG')),
                ],
                rows: users
                    .map(
                      (u) => DataRow(
                        cells: [
                          DataCell(_UserCellApi(user: u)),
                          DataCell(_AccountStatusBadge(
                            status: u.accountStatus,
                            lockedUntil: u.lockedUntil,
                          )),
                          DataCell(_EkycBadge(
                              verified: u.kycStatus == 'Verified')),
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: TrustScoreBar(score: u.trustScore),
                            ),
                          ),
                          DataCell(Text('${u.orders}')),
                          DataCell(
                            _UserActionsMenu(
                              user: u,
                              onWarn: onWarn,
                              onLock: onLock,
                              onSuspend: onSuspend,
                              onUnlock: onUnlock,
                              onBan: onBan,
                              onPunish: onPunish,
                              onDelete: onDelete,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ người dùng trên mobile — nút Xóa hiện rõ.
class _UserMobileTile extends StatelessWidget {
  const _UserMobileTile({
    required this.user,
    this.onWarn,
    this.onLock,
    this.onSuspend,
    this.onUnlock,
    this.onBan,
    this.onPunish,
    this.onDelete,
  });

  final AdminUserRow user;
  final void Function(AdminUserRow user)? onWarn;
  final void Function(AdminUserRow user)? onLock;
  final void Function(AdminUserRow user)? onSuspend;
  final void Function(int userId)? onUnlock;
  final void Function(AdminUserRow user)? onBan;
  final void Function(AdminUserRow user)? onPunish;
  final void Function(AdminUserRow user)? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.email;
    final isDeleted = user.accountStatus == 'Deleted';
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AccountStatusBadge(
                status: user.accountStatus,
                lockedUntil: user.lockedUntil,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _EkycBadge(verified: user.kycStatus == 'Verified'),
              const SizedBox(width: 8),
              Expanded(
                child: TrustScoreBar(score: user.trustScore),
              ),
            ],
          ),
          if (!isDeleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _UserActionsMenu(
                user: user,
                showAsButton: true,
                onWarn: onWarn,
                onLock: onLock,
                onSuspend: onSuspend,
                onUnlock: onUnlock,
                onBan: onBan,
                onPunish: onPunish,
                onDelete: onDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserCellApi extends StatelessWidget {
  const _UserCellApi({required this.user});

  final AdminUserRow user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.email;
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFBFDBFE),
          radius: 18,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(user.email,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _SuspendResult {
  const _SuspendResult({required this.days, required this.reason});
  final int days;
  final String reason;
}

class _AccountStatusBadge extends StatelessWidget {
  const _AccountStatusBadge({required this.status, this.lockedUntil});

  final String status;
  final DateTime? lockedUntil;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    final isBanned = status == 'Banned';
    final isDeleted = status == 'Deleted';
    final isSuspended = status == 'Locked' && lockedUntil != null;

    final Color color;
    final String label;
    if (isActive) {
      color = AppColors.trustGreen;
      label = 'HOẠT ĐỘNG';
    } else if (isBanned) {
      color = AppColors.danger;
      label = 'BỊ CẤM';
    } else if (isDeleted) {
      color = AppColors.textMuted;
      label = 'ĐÃ XÓA';
    } else if (isSuspended) {
      color = AppColors.warning;
      label = 'ĐÌNH CHỈ';
    } else {
      color = AppColors.warning;
      label = 'BỊ KHÓA';
    }

    final until = lockedUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (isSuspended && until != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'đến ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}',
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _UserActionsMenu extends StatelessWidget {
  const _UserActionsMenu({
    required this.user,
    this.showAsButton = false,
    this.onWarn,
    this.onLock,
    this.onSuspend,
    this.onUnlock,
    this.onBan,
    this.onPunish,
    this.onDelete,
  });

  final AdminUserRow user;
  final bool showAsButton;
  final void Function(AdminUserRow user)? onWarn;
  final void Function(AdminUserRow user)? onLock;
  final void Function(AdminUserRow user)? onSuspend;
  final void Function(int userId)? onUnlock;
  final void Function(AdminUserRow user)? onBan;
  final void Function(AdminUserRow user)? onPunish;
  final void Function(AdminUserRow user)? onDelete;

  /// Chạy sau khi đóng menu/sheet — tránh lỗi “deactivated context” / trang trắng.
  void _runAfterClose(VoidCallback? action) {
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
  }

  Future<void> _openActions(BuildContext context) async {
    final isActive = user.accountStatus == 'Active';
    final name = user.displayName ?? user.email;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        Widget actionTile({
          required IconData icon,
          required Color color,
          required String title,
          String? subtitle,
          required VoidCallback onTap,
        }) {
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: const TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.pop(sheetCtx);
              _runAfterClose(onTap);
            },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thao tác quản trị',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (isActive && onWarn != null)
                    actionTile(
                      icon: Icons.campaign_outlined,
                      color: AppColors.warning,
                      title: 'Cảnh cáo',
                      subtitle: 'Gửi cảnh báo, không trừ điểm',
                      onTap: () => onWarn!(user),
                    ),
                  if (isActive && onPunish != null)
                    actionTile(
                      icon: Icons.remove_circle_outline,
                      color: AppColors.textPrimary,
                      title: 'Trừ điểm tín nhiệm',
                      onTap: () => onPunish!(user),
                    ),
                  if (isActive && onSuspend != null)
                    actionTile(
                      icon: Icons.timer_outlined,
                      color: AppColors.warning,
                      title: 'Đình chỉ tạm thời',
                      subtitle: 'Khóa có thời hạn, tự mở lại',
                      onTap: () => onSuspend!(user),
                    ),
                  if (isActive && onLock != null)
                    actionTile(
                      icon: Icons.block,
                      color: AppColors.textPrimary,
                      title: 'Khóa vô thời hạn',
                      onTap: () => onLock!(user),
                    ),
                  if (!isActive && onUnlock != null)
                    actionTile(
                      icon: Icons.lock_open_rounded,
                      color: AppColors.trustGreen,
                      title: 'Mở khóa',
                      onTap: () => onUnlock!(user.userId),
                    ),
                  if (onBan != null)
                    actionTile(
                      icon: Icons.gavel,
                      color: AppColors.danger,
                      title: 'Cấm vĩnh viễn',
                      onTap: () => onBan!(user),
                    ),
                  if (onDelete != null) ...[
                    const Divider(height: 1),
                    actionTile(
                      icon: Icons.delete_forever_rounded,
                      color: AppColors.danger,
                      title: 'Xóa tài khoản',
                      subtitle: 'Không thể hoàn tác dễ dàng',
                      onTap: () => onDelete!(user),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = user.accountStatus == 'Deleted';
    if (isDeleted) {
      return const SizedBox(
        width: 40,
        child: Text('—', textAlign: TextAlign.center),
      );
    }

    if (showAsButton) {
      return FilledButton.tonalIcon(
        onPressed: () => _openActions(context),
        icon: const Icon(Icons.manage_accounts_outlined, size: 20),
        label: const Text('Thao tác quản trị'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDelete != null)
          IconButton(
            tooltip: 'Xóa tài khoản',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 22,
            ),
            onPressed: () => _runAfterClose(() => onDelete!(user)),
          ),
        IconButton(
          tooltip: 'Thao tác quản trị',
          icon: const Icon(Icons.more_horiz_rounded, size: 22),
          onPressed: () => _openActions(context),
        ),
      ],
    );
  }
}

class _EkycBadge extends StatelessWidget {
  const _EkycBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: verified ? AppColors.ekycVerifiedBg : AppColors.ekycPendingBg,
        borderRadius: BorderRadius.circular(AppDecorations.radiusBadge),
      ),
      child: Text(
        verified ? 'ĐÃ XÁC THỰC' : 'CHỜ DUYỆT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color:
              verified ? AppColors.ekycVerifiedText : AppColors.ekycPendingText,
        ),
      ),
    );
  }
}

class _PendingEkycCard extends StatelessWidget {
  const _PendingEkycCard({
    required this.items,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  final List<Map<String, dynamic>> items;
  final bool loading;
  final void Function(int userId) onApprove;
  final void Function(int userId) onReject;

  static String _str(Map<String, dynamic> e, String key) =>
      (e[key] as String?)?.trim() ?? '';

  static String _fmtDob(String raw) {
    if (raw.isEmpty) return '';
    if (raw.length >= 10) {
      final ymd = raw.substring(0, 10).split('-');
      if (ymd.length == 3) return '${ymd[2]}/${ymd[1]}/${ymd[0]}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hồ sơ eKYC chờ duyệt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ekycPendingBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ekycPendingText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bấm ảnh để phóng to CCCD và ảnh nhận dạng khuôn mặt.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Không có hồ sơ chờ duyệt',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...items.map((e) {
              final userId = (e['userId'] as num).toInt();
              final hasProfile = e['hasProfile'] as bool? ?? true;
              final fullName = _str(e, 'fullName');
              final idNumber = _str(e, 'idNumber');
              final displayName = _str(e, 'displayName');
              final dob = _fmtDob(_str(e, 'dob'));
              final address = _str(e, 'address');
              final frontUrl = ApiConfig.mediaUrl(_str(e, 'idFrontUrl'));
              final backUrl = ApiConfig.mediaUrl(_str(e, 'idBackUrl'));
              final faceUrl = ApiConfig.mediaUrl(_str(e, 'faceUrl'));
              final faceMatchIsMatch = e['faceMatchIsMatch'] as bool?;
              final faceSimilarity = (e['faceSimilarity'] as num?)?.toDouble();
              final faceMatchMessage = _str(e, 'faceMatchMessage');
              final faceMismatch = faceMatchIsMatch == false;
              final hasImages = frontUrl.isNotEmpty ||
                  backUrl.isNotEmpty ||
                  faceUrl.isNotEmpty;
              final initial = displayName.isNotEmpty
                  ? displayName.substring(0, 1).toUpperCase()
                  : '?';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: faceMismatch
                        ? AppColors.danger
                        : const Color(0xFFE5E7EB),
                    width: faceMismatch ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isNotEmpty ? fullName : displayName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (idNumber.isNotEmpty) 'CCCD $idNumber',
                                  if (dob.isNotEmpty) 'NS $dob',
                                  if (!hasProfile) 'Chưa có file CCCD',
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: faceMismatch
                              ? 'Không duyệt — khuôn mặt không khớp CCCD'
                              : 'Duyệt',
                          icon: Icon(
                            Icons.check_circle_rounded,
                            color: faceMismatch
                                ? AppColors.textMuted
                                : AppColors.trustGreen,
                          ),
                          onPressed:
                              faceMismatch ? null : () => onApprove(userId),
                        ),
                        IconButton(
                          tooltip: 'Từ chối',
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.danger,
                          ),
                          onPressed: () => onReject(userId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (faceMatchIsMatch != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: faceMismatch
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          faceMismatch
                              ? 'KHÔNG KHỚP CCCD — ${(faceSimilarity != null ? '${(faceSimilarity * 100).toStringAsFixed(0)}%' : 'thấp')}'
                                  '${faceMatchMessage.isNotEmpty ? '\n$faceMatchMessage' : ''}'
                              : 'Khớp CCCD — ${((faceSimilarity ?? 0) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: faceMismatch
                                ? AppColors.danger
                                : AppColors.trustGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _EkycEvidenceThumb(
                            label: 'CCCD mặt trước',
                            url: frontUrl,
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _EkycEvidenceThumb(
                            label: 'CCCD mặt sau',
                            url: backUrl,
                            icon: Icons.credit_card_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _EkycEvidenceThumb(
                            label: 'Khuôn mặt',
                            url: faceUrl,
                            icon: Icons.face_retouching_natural_outlined,
                          ),
                        ),
                      ],
                    ),
                    if (hasImages)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openReviewSheet(
                            context,
                            fullName: fullName.isNotEmpty
                                ? fullName
                                : displayName,
                            idNumber: idNumber,
                            dob: dob,
                            address: address,
                            frontUrl: frontUrl,
                            backUrl: backUrl,
                            faceUrl: faceUrl,
                          ),
                          icon: const Icon(Icons.zoom_in, size: 18),
                          label: const Text('Xem lớn CCCD & khuôn mặt'),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static Future<void> _openReviewSheet(
    BuildContext context, {
    required String fullName,
    required String idNumber,
    required String dob,
    required String address,
    required String frontUrl,
    required String backUrl,
    required String faceUrl,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fullName.isEmpty ? 'Hồ sơ eKYC' : fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    [
                      if (idNumber.isNotEmpty) 'CCCD: $idNumber',
                      if (dob.isNotEmpty) 'Ngày sinh: $dob',
                      if (address.isNotEmpty) address,
                    ].join('\n'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 640;
                        final images = [
                          _EkycLargeImage(
                            label: 'CCCD mặt trước',
                            url: frontUrl,
                          ),
                          _EkycLargeImage(
                            label: 'CCCD mặt sau',
                            url: backUrl,
                          ),
                          _EkycLargeImage(
                            label: 'Ảnh nhận dạng khuôn mặt',
                            url: faceUrl,
                          ),
                        ];
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < images.length; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(child: images[i]),
                              ],
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (var i = 0; i < images.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              images[i],
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EkycEvidenceThumb extends StatelessWidget {
  const _EkycEvidenceThumb({
    required this.label,
    required this.url,
    required this.icon,
  });

  final String label;
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () => _showEkycImageViewer(context, title: label, url: url),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: const Color(0xFFE8EEF7),
                child: url.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: AppColors.textMuted),
                          const SizedBox(height: 4),
                          const Text(
                            'Chưa có ảnh',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          icon,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EkycLargeImage extends StatelessWidget {
  const _EkycLargeImage({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: url.isEmpty
              ? null
              : () => _showEkycImageViewer(context, title: label, url: url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFFE8EEF7),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: url.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có ảnh',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: AppColors.textMuted),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _showEkycImageViewer(
  BuildContext context, {
  required String title,
  required String url,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Không tải được ảnh',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportsManageCard extends StatelessWidget {
  const _ReportsManageCard({
    required this.reports,
    required this.loading,
    required this.onResolve,
    this.onHideProduct,
    this.onLockUser,
    this.onPunishUser,
  });

  final List<Map<String, dynamic>> reports;
  final bool loading;
  final void Function(int reportId) onResolve;
  final void Function(int productId)? onHideProduct;
  final void Function(int userId, String name)? onLockUser;
  final void Function(int userId, String name)? onPunishUser;

  @override
  Widget build(BuildContext context) {
    if (loading && reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kiểm duyệt báo cáo vi phạm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Báo cáo sản phẩm hoặc người dùng có ý đồ xấu từ cộng đồng.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Text('Không có báo cáo mở')
          else
            ...reports.map((r) {
              final id = (r['reportId'] as num).toInt();
              final reportedUserId = (r['reportedUserId'] as num?)?.toInt();
              final productId = (r['productId'] as num?)?.toInt();
              final productTitle = r['productTitle'] as String?;
              final reportType = r['reportType'] as String? ?? 'user';
              final severity = r['severity'] as String? ?? 'medium';
              final name = r['name'] as String? ?? 'User';
              final reporterName = r['reporterName'] as String? ?? '';
              final isProduct = reportType == 'product' && productId != null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isProduct
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isProduct ? 'SẢN PHẨM' : 'NGƯỜI DÙNG',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isProduct
                                    ? AppColors.warning
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: severity == 'high'
                                  ? AppColors.danger.withValues(alpha: 0.12)
                                  : AppColors.textMuted.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              severity.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: severity == 'high'
                                    ? AppColors.danger
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (isProduct && productTitle != null)
                        Text(
                          'SP: $productTitle',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (reporterName.isNotEmpty)
                        Text(
                          'Báo cáo bởi: $reporterName',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        r['reason'] as String? ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isProduct && onHideProduct != null)
                            OutlinedButton.icon(
                              onPressed: () => onHideProduct!(productId!),
                              icon: const Icon(Icons.visibility_off, size: 16),
                              label: const Text('Ẩn SP'),
                            ),
                          if (reportedUserId != null && onLockUser != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  onLockUser!(reportedUserId, name),
                              icon: const Icon(Icons.block, size: 16),
                              label: const Text('Khóa user'),
                            ),
                          if (reportedUserId != null && onPunishUser != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  onPunishUser!(reportedUserId, name),
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 16),
                              label: const Text('Trừ điểm'),
                            ),
                          FilledButton(
                            onPressed: () => onResolve(id),
                            child: const Text('Đã xử lý'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DisputesManageCard extends StatelessWidget {
  const _DisputesManageCard({
    required this.disputes,
    required this.loading,
    required this.onResolve,
  });

  final List<Map<String, dynamic>> disputes;
  final bool loading;
  final Future<void> Function(
    int orderId,
    String decision, {
    String? note,
    int penaltyPoints,
    bool skipPenalty,
  }) onResolve;

  @override
  Widget build(BuildContext context) {
    if (loading && disputes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khiếu nại đơn hàng chờ xử lý',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hoàn tiền người mua = hủy đơn + hoàn escrow + trừ điểm người bán.\n'
            'Giải ngân người bán = hoàn tất đơn + cộng ví + trừ điểm người mua.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (disputes.isEmpty)
            const Text('Không có khiếu nại đang mở')
          else
            ...disputes.map((d) {
              final orderId = (d['orderId'] as num).toInt();
              final type = d['disputeType'] as String? ?? '';
              final typeLabel = switch (type) {
                'NO_RECEIVE' => 'Không nhận hàng',
                'WRONG_DELIVERY' => 'Giao sai',
                _ => type.isEmpty ? 'Khiếu nại' : type,
              };
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đơn #$orderId · $typeLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['productTitle'] as String? ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Mua: ${d['buyerName']}  ·  Bán: ${d['sellerName']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if ((d['disputeNote'] as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Ghi chú: ${d['disputeNote']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      Text(
                        'Escrow: ${d['escrowStatus'] ?? '—'} · '
                        '${d['escrowAmount'] ?? 0}đ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => onResolve(
                              orderId,
                              'REFUND_BUYER',
                              note: 'Admin hoàn tiền người mua',
                            ),
                            child: const Text('Hoàn tiền người mua'),
                          ),
                          FilledButton(
                            onPressed: () => onResolve(
                              orderId,
                              'RELEASE_SELLER',
                              note: 'Admin giải ngân người bán',
                            ),
                            child: const Text('Giải ngân người bán'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WithdrawalsManageCard extends StatelessWidget {
  const _WithdrawalsManageCard({
    required this.withdrawals,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  final List<Map<String, dynamic>> withdrawals;
  final bool loading;
  final void Function(int id) onApprove;
  final void Function(int id) onReject;

  @override
  Widget build(BuildContext context) {
    if (loading && withdrawals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yêu cầu rút tiền chờ duyệt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Duyệt = đã chuyển khoản. Từ chối = hoàn tiền về ví người bán.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (withdrawals.isEmpty)
            const Text('Không có lệnh rút đang chờ')
          else
            ...withdrawals.map((w) {
              final id = (w['withdrawalId'] as num).toInt();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    '${w['displayName'] ?? ''} · ${w['amountFormatted'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${w['bankName']} · ${w['bankAccount']}\n'
                    'Chủ TK: ${w['accountHolder']}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Duyệt',
                        icon: const Icon(Icons.check_circle_outline,
                            color: AppColors.trustGreen),
                        onPressed: () => onApprove(id),
                      ),
                      IconButton(
                        tooltip: 'Từ chối',
                        icon: const Icon(Icons.cancel_outlined,
                            color: AppColors.danger),
                        onPressed: () => onReject(id),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LockedUsersCard extends StatelessWidget {
  const _LockedUsersCard({
    required this.users,
    required this.loading,
    required this.onUnlock,
  });

  final List<Map<String, dynamic>> users;
  final bool loading;
  final void Function(int userId) onUnlock;

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh sách đen / tài khoản khóa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (users.isEmpty)
            const Text('Không có tài khoản bị khóa')
          else
            ...users.map((u) {
              final id = (u['userId'] as num).toInt();
              final status = u['accountStatus'] as String? ?? 'Locked';
              final until = u['lockedUntil'] != null
                  ? DateTime.tryParse(u['lockedUntil'] as String)
                  : null;
              final statusLabel = status == 'Banned'
                  ? 'Bị cấm'
                  : until != null
                      ? 'Đình chỉ đến ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}'
                      : 'Bị khóa';
              return ListTile(
                title: Text(u['displayName'] as String? ?? ''),
                subtitle: Text('$statusLabel • ${u['lockReason'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open),
                  tooltip: 'Mở khóa',
                  onPressed: () => onUnlock(id),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Bảng xếp hạng người dùng theo điểm tín nhiệm.
/// eKYC đã xác thực xếp trên; chưa xác thực xếp chót. Có nút đảo chiều.
class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.ranking,
    required this.descending,
    required this.loading,
    required this.onOrderChanged,
  });

  final List<AdminRankRow> ranking;
  final bool descending;
  final bool loading;
  final ValueChanged<bool> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final verified = ranking.where((r) => r.verified).toList();
    final unverified = ranking.where((r) => !r.verified).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const title = Text(
                'Xếp hạng điểm tín nhiệm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              );
              final segmented = SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Cao → Thấp'),
                    icon: Icon(Icons.arrow_downward, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Thấp → Cao'),
                    icon: Icon(Icons.arrow_upward, size: 16),
                  ),
                ],
                selected: {descending},
                onSelectionChanged:
                    loading ? null : (s) => onOrderChanged(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                ),
              );

              // Màn hình hẹp: tiêu đề ở trên, bộ lọc thứ tự ở dưới.
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: segmented,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: title),
                  segmented,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Người đã xác thực eKYC luôn xếp trên; người chưa quét eKYC xếp chót.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (loading && ranking.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (ranking.isEmpty)
            const Text('Chưa có dữ liệu người dùng')
          else ...[
            _RankingGroupLabel(
              label: 'Đã xác thực eKYC (${verified.length})',
              color: AppColors.trustGreen,
            ),
            ...verified.map((r) => _RankingRow(row: r)),
            if (unverified.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RankingGroupLabel(
                label: 'Chưa quét eKYC — xếp chót (${unverified.length})',
                color: AppColors.warning,
              ),
              ...unverified.map((r) => _RankingRow(row: r)),
            ],
          ],
        ],
      ),
    );
  }
}

class _RankingGroupLabel extends StatelessWidget {
  const _RankingGroupLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.row});
  final AdminRankRow row;

  Color _rankColor() {
    switch (row.rank) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF9CA3AF);
      case 3:
        return const Color(0xFFB45309);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = row.displayName ?? row.email;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Màn hình hẹp: ẩn thanh điểm bên phải (điểm số đã hiển thị bằng chữ)
        // để tránh tràn ngang.
        final showBar = constraints.maxWidth >= 420;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#${row.rank}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _rankColor(),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFBFDBFE),
                child: Text(
                  name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EkycBadge(verified: row.verified),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.trustScore} điểm · ${row.rankLevel} · ${row.orders} giao dịch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (showBar) ...[
                const SizedBox(width: 12),
                SizedBox(width: 120, child: TrustScoreBar(score: row.trustScore)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SystemReportCard extends StatelessWidget {
  const _SystemReportCard({required this.stats});
  final AdminStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Báo cáo hệ thống',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('Tổng người dùng: ${s?.totalUsers ?? 0}'),
          Text('Đã eKYC: ${s?.verifiedUsers ?? 0}'),
          Text('eKYC chờ duyệt: ${s?.pendingEkyc ?? 0}'),
          Text('Báo cáo mở: ${s?.openReports ?? 0}'),
          Text('Tài khoản khóa: ${s?.lockedUsers ?? 0}'),
          Text('Tổng sản phẩm: ${s?.totalProducts ?? 0}'),
          Text('Tổng đơn hàng: ${s?.totalOrders ?? 0}'),
          Text('Giao dịch hoàn tất: ${s?.completedOrders ?? 0}'),
        ],
      ),
    );
  }
}
