import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../data/institutional_providers.dart';

class MottoLogoAnthemScreen extends ConsumerWidget {
  const MottoLogoAnthemScreen({super.key});

  static const routeName = 'motto-logo-anthem';
  static const routePath = '/motto-logo-anthem';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mottoAsync = ref.watch(runMottoLogoAnthemProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Motto, Logo & Anthem'),
      ),
      body: mottoAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No data available.'));
          }

          final fullContent = data['fullContent'] as String? ?? '';
          final imageUrls =
              (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Logo Images ─────────────────────────────────────────
                if (imageUrls.isNotEmpty) ...[
                  ...imageUrls.map((url) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => FullScreenImageViewer.open(
                            context,
                            imageUrl: url,
                            heroTag: 'motto-img-$url',
                          ),
                          child: Hero(
                            tag: 'motto-img-$url',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                // ── Full Content (Motto, Colours, Anthem) ───────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_quote,
                                size: 28, color: AppTheme.runGold),
                            const SizedBox(width: 8),
                            Text(
                              'Motto, Logo & Anthem',
                              style:
                                  theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.runBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          fullContent,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
