import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../data/run_news_provider.dart';
import 'contacts.dart';
import 'governance_screen.dart';
import 'history_screen.dart';
import 'motto_logo_anthem_screen.dart';
import 'news_detail_screen.dart';
import 'vision_mission_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const routeName = 'explore';
  static const routePath = '/explore';

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(runNewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Campus News Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.newspaper, color: AppTheme.runBlue),
                    const SizedBox(width: 8),
                    Text(
                      'RUN News',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.runBlue,
                              ),
                    ),
                  ],
                ),
              ),
            ),

            // ── News Cards ──────────────────────────────────────────────
            newsAsync.when(
              data: (newsList) {
                if (newsList.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No news yet',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = newsList[index];
                        return _NewsCard(newsItem: item);
                      },
                      childCount: newsList.length,
                    ),
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
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('Error loading news: $err')),
                ),
              ),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Drawer ──────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.runBlue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/run_logo.jpg',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Redeemer's University",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Campus Connect',
                  style: TextStyle(
                    color: AppTheme.runGold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          _drawerItem(
            context,
            icon: Icons.newspaper,
            label: 'News',
            onTap: () {
              Navigator.pop(context);
              _scrollToTop();
            },
          ),
          _drawerItem(
            context,
            icon: Icons.history_edu,
            label: 'History',
            onTap: () {
              Navigator.pop(context);
              context.push(HistoryScreen.routePath);
            },
          ),
          _drawerItem(
            context,
            icon: Icons.account_balance,
            label: 'Governance',
            onTap: () {
              Navigator.pop(context);
              context.push(GovernanceScreen.routePath);
            },
          ),
          _drawerItem(
            context,
            icon: Icons.emoji_events,
            label: 'Motto, Logo & Anthem',
            onTap: () {
              Navigator.pop(context);
              context.push(MottoLogoAnthemScreen.routePath);
            },
          ),
          _drawerItem(
            context,
            icon: Icons.lightbulb,
            label: 'Vision, Mission & Strategy',
            onTap: () {
              Navigator.pop(context);
              context.push(VisionMissionScreen.routePath);
            },
          ),
          const Divider(),
          _drawerItem(
            context,
            icon: Icons.phone_in_talk,
            label: 'Contacts',
            onTap: () {
              Navigator.pop(context);
              context.push(ContactsScreen.routePath);
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.runBlue),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppTheme.runBlue,
        ),
      ),
      selectedTileColor: AppTheme.runGold.withOpacity(0.15),
      selectedColor: AppTheme.runGold,
      onTap: onTap,
    );
  }
}

// ── News Card Widget ──────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.newsItem});

  final Map<String, dynamic> newsItem;

  @override
  Widget build(BuildContext context) {
    final heading = newsItem['heading'] as String? ?? '';
    final imageUrl = newsItem['imageUrl'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Image ────────────────────────────────────────────────
          if (imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => FullScreenImageViewer.open(
                context,
                imageUrl: imageUrl,
                heroTag: 'news-image-${newsItem['id'] ?? imageUrl}',
              ),
              child: Hero(
                tag: 'news-image-${newsItem['id'] ?? imageUrl}',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ShimmerBox(
                      width: double.infinity,
                      height: 180,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              heading,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Read More Button ─────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewsDetailScreen(newsItem: newsItem),
                  ),
                );
              },
              child: const Text(
                'Read More',
                style: TextStyle(color: AppTheme.runBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
