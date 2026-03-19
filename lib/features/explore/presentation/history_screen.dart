import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../data/institutional_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const routeName = 'history';
  static const routePath = '/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(runHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: historyAsync.when(
        data: (data) {
          if (data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Our History')),
              body: const Center(child: Text('No history available.')),
            );
          }

          // Structured format:
          // {
          //   "title": "Our History",
          //   "blocks": [
          //      { "type": "text", "content": ["para1", ...] },
          //      { "type": "image", "url": "...", "alt": "..." },
          //   ],
          //   "last_updated": "...",
          // }
          final title = data['title'] as String? ?? 'Our History';
          final blocks = (data['blocks'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

          // Fallback to legacy flat format if blocks are empty
          if (blocks.isEmpty && data['fullHistory'] is String) {
            final fullHistory = data['fullHistory'] as String? ?? '';
            final imageUrls =
                (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

            final paragraphs = fullHistory
                .split('\n')
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList();

            final heroImage = imageUrls.isNotEmpty ? imageUrls[0] : null;

            return _LegacyHistoryLayout(
              heroImage: heroImage,
              paragraphs: paragraphs,
              imageUrls: imageUrls,
            );
          }

          final heroImage = _firstImageUrl(blocks);

          return CustomScrollView(
            slivers: [
              // ── Header (Hero Image) ────────────────────────────────────
              SliverAppBar(
                expandedHeight: heroImage != null ? 280.0 : kToolbarHeight,
                pinned: true,
                backgroundColor: AppTheme.runBlue,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                  background: heroImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: heroImage,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ShimmerBox(
                                width: double.infinity,
                                height: 280,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.runBlue,
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black26,
                                    Colors.black87,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),

              // ── Structured history blocks — faithful to JSON order ─────
              // JSON block order: text → image → text → image → image → text
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= blocks.length) {
                        return const SizedBox.shrink();
                      }
                      final block = blocks[index];
                      final type = block['type'] as String? ?? '';

                      // ── Image block ──────────────────────────────────
                      if (type == 'image' && block['url'] is String) {
                        final url = block['url'] as String;
                        return _ArticleImage(
                          imageUrl: url,
                          index: index,
                        );
                      }

                      // ── Text block ───────────────────────────────────
                      if (type == 'text') {
                        final List<dynamic> content =
                            block['content'] as List<dynamic>? ?? [];
                        final paragraphs = content
                            .map((e) => e.toString().trim())
                            .where((p) => p.isNotEmpty)
                            .toList();
                        if (paragraphs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < paragraphs.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: index == 0 && i == 0
                                    ? _DropCapParagraph(
                                        text: paragraphs[i],
                                      )
                                    : Text(
                                        paragraphs[i],
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                          height: 1.8,
                                          color: Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                    childCount: blocks.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}

// ── Legacy layout used when Firestore still has the old flat fields ──────────
class _LegacyHistoryLayout extends StatelessWidget {
  final String? heroImage;
  final List<String> paragraphs;
  final List<String> imageUrls;

  const _LegacyHistoryLayout({
    required this.heroImage,
    required this.paragraphs,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: heroImage != null ? 280.0 : kToolbarHeight,
          pinned: true,
          backgroundColor: AppTheme.runBlue,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Our History',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
            ),
            background: heroImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: heroImage!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ShimmerBox(
                          width: double.infinity,
                          height: 280,
                        ),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppTheme.runBlue),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black26,
                              Colors.black87,
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        SliverPadding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      "Redeemer's University",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.runBlue,
                      ),
                    ),
                  );
                }

                final pIndex = index - 1;
                final isImageSlot = (pIndex + 1) % 3 == 0;
                final paragraphIndex = pIndex - (pIndex ~/ 3);
                final imageIndex = (pIndex ~/ 3) + 1;

                if (isImageSlot) {
                  if (imageIndex < imageUrls.length) {
                    return _ArticleImage(
                      imageUrl: imageUrls[imageIndex],
                      index: imageIndex,
                    );
                  }
                  return const SizedBox.shrink();
                }

                if (paragraphIndex < paragraphs.length) {
                  final isFirstChar = paragraphIndex == 0;
                  final text = paragraphs[paragraphIndex];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: isFirstChar
                        ? _DropCapParagraph(text: text)
                        : Text(
                            text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.8,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                  );
                }

                return const SizedBox.shrink();
              },
              childCount: 1 +
                  paragraphs.length +
                  (paragraphs.length ~/ 2),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

String? _firstImageUrl(List<Map<String, dynamic>> blocks) {
  for (final b in blocks) {
    if (b['type'] == 'image' && b['url'] is String) {
      final u = (b['url'] as String).trim();
      if (u.isNotEmpty) return u;
    }
  }
  return null;
}

// ── Drop Cap Text for the very first paragraph ───────────────────────────────
class _DropCapParagraph extends StatelessWidget {
  final String text;

  const _DropCapParagraph({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final firstChar = text.characters.first;
    final rest = text.characters.skip(1).toString();
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: firstChar,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppTheme.runGold,
              fontFamily: 'serif',
              height: 1.0,
            ),
          ),
          TextSpan(
            text: rest,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.8,
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── In-article Image Component ───────────────────────────────────────────────
class _ArticleImage extends StatelessWidget {
  final String imageUrl;
  final int index;

  const _ArticleImage({required this.imageUrl, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: GestureDetector(
        onTap: () => FullScreenImageViewer.open(
          context,
          imageUrl: imageUrl,
          heroTag: 'history-img-$index',
        ),
        child: Hero(
          tag: 'history-img-$index',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ShimmerBox(
                  width: double.infinity,
                  height: 250,
                  borderRadius: 16,
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
