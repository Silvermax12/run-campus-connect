import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/birthday_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/data/unread_badge_provider.dart';
import '../../posts/presentation/create_post/create_post_screen.dart';
import '../../chat/presentation/inbox_screen.dart';
import '../../posts/data/post_repository.dart';
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
  bool _birthdayMessageSent = false;

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

  void _sendBirthdayMessageIfNeeded() {
    if (_birthdayMessageSent) return;
    final isBirthday = ref.read(isTodayUserBirthdayProvider);
    if (isBirthday) {
      _birthdayMessageSent = true;
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid != null) {
        ref.read(birthdayServiceProvider).sendBirthdayMessage(uid);
      }
    }
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

    // Birthday check
    final isBirthday = ref.watch(isTodayUserBirthdayProvider);

    // Send birthday message (fire-and-forget, once per session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendBirthdayMessageIfNeeded();
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // ── RUN Logo (WhatsApp-style) ────────────────────────────────
            ClipOval(
              child: Image.asset(
                'assets/images/run_logo.jpg',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Redeemer's University",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text('Campus Connect'),
              ],
            ),
          ],
        ),
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
      body: Column(
        children: [
          // ── Birthday Banner ──────────────────────────────────────────
          if (isBirthday)
            MaterialBanner(
              backgroundColor: AppTheme.runGold.withValues(alpha: 0.15),
              content: const Text(
                '🎂 Happy Birthday! Enjoy your special day! 🎉',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              leading: const Icon(Icons.cake, color: AppTheme.runGold, size: 28),
              actions: [
                TextButton(
                  onPressed: () {
                    // Dismiss by force-rebuilding without the banner
                    // In a real app you'd store a dismissed flag
                  },
                  child: const Text('🥳'),
                ),
              ],
            ),

          // ── Feed Tabs ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FeedTab(feedType: FeedType.global, filterValue: ''),
                _FeedTab(
                    feedType: FeedType.faculty, filterValue: userFaculty),
                _FeedTab(
                    feedType: FeedType.department,
                    filterValue: userDepartment),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.runBlue,
        onPressed: () => context.push(CreatePostScreen.routePath),
        child: const Icon(Icons.edit_note, color: AppTheme.runGold),
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
    // 1. Invalidate the underlying Firestore stream so it re-subscribes.
    switch (widget.feedType) {
      case FeedType.global:
        ref.invalidate(globalPostsStreamProvider);
        break;
      case FeedType.faculty:
        ref.invalidate(facultyPostsStreamProvider(widget.filterValue));
        break;
      case FeedType.department:
        ref.invalidate(departmentPostsStreamProvider(widget.filterValue));
        break;
    }
    // 2. Re-create the feed controller so it picks up the fresh stream.
    ref.invalidate(
        postFeedControllerProvider(widget.feedType, widget.filterValue));
    // 3. Give the new providers time to initialise and the stream to emit.
    await Future.delayed(const Duration(milliseconds: 800));
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
            cacheExtent: 500,
            itemCount: feedState.posts.length + 1,
            itemBuilder: (context, index) {
              if (index < feedState.posts.length) {
                return RepaintBoundary(
                  child: PostCard(post: feedState.posts[index]),
                );
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
