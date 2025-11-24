import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/login/login_screen.dart';
import '../../posts/presentation/widgets/post_card.dart';
import 'edit_profile_screen.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const routeName = 'profile';
  static const routePath = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile.')),
      );
    }

    // Watch user doc for real-time updates (e.g. after edit)
    final userDocAsync = ref.watch(
      streamProvider(
        ref.watch(firestoreProvider).collection('users').doc(user.uid),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(profileControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(LoginScreen.routePath);
              }
            },
          ),
        ],
      ),
      body: userDocAsync.when(
        data: (doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final name = data['displayName'] as String? ?? user.displayName ?? '';
          final dept = data['department'] as String? ?? '';
          final bio = data['bio'] as String? ?? '';
          final photoUrl = data['photoUrl'] as String? ?? user.photoURL ?? '';

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
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () {
                          context.push(EditProfileScreen.routePath);
                        },
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'My Posts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              _UserPostsList(userId: user.uid),
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

// Helper provider for simple stream
final streamProvider = StreamProvider.family<DocumentSnapshot, DocumentReference>(
  (ref, docRef) => docRef.snapshots(),
);

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
