import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/public_profile_screen.dart';
import 'package:safemarket_app/services/follow_service.dart';
import 'package:safemarket_app/widgets/verified_badge.dart';

enum FollowListMode { followers, following }

/// Danh sách người theo dõi / đang theo dõi.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
    this.titleHint,
  });

  final int userId;
  final FollowListMode mode;
  final String? titleHint;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late Future<List<FollowUserItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FollowUserItem>> _load() {
    return widget.mode == FollowListMode.followers
        ? FollowService.instance.listFollowers(widget.userId)
        : FollowService.instance.listFollowing(widget.userId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  String get _title {
    final base = widget.mode == FollowListMode.followers
        ? 'Người theo dõi'
        : 'Đang theo dõi';
    final hint = widget.titleHint?.trim();
    if (hint == null || hint.isEmpty) return base;
    return '$base · $hint';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<FollowUserItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              );
            }
            final items = snap.data ?? const <FollowUserItem>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    widget.mode == FollowListMode.followers
                        ? Icons.people_outline
                        : Icons.person_add_alt_1_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.mode == FollowListMode.followers
                        ? 'Chưa có ai theo dõi'
                        : 'Chưa theo dõi ai',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = items[i];
                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFBFDBFE),
                        child: Text(
                          u.initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (u.kycStatus == 'Verified')
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: VerifiedBadge(size: 16),
                        ),
                    ],
                  ),
                  title: Text(
                    u.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PublicProfileScreen(
                          userId: u.userId,
                          displayNameHint: u.label,
                        ),
                      ),
                    ).then((_) => _refresh());
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
