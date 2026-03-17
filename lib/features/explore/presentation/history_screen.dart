import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
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

          final fullHistory = data['fullHistory'] as String? ?? '';
          final imageUrls =
              (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          // Split history into actual paragraphs
          final paragraphs = fullHistory
              .split('\n')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

          final heroImage = imageUrls.isNotEmpty ? imageUrls[0] : null;

          return CustomScrollView(
            slivers: [
              // ── Header (Hero Image) ──────────────────────────────────────
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
                              imageUrl: heroImage,
                              fit: BoxFit.cover,
                            ),
                            // Dark gradient overlay to make text readable
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

              // ── Article Body (Interleaved Text and Images) ───────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

                      // Adjust index because index 0 is the title
                      final pIndex = index - 1;

                      // Calculate if we need to show a paragraph or an image
                      // Layout pattern: Paragraph -> Paragraph -> Image
                      final isImageSlot = (pIndex + 1) % 3 == 0;
                      final paragraphIndex = pIndex - (pIndex ~/ 3);
                      final imageIndex = (pIndex ~/ 3) + 1; // +1 to skip hero

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
                    // Total count: 1 Title + paragraphs + image slots
                    childCount: 1 +
                        paragraphs.length +
                        (paragraphs.length ~/ 2), // Approx 1 image per 2 paragraphs
                  ),
                ),
              ),

              // ── Remaining Gallery (if any) ───────────────────────────────
              _buildRemainingGallery(context, imageUrls,
                  startIndex: (paragraphs.length ~/ 2) + 1),

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

  Widget _buildRemainingGallery(
      BuildContext context, List<String> imageUrls, {required int startIndex}) {
    if (startIndex >= imageUrls.length) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final remainingImages = imageUrls.sublist(startIndex);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 40, thickness: 1),
            Text(
              'Gallery',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.runBlue,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: remainingImages.length,
              itemBuilder: (context, index) {
                final url = remainingImages[index];
                final realIndex = startIndex + index;
                return GestureDetector(
                  onTap: () => FullScreenImageViewer.open(
                    context,
                    imageUrl: url,
                    heroTag: 'history-img-$realIndex',
                  ),
                  child: Hero(
                    tag: 'history-img-$realIndex',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drop Cap Text for the very first paragraph ──────────────────────────────
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

// ── In-article Image Component ──────────────────────────────────────────────
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
