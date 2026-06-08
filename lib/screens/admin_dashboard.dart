import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/services/admin_service.dart';
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
  bool _loading = true;

  static const _menuItems = [
    _MenuItem('Tổng quan', Icons.dashboard_outlined),
    _MenuItem('Người dùng', Icons.people_outline),
    _MenuItem('Phê duyệt eKYC', Icons.verified_user_outlined),
    _MenuItem('Báo cáo vi phạm', Icons.report_outlined),
    _MenuItem('Danh sách đen', Icons.block_outlined),
    _MenuItem('Báo cáo hệ thống', Icons.analytics_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await AdminService.instance.getStats();
      final users = await AdminService.instance.getUsers();
      final reports = await AdminService.instance.getReports();
      final pending = await AdminService.instance.getPendingEkyc();
      final locked = await AdminService.instance.getLockedUsers();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _users = users;
        _reports = reports;
        _pendingEkyc = pending;
        _lockedUsers = locked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isWide) _AdminSidebar(
            selectedIndex: _selectedMenu,
            items: _menuItems,
            onSelect: (i) => setState(() => _selectedMenu = i),
          ),
          Expanded(
            child: Column(
              children: [
                _AdminHeader(showMenuButton: !isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PageTitleRow(menuIndex: _selectedMenu),
                        const SizedBox(height: 24),
                        _buildMenuContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: _AdminSidebar(
                selectedIndex: _selectedMenu,
                items: _menuItems,
                onSelect: (i) {
                  setState(() => _selectedMenu = i);
                  Navigator.pop(context);
                },
              ),
            ),
    );
  }

  Widget _buildMenuContent() {
    switch (_selectedMenu) {
      case 1:
        return _UsersTableCard(users: _users, loading: _loading, onLock: _lockUser, onUnlock: _unlockUser);
      case 2:
        return _PendingEkycCard(
          items: _pendingEkyc,
          loading: _loading,
          onApprove: _approveEkyc,
          onReject: _rejectEkyc,
        );
      case 3:
        return _ReportsManageCard(
          reports: _reports,
          loading: _loading,
          onResolve: _resolveReport,
        );
      case 4:
        return _LockedUsersCard(
          users: _lockedUsers,
          loading: _loading,
          onUnlock: _unlockUser,
        );
      case 5:
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
                      const Expanded(flex: 7, child: _EkycChartCard()),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _RecentReportsCard(reports: _reports)),
                    ],
                  );
                }
                return Column(
                  children: [
                    const _EkycChartCard(),
                    const SizedBox(height: 16),
                    _RecentReportsCard(reports: _reports),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _UsersTableCard(users: _users, loading: _loading),
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

  Future<void> _lockUser(int userId) async {
    try {
      await AdminService.instance.lockUser(userId);
      await _load();
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
  });

  final int selectedIndex;
  final List<_MenuItem> items;
  final ValueChanged<int> onSelect;

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
        ],
      ),
    );
  }
}

/// Header: tìm kiếm + thông báo + avatar admin.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.showMenuButton});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppColors.white,
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người dùng, giao dịch...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin Quản trị',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'HỆ THỐNG SAFEMARKET',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: const Color(0xFFBFDBFE),
            child: Text(
              'AD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTitleRow extends StatelessWidget {
  const _PageTitleRow({required this.menuIndex});
  final int menuIndex;

  String get _title {
    switch (menuIndex) {
      case 1:
        return 'Quản lý người dùng';
      case 2:
        return 'Phê duyệt eKYC';
      case 3:
        return 'Báo cáo vi phạm';
      case 4:
        return 'Danh sách đen';
      case 5:
        return 'Báo cáo hệ thống';
      default:
        return 'Tổng quan hệ thống';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chào mừng trở lại, đây là những gì đang diễn ra hôm nay.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('Xuất báo cáo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
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
            change: 'SQL',
            changePositive: true,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Đã định danh eKYC',
            value: '${s?.verifiedUsers ?? 0}',
            icon: Icons.shield,
            iconColor: AppColors.primary,
            change: 'live',
            changePositive: true,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Báo cáo vi phạm',
            value: '${s?.openReports ?? 0}',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            change: 'open',
            changePositive: false,
            isNeutralChange: true,
          ),
          _StatCardData(
            title: 'Tài khoản bị khóa',
            value: '${s?.lockedUsers ?? 0}',
            icon: Icons.person_off_outlined,
            iconColor: AppColors.danger,
            change: '+1',
            changePositive: false,
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
            childAspectRatio: crossAxisCount == 1 ? 2.8 : 1.8,
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
  const _EkycChartCard();

  static const _labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _values = [0.45, 0.62, 0.55, 0.78, 0.68, 0.85, 0.72];

  @override
  Widget build(BuildContext context) {
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
                'Biến động Định danh eKYC',
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tuần này', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_labels.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: _values[i],
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
                          _labels[i],
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
    this.onLock,
    this.onUnlock,
  });

  final List<AdminUserRow> users;
  final bool loading;
  final void Function(int userId)? onLock;
  final void Function(int userId)? onUnlock;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quản lý người dùng gần đây',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
            ],
          ),
          const SizedBox(height: 16),
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
                          u.accountStatus == 'Active'
                              ? IconButton(
                                  tooltip: 'Khóa tài khoản',
                                  icon: const Icon(Icons.block, size: 20),
                                  onPressed: onLock != null
                                      ? () => onLock!(u.userId)
                                      : null,
                                )
                              : IconButton(
                                  tooltip: 'Mở khóa',
                                  icon: const Icon(Icons.lock_open, size: 20),
                                  onPressed: onUnlock != null
                                      ? () => onUnlock!(u.userId)
                                      : null,
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

class _UserRowData {
  const _UserRowData(
    this.name,
    this.email,
    this.initials,
    this.ekycVerified,
    this.trustScore,
    this.orders,
  );

  final String name;
  final String email;
  final String initials;
  final bool ekycVerified;
  final int trustScore;
  final int orders;
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.user});

  final _UserRowData user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFBFDBFE),
          radius: 18,
          child: Text(
            user.initials,
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
            Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              user.email,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hồ sơ eKYC chờ duyệt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Không có hồ sơ chờ duyệt')
          else
            ...items.map((e) {
              final userId = (e['userId'] as num).toInt();
              return ListTile(
                title: Text(e['displayName'] as String? ?? ''),
                subtitle: Text(
                    '${e['fullName'] ?? ''} • ${e['idNumber'] ?? ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => onApprove(userId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => onReject(userId),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReportsManageCard extends StatelessWidget {
  const _ReportsManageCard({
    required this.reports,
    required this.loading,
    required this.onResolve,
  });

  final List<Map<String, dynamic>> reports;
  final bool loading;
  final void Function(int reportId) onResolve;

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
          const Text('Xử lý báo cáo vi phạm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Text('Không có báo cáo mở')
          else
            ...reports.map((r) {
              final id = (r['reportId'] as num).toInt();
              return ListTile(
                title: Text(r['name'] as String? ?? ''),
                subtitle: Text(r['reason'] as String? ?? ''),
                trailing: FilledButton(
                  onPressed: () => onResolve(id),
                  child: const Text('Đã xử lý'),
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
              return ListTile(
                title: Text(u['displayName'] as String? ?? ''),
                subtitle: Text(
                    '${u['accountStatus']} • ${u['lockReason'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open),
                  onPressed: () => onUnlock(id),
                ),
              );
            }),
        ],
      ),
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
          Text('Báo cáo mở: ${s?.openReports ?? 0}'),
          Text('Tài khoản khóa: ${s?.lockedUsers ?? 0}'),
        ],
      ),
    );
  }
}
