import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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

          final vision = data['visionStatement'] as String? ?? '';
          final mission = data['missionStatement'] as String? ?? '';
          final strategy = data['visionStrategy'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Vision ───────────────────────────────────────────────
                _sectionCard(
                  context,
                  icon: Icons.visibility,
                  title: 'Our Vision',
                  content: vision,
                ),
                const SizedBox(height: 16),

                // ── Mission ──────────────────────────────────────────────
                _sectionCard(
                  context,
                  icon: Icons.flag,
                  title: 'Our Mission',
                  content: mission,
                ),
                const SizedBox(height: 16),

                // ── Strategy ─────────────────────────────────────────────
                _sectionCard(
                  context,
                  icon: Icons.trending_up,
                  title: 'Our Strategy',
                  content: strategy,
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

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
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
