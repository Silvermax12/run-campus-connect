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

          // New structured shape from moto,logo,anth.py:
          // {
          //   "motto_section": [...],
          //   "logo_section": { "description": "", "images": [...] },
          //   "color_identity": { "main_text": "", "details": [...] },
          //   "anthem": [...],
          //   ...
          // }

          final mottoSection =
              (data['motto_section'] as List<dynamic>? ?? []).cast<String>();
          final logoSection =
              (data['logo_section'] as Map<String, dynamic>? ?? {});
          final colorIdentity =
              (data['color_identity'] as Map<String, dynamic>? ?? {});
          final anthem =
              (data['anthem'] as List<dynamic>? ?? []).cast<String>();

          final logoImages =
              (logoSection['images'] as List<dynamic>? ?? []).cast<String>();
          final colorDetails =
              (colorIdentity['details'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();

          // Legacy fallback if new structured fields are missing
          final fullContent = data['fullContent'] as String? ?? '';
          final legacyImageUrls =
              (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
          final useLegacy = mottoSection.isEmpty &&
              logoSection.isEmpty &&
              colorIdentity.isEmpty &&
              anthem.isEmpty &&
              fullContent.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (useLegacy) ...[
                  // Old flat layout
                  if (legacyImageUrls.isNotEmpty) ...[
                    ...legacyImageUrls.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _LogoImageTile(url: url),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                ] else ...[
                  // ── 1. Motto Section ───────────────────────────────────
                  if (mottoSection.isNotEmpty)
                    _TextSectionCard(
                      title: 'Motto',
                      icon: Icons.emoji_flags,
                      lines: mottoSection,
                    ),
                  if (mottoSection.isNotEmpty) const SizedBox(height: 16),

                  // ── 2. Logo Images ─────────────────────────────────────
                  if (logoImages.isNotEmpty) ...[
                    ...logoImages.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _LogoImageTile(url: url),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── 2b. Logo Description ───────────────────────────────
                  if ((logoSection['description'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true)
                    _TextSectionCard(
                      title: 'Logo',
                      icon: Icons.image_outlined,
                      lines: [(logoSection['description'] as String).trim()],
                    ),
                  if ((logoSection['description'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true)
                    const SizedBox(height: 16),

                  // ── 3. Colour Identity ─────────────────────────────────
                  if ((colorIdentity['main_text'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true)
                    _TextSectionCard(
                      title: 'Colour Identity',
                      icon: Icons.palette_outlined,
                      lines: [(colorIdentity['main_text'] as String).trim()],
                    ),
                  if (colorDetails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...colorDetails.map(
                      (detail) => ListTile(
                        leading: detail['image_url'] is String
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      (detail['image_url'] as String).trim(),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.circle, size: 16),
                        title: Text(
                          (detail['description'] as String? ?? '').trim(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                  if ((colorIdentity['main_text'] as String?)
                              ?.trim()
                              .isNotEmpty ==
                          true ||
                      colorDetails.isNotEmpty)
                    const SizedBox(height: 16),

                  // ── 4. Anthem ──────────────────────────────────────────
                  if (anthem.isNotEmpty)
                    _TextSectionCard(
                      title: 'Anthem',
                      icon: Icons.music_note,
                      lines: anthem,
                    ),
                ],
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

class _LogoImageTile extends StatelessWidget {
  final String url;

  const _LogoImageTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _TextSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> lines;

  const _TextSectionCard({
    required this.title,
    required this.icon,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = lines.join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: AppTheme.runGold),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.runBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
