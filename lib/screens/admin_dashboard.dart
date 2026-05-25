import 'package:flutter/material.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/widgets/trust_score_bar.dart';

/// Màn hình SafeAdmin — dashboard quản trị Web/Tablet responsive.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedMenu = 0;

  static const _menuItems = [
    _MenuItem('Tổng quan', Icons.dashboard_outlined),
    _MenuItem('Người dùng', Icons.people_outline),
    _MenuItem('Phê duyệt eKYC', Icons.verified_user_outlined),
    _MenuItem('Báo cáo vi phạm', Icons.report_outlined),
    _MenuItem('Danh sách đen', Icons.block_outlined),
    _MenuItem('Báo cáo hệ thống', Icons.analytics_outlined),
  ];

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
                        _PageTitleRow(),
                        const SizedBox(height: 24),
                        _StatsCardsRow(),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 800) {
                              return const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: _EkycChartCard()),
                                  SizedBox(width: 16),
                                  Expanded(flex: 3, child: _RecentReportsCard()),
                                ],
                              );
                            }
                            return const Column(
                              children: [
                                _EkycChartCard(),
                                SizedBox(height: 16),
                                _RecentReportsCard(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const _UsersTableCard(),
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
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng quan hệ thống',
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
  @override
  Widget build(BuildContext context) {
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
            value: '1,284',
            icon: Icons.people,
            iconColor: AppColors.primary,
            change: '+12%',
            changePositive: true,
          ),
          _StatCardData(
            title: 'Đã định danh eKYC',
            value: '856',
            icon: Icons.shield,
            iconColor: AppColors.primary,
            change: '+5%',
            changePositive: true,
          ),
          _StatCardData(
            title: 'Báo cáo vi phạm',
            value: '24',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            change: '-2%',
            changePositive: false,
          ),
          _StatCardData(
            title: 'Tài khoản bị khóa',
            value: '12',
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
  const _RecentReportsCard();

  static const _reports = [
    _ReportItem('Trần Văn B', 'Gian lận giao dịch', 420, Colors.orange),
    _ReportItem('Lê Thị C', 'Spam tin rao', 510, Colors.orange),
    _ReportItem('Phạm Văn D', 'Hàng giả mạo', 280, Colors.red),
    _ReportItem('Hoàng Thị E', 'Quấy rối chat', 650, Colors.orange),
  ];

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
          ..._reports.map((r) => _ReportRow(item: r)),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('Xem tất cả báo cáo'),
            ),
          ),
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
  const _UsersTableCard();

  static const _users = [
    _UserRowData('Nguyễn Văn An', 'an.nguyen@email.com', 'NA', true, 920, 12),
    _UserRowData('Trần Thị B', 'b.tran@email.com', 'TB', false, 500, 3),
    _UserRowData('Lê Văn C', 'c.le@email.com', 'LC', true, 780, 8),
    _UserRowData('Phạm Thị D', 'd.pham@email.com', 'PD', true, 850, 15),
  ];

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
              rows: _users
                  .map(
                    (u) => DataRow(
                      cells: [
                        DataCell(_UserCell(user: u)),
                        DataCell(_EkycBadge(verified: u.ekycVerified)),
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: TrustScoreBar(score: u.trustScore),
                          ),
                        ),
                        DataCell(Text('${u.orders} đơn')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {},
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
