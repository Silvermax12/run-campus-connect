import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../chat/presentation/chat_screen.dart';
import 'profile_controller.dart';
import 'profile_screen.dart';

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
          final faculty = data['faculty'] as String? ?? '';
          final bio = data['bio'] as String? ?? '';
          final photoUrl = data['photoUrl'] as String? ?? '';
          final birthDay = (data['birthDay'] as num?)?.toInt();
          final birthMonth = (data['birthMonth'] as num?)?.toInt();

          // Format birthday
          String formattedBirthday = '';
          if (birthDay != null && birthMonth != null) {
            const months = [
              '', 'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December',
            ];
            if (birthMonth >= 1 && birthMonth <= 12) {
              final suffix = _daySuffix(birthDay);
              formattedBirthday = '${months[birthMonth]} $birthDay$suffix';
            }
          }

          final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

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
                      if (faculty.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          faculty,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
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
                      if (formattedBirthday.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cake_outlined, size: 18,
                                color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              formattedBirthday,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Actions for other users
                      if (myUid != null && myUid != userId)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                context.push(ChatScreen.routePath(userId));
                              },
                              icon: const Icon(Icons.message_outlined),
                              label: const Text('Message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showAboutUser(
                                context,
                                name: name,
                                faculty: faculty,
                                department: dept,
                                birthday: formattedBirthday,
                                bio: bio,
                              ),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('View profile'),
                            ),
                          ],
                        ),
                    ],
                  ),
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

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static void _showAboutUser(
    BuildContext context, {
    required String name,
    required String faculty,
    required String department,
    required String birthday,
    required String bio,
  }) {
    final theme = Theme.of(context);
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final title = firstName.isNotEmpty ? 'About $firstName' : 'About them';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              _aboutRow(Icons.person_outline, 'Name', name),
              _aboutRow(Icons.account_balance_outlined, 'Faculty', faculty),
              _aboutRow(Icons.school_outlined, 'Department', department),
              if (birthday.isNotEmpty)
                _aboutRow(Icons.cake_outlined, 'Birthday', birthday),
              if (bio.isNotEmpty) _aboutRow(Icons.info_outline, 'Bio', bio),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _aboutRow(IconData icon, String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.runBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
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
