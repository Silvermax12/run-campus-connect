import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../data/institutional_providers.dart';

class GovernanceScreen extends ConsumerWidget {
  const GovernanceScreen({super.key});

  static const routeName = 'governance';
  static const routePath = '/governance';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final governanceAsync = ref.watch(runGovernanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Governance'),
      ),
      body: governanceAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(
                child: Text('No governance info available.'));
          }

          final fullContent = data['fullContent'] as String? ?? '';
          final imageUrls =
              (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'University Leadership',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.runBlue,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Profile Photos ──────────────────────────────────────
                if (imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 120,
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
                            heroTag: 'gov-img-$index',
                          ),
                          child: Hero(
                            tag: 'gov-img-$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Full Content ────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      fullContent,
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
