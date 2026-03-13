import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../explore/presentation/explore_controller.dart';
import '../../profile/presentation/user_profile_screen.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import 'chat_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  static const routeName = 'inbox';
  static const routePath = '/messages';

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    ref.read(exploreControllerProvider.notifier).searchUsers(query);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final chatsStream = ref.watch(userChatsStreamProvider(myUid));
    final searchResultsAsync = ref.watch(exploreControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Find Students...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // ── Body: search results OR chat list ─────────────────────
          Expanded(
            child: _isSearching
                ? _buildSearchResults(searchResultsAsync, myUid)
                : _buildChatList(chatsStream, myUid),
          ),
        ],
      ),
    );
  }

  // ── Search Results ──────────────────────────────────────────────────
  Widget _buildSearchResults(
    AsyncValue<List<Map<String, dynamic>>> searchResultsAsync,
    String myUid,
  ) {
    return searchResultsAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No students found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final user = users[index];
            final uid = user['uid'] as String? ?? '';
            final name = user['displayName'] as String? ?? 'Unknown';
            final dept = user['department'] as String? ?? '';
            final photoUrl = user['photoUrl'] as String? ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name.characters.first : '?')
                    : null,
              ),
              title: Text(name),
              subtitle: Text(dept),
              trailing: uid != myUid
                  ? IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        _clearSearch();
                        context.push(ChatScreen.routePath(uid),
                            extra: name);
                      },
                    )
                  : null,
              onTap: () {
                if (uid.isNotEmpty) {
                  context.push(UserProfileScreen.routePath(uid));
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  // ── Chat List ─────────────────────────────────────────────────────
  Widget _buildChatList(
    AsyncValue<List<Chat>> chatsStream,
    String myUid,
  ) {
    return chatsStream.when(
      data: (chats) {
        if (chats.isEmpty) {
          return const Center(child: Text('No messages yet.'));
        }
        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final otherUserId = chat.participants.firstWhere(
              (id) => id != myUid,
              orElse: () => '',
            );
            if (otherUserId.isEmpty) return const SizedBox.shrink();
            return _ChatListTile(chat: chat, otherUserId: otherUserId);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
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
          tileColor: isUnread
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
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
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
              if (isUnread) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
final userChatsStreamProvider =
    StreamProvider.family<List<Chat>, String>((ref, myUid) {
  return ref.watch(chatRepositoryProvider).watchChats(myUid);
});

final userDocProvider =
    StreamProvider.family<DocumentSnapshot, String>((ref, userId) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots();
});
