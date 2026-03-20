import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../data/institutional_providers.dart';

class VisionMissionScreen extends ConsumerWidget {
  const VisionMissionScreen({super.key});

  static const routeName = 'vision-mission';
  static const routePath = '/vision-mission';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmAsync = ref.watch(runVisionMissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision, Mission & Strategy'),
      ),
      body: vmAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No data available.'));
          }

          // JSON shape (campus_vision_mission.json):
          // {
          //   "vision": "...",
          //   "mission": "...",
          //   "overview_image": "...",
          //   "vision_strategy": [ "para1", ... ],
          //   "last_updated": "..."
          // }
          // Display order mirrors JSON field order:
          //   1. Vision
          //   2. Mission
          //   3. Overview image
          //   4. Vision Strategy paragraphs

          final vision = data['vision'] as String? ??
              data['visionStatement'] as String? ??
              '';
          final mission = data['mission'] as String? ??
              data['missionStatement'] as String? ??
              '';
          final overviewImage = data['overview_image'] as String?;

          final strategyParagraphs = <String>[];
          if (data['vision_strategy'] is List) {
            strategyParagraphs.addAll(
              (data['vision_strategy'] as List<dynamic>)
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty),
            );
          } else if (data['visionStrategy'] is String) {
            // Legacy single-string field
            final raw = data['visionStrategy'] as String;
            strategyParagraphs.addAll(
              raw
                  .split('\n')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Vision ──────────────────────────────────────────
                if (vision.isNotEmpty) ...[
                  _SectionCard(
                    icon: Icons.visibility,
                    title: 'Our Vision',
                    content: vision,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 2. Mission ─────────────────────────────────────────
                if (mission.isNotEmpty) ...[
                  _SectionCard(
                    icon: Icons.flag,
                    title: 'Our Mission',
                    content: mission,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 3. Overview Image ──────────────────────────────────
                if (overviewImage != null && overviewImage.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => FullScreenImageViewer.open(
                      context,
                      imageUrl: overviewImage,
                      heroTag: 'vm-overview-image',
                    ),
                    child: Hero(
                      tag: 'vm-overview-image',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: overviewImage,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ShimmerBox(
                            width: double.infinity,
                            height: 220,
                            borderRadius: 16,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 220,
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
                  const SizedBox(height: 24),
                ],

                // ── 4. Vision Strategy paragraphs ──────────────────────
                if (strategyParagraphs.isNotEmpty) ...[
                  _StrategySectionHeader(),
                  const SizedBox(height: 12),
                  ...strategyParagraphs.map(
                    (para) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        para,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.75,
                                  color: Colors.black87,
                                ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
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

// ── Section card (Vision / Mission) ─────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.runBlue.withValues(alpha: 0.1),
                  child: Icon(icon, color: AppTheme.runGold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.runBlue,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Strategy section header ──────────────────────────────────────────────────
class _StrategySectionHeader extends StatelessWidget {
  const _StrategySectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.runBlue.withValues(alpha: 0.1),
          child: const Icon(Icons.trending_up, color: AppTheme.runGold),
        ),
        const SizedBox(width: 12),
        Text(
          'Our Strategy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.runBlue,
              ),
        ),
      ],
    );
  }
}
