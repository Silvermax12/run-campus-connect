import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import 'chat_screen.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  static const routeName = 'inbox';
  static const routePath = '/messages';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final chatsStream = ref.watch(userChatsStreamProvider(myUid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: chatsStream.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUserId = chat.participants.firstWhere((id) => id != myUid, orElse: () => '');
              if (otherUserId.isEmpty) return const SizedBox.shrink();

              return _ChatListTile(chat: chat, otherUserId: otherUserId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  const _ChatListTile({required this.chat, required this.otherUserId});

  final Chat chat;
  final String otherUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch other user's details
    final otherUserAsync = ref.watch(userDocProvider(otherUserId));
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final unreadCount = myUid != null ? (chat.unreadCounts[myUid] ?? 0) : 0;
    final isUnread = unreadCount > 0;

    return otherUserAsync.when(
      data: (doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = data['displayName'] as String? ?? 'Unknown';
        final photoUrl = data['photoUrl'] as String? ?? '';

        return ListTile(
          tileColor: isUnread ? Theme.of(context).primaryColor.withOpacity(0.05) : null,
          leading: CircleAvatar(
            backgroundImage: photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? Text(name.isNotEmpty ? name.characters.first : '?')
                : null,
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(chat.lastTime),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isUnread) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          onTap: () {
            context.push(ChatScreen.routePath(otherUserId), extra: name);
          },
        );
      },
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator()),
        title: Text('Loading...'),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

// Providers
final userChatsStreamProvider = StreamProvider.family<List<Chat>, String>((ref, myUid) {
  return ref.watch(chatRepositoryProvider).watchChats(myUid);
});

final userDocProvider = StreamProvider.family<DocumentSnapshot, String>((ref, userId) {
  return ref.watch(firestoreProvider).collection('users').doc(userId).snapshots();
});
