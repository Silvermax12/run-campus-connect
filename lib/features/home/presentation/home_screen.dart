import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../notifications/data/unread_badge_provider.dart';
import '../../posts/presentation/create_post/create_post_screen.dart';
import '../../chat/presentation/inbox_screen.dart';
import '../../posts/presentation/feed/post_feed_controller.dart';
import '../../posts/presentation/widgets/post_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = 'home';
  static const routePath = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(postFeedControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    // Invalidate the provider to force a fresh fetch
    ref.refresh(postFeedControllerProvider);
    // Wait for the new state to be loaded (optional, but good for UX if we want to show the spinner until data is back)
    // However, since we are invalidating, the stream will restart.
    // We might just wait a bit or let the stream listener handle it.
    // Actually, ref.refresh returns the new state, but for a class provider it returns the controller.
    // We can just await a small delay or rely on the UI to update.
    // But to keep the RefreshIndicator spinning until data is ready, we might need to wait for the loading state to finish.
    // For now, simple invalidation is what was requested.
    await Future.delayed(const Duration(milliseconds: 500)); // Small UX delay
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(postFeedControllerProvider);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final unreadCountAsync = ref.watch(unreadBadgeProvider(currentUser?.uid ?? ''));
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () => context.push(InboxScreen.routePath),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Builder(
          builder: (context) {
            if (feedState.isInitialLoading && feedState.posts.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (feedState.posts.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No posts yet. Be the first to share!')),
                ],
              );
            }
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: feedState.posts.length + 1,
              itemBuilder: (context, index) {
                if (index < feedState.posts.length) {
                  return PostCard(post: feedState.posts[index]);
                }
                if (feedState.isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!feedState.hasMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('You are up to date!')),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(CreatePostScreen.routePath),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
