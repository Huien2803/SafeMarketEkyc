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
  late Future<List<ChatThread>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = ChatService.instance.getThreads();
      });

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.instance.currentUser?.userId ?? 0;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<ChatThread>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final threads = snapshot.data ?? [];
          if (threads.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'Chưa có hội thoại.\nMua hàng hoặc bấm "Liên hệ người bán" để chat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = threads[i];
              final peer = t.peerName(myId);
              return ListTile(
                tileColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFBFDBFE),
                  child: Text(
                    peer.isNotEmpty ? peer[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                title: Text(peer, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  t.lastMessage ?? t.productTitle ?? 'Bắt đầu chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        },
      ),
    );
  }
}
