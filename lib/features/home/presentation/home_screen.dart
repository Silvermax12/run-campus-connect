import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../notifications/data/unread_badge_provider.dart';
import '../../posts/presentation/create_post/create_post_screen.dart';
import '../../chat/presentation/inbox_screen.dart';
import '../../posts/presentation/feed/post_feed_controller.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../profile/data/profile_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = 'home';
  static const routePath = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final unreadCountAsync =
        ref.watch(unreadBadgeProvider(currentUser?.uid ?? ''));
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    // Watch the current user's profile to get faculty & department.
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;
    final userFaculty = profile?.faculty ?? '';
    final userDepartment = profile?.department ?? '';

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Faculty'),
            Tab(text: 'My Dept'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(feedType: FeedType.global, filterValue: ''),
          _FeedTab(feedType: FeedType.faculty, filterValue: userFaculty),
          _FeedTab(feedType: FeedType.department, filterValue: userDepartment),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(CreatePostScreen.routePath),
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual tab that displays a filtered post feed.
// ---------------------------------------------------------------------------

class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab({required this.feedType, required this.filterValue});

  final FeedType feedType;
  final String filterValue;

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
      ref
          .read(postFeedControllerProvider(
                  widget.feedType, widget.filterValue)
              .notifier)
          .loadMore();
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(
        postFeedControllerProvider(widget.feedType, widget.filterValue));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(
        postFeedControllerProvider(widget.feedType, widget.filterValue));

    return RefreshIndicator(
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
                Center(child: Text('No posts here yet.')),
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
    );
  }
}
