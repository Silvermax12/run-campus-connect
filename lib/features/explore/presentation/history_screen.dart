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
      appBar: AppBar(
        title: const Text('Our History'),
      ),
      body: historyAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No history available.'));
          }

          final fullHistory = data['fullHistory'] as String? ?? '';
          final imageUrls =
              (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Images ───────────────────────────────────────────────
                if (imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final url = imageUrls[index];
                        return GestureDetector(
                          onTap: () => FullScreenImageViewer.open(
                            context,
                            imageUrl: url,
                            heroTag: 'history-img-$index',
                          ),
                          child: Hero(
                            tag: 'history-img-$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                height: 200,
                                width: 280,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Text(
                  "Redeemer's University",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.runBlue,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Full History Text ────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      fullHistory,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.7),
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
