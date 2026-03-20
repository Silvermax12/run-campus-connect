import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../providers/profile_stream_provider.dart';
import 'widgets/about_bottom_sheet.dart';
import 'widgets/user_posts_list.dart';

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
      profileDocumentStreamProvider(
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

          final formattedBirthday = (birthDay != null && birthMonth != null)
              ? formatBirthday(birthMonth, birthDay)
              : '';

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
                              onPressed: () {
                                final firstName =
                                    name.trim().split(RegExp(r'\s+')).first;
                                final title = firstName.isNotEmpty
                                    ? 'About $firstName'
                                    : 'About them';
                                showAboutBottomSheet(
                                  context,
                                  name: name,
                                  faculty: faculty,
                                  department: dept,
                                  birthday: formattedBirthday,
                                  bio: bio,
                                  title: title,
                                );
                              },
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
              UserPostsList(userId: userId),
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
