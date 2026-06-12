import 'dart:async';

import 'package:flutter/material.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/chat.dart';
import 'package:safemarket_app/screens/chat_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  StreamSubscription<List<ChatThread>>? _sub;
  List<ChatThread> _threads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = ChatService.instance.watchThreads().listen(
      (list) {
        if (mounted) {
          setState(() {
            _threads = list;
            _loading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.instance.currentUser?.userId ?? 0;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_threads.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Chưa có hội thoại.\nMua hàng hoặc bấm "Liên hệ người bán" để chat realtime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = _threads[i];
        final peer = t.peerName(myId);
        return ListTile(
          tileColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFBFDBFE),
                child: Text(
                  peer.isNotEmpty ? peer[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.trustGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            peer,
            style: TextStyle(
              fontWeight:
                  t.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            t.lastMessage ?? t.productTitle ?? 'Bắt đầu chat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: t.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
              color: t.unreadCount > 0
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (t.updatedAt != null)
                Text(
                  _formatTime(t.updatedAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              if (t.unreadCount > 0) ...[
                const SizedBox(height: 4),
                _ThreadUnreadBadge(count: t.unreadCount),
              ],
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ChatScreen(
                  threadId: t.threadId,
                  peerName: peer,
                  subtitle: t.productTitle,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

class _ThreadUnreadBadge extends StatelessWidget {
  const _ThreadUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 6 : 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
