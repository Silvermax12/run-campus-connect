import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/login/login_screen.dart';
import '../providers/profile_stream_provider.dart';
import 'edit_profile_screen.dart';
import 'profile_controller.dart';
import 'widgets/about_bottom_sheet.dart';
import 'widgets/user_posts_list.dart';

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
        body: const Center(child: Text('Please sign in to view your profile.')),
      );
    }

    // Watch user doc for real-time updates (e.g. after edit)
    final userDocAsync = ref.watch(
      profileDocumentStreamProvider(
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

          final formattedBirthday = (birthDay != null && birthMonth != null)
              ? formatBirthday(birthMonth, birthDay)
              : '';

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
                            onPressed: () => showAboutBottomSheet(
                              context,
                              name: name,
                              faculty: faculty,
                              department: dept,
                              birthday: formattedBirthday,
                              bio: bio,
                              title: 'About Me',
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
              // ── Contacts ───────────────────────────────────────────────
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
              UserPostsList(userId: user.uid),
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
