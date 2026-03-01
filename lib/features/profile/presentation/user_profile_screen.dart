import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../posts/presentation/widgets/post_card.dart';
import 'profile_controller.dart';
import 'profile_screen.dart';
import 'user_profile_screen_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/friend_repository.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  static const routeName = 'user-profile';
  static String routePath(String userId) => '/user/$userId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Watch user doc
    final userDocAsync = ref.watch(
      streamProvider(
        ref.watch(firestoreProvider).collection('users').doc(userId),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: userDocAsync.when(
        data: (doc) {
          if (!doc.exists) {
            return const Center(child: Text('User not found.'));
          }
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final name = data['displayName'] as String? ?? 'Unknown';
          final dept = data['department'] as String? ?? '';
          final bio = data['bio'] as String? ?? '';
          final photoUrl = data['photoUrl'] as String? ?? '';

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            photoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(photoUrl)
                                : null,
                        child:
                            photoUrl.isEmpty
                                ? Text(
                                  name.isNotEmpty ? name.characters.first : '?',
                                  style: const TextStyle(fontSize: 32),
                                )
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (dept.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dept,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _FriendActionButtons(userId: userId),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Posts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              _UserPostsList(userId: userId),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _UserPostsList extends ConsumerWidget {
  const _UserPostsList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId: userId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No posts yet.'),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => PostCard(post: posts[index]),
            childCount: posts.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Error loading posts: $err'),
        ),
      ),
    );
  }
}

class _FriendActionButtons extends ConsumerWidget {
  const _FriendActionButtons({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null || myUid == userId) return const SizedBox.shrink();

    final friendStatusAsync = ref.watch(
      friendStatusStreamProvider(myUid: myUid, targetUid: userId),
    );

    // Get current user's profile for notification
    final myProfileAsync = ref.watch(
      streamProvider(FirebaseFirestore.instance.collection('users').doc(myUid)),
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.push(ChatScreen.routePath(userId));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Message'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: friendStatusAsync.when(
            data: (status) {
              switch (status) {
                case FriendStatus.none:
                  return myProfileAsync.when(
                    data: (myDoc) {
                      final myData = myDoc.data() as Map<String, dynamic>? ?? {};
                      final myName = myData['displayName'] as String? ?? 'User';
                      final myPhoto = myData['photoUrl'] as String? ?? '';
                      
                      return OutlinedButton(
                        onPressed: () {
                          ref.read(friendRepositoryProvider).sendFriendRequest(
                                myUid: myUid,
                                targetUid: userId,
                                myName: myName,
                                myPhotoUrl: myPhoto,
                              );
                        },
                        child: const Text('Add Friend'),
                      );
                    },
                    loading: () => const OutlinedButton(onPressed: null, child: Text('Add Friend')),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                case FriendStatus.pending_outgoing:
                  return OutlinedButton(
                    onPressed: () {
                      ref.read(friendRepositoryProvider).cancelFriendRequest(
                            myUid: myUid,
                            targetUid: userId,
                          );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('Request Sent'),
                  );
                case FriendStatus.pending_incoming:
                  return ElevatedButton(
                    onPressed: () {
                      ref.read(friendRepositoryProvider).acceptFriendRequest(
                            myUid: myUid,
                            targetUid: userId,
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept Request'),
                  );
                case FriendStatus.accepted:
                  return OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Unfriend'),
                          content: const Text(
                              'Are you sure you want to remove this friend?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(friendRepositoryProvider).unfriend(
                                      myUid: myUid,
                                      targetUid: userId,
                                    );
                                Navigator.pop(context);
                              },
                              child: const Text('Unfriend'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Friends'),
                  );
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
