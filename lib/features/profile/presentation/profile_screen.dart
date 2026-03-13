import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login/login_screen.dart';
import '../../posts/presentation/widgets/post_card.dart';
import 'about_run_screen.dart';
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
          final faculty = data['faculty'] as String? ?? '';
          final bio = data['bio'] as String? ?? '';
          final photoUrl = data['photoUrl'] as String? ?? user.photoURL ?? '';
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showAboutMe(
                              context,
                              name: name,
                              faculty: faculty,
                              department: dept,
                              birthday: formattedBirthday,
                              bio: bio,
                            ),
                            icon: const Icon(Icons.person_outline),
                            label: const Text('About Me'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () {
                              context.push(EditProfileScreen.routePath);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit Profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // ── About RUN ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline,
                          color: AppTheme.runBlue),
                      title: const Text('About RUN'),
                      subtitle: const Text('History & Emergency Contacts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AboutRunScreen.routePath),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

  static void _showAboutMe(
    BuildContext context, {
    required String name,
    required String faculty,
    required String department,
    required String birthday,
    required String bio,
  }) {
    final theme = Theme.of(context);
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
                'About Me',
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
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
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
