import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/presentation/user_profile_screen.dart';
import 'explore_controller.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const routeName = 'explore';
  static const routePath = '/explore';

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce could be added here for better performance
    ref.read(exploreControllerProvider.notifier).searchUsers(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(exploreControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Find Students...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ),
            Expanded(
              child: searchResultsAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    if (_searchController.text.isNotEmpty) {
                      return const Center(child: Text('No students found.'));
                    }
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Search for students by name',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              ? Text(name.isNotEmpty ? name.characters.first : '?')
                              : null,
                        ),
                        title: Text(name),
                        subtitle: Text(dept),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
