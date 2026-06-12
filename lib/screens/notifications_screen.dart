import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/app_notification.dart';
import 'package:safemarket_app/screens/product_detail.dart';
import 'package:safemarket_app/screens/public_profile_screen.dart';
import 'package:safemarket_app/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.syncFromApi();
    NotificationService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _onTapNotification(
    BuildContext context,
    AppNotification n,
  ) async {
    await NotificationService.instance.markRead(n.id);
    if (!context.mounted) return;

    if (n.productId != null &&
        (n.type == 'NEW_PRODUCT' || n.type == 'PRODUCT_SOLD')) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(productId: n.productId!),
        ),
      );
      return;
    }
    if (n.sellerId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(userId: n.sellerId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = NotificationService.instance.items;
    final unread = NotificationService.instance.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: NotificationService.instance.markAllRead,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Không có thông báo'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = items[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _onTapNotification(context, n),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.icon) {
      case 'shield':
        return Icons.verified_user_outlined;
      case 'product':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd/MM HH:mm').format(notification.createdAt);

    return Material(
      color: notification.read ? AppColors.white : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
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
  }
}
