import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.newsItem});

  static const routeName = 'news-detail';
  static const routePath = '/news-detail';

  final Map<String, dynamic> newsItem;

  @override
  Widget build(BuildContext context) {
    final heading = newsItem['heading'] as String? ?? '';
    final imageUrl = newsItem['imageUrl'] as String? ?? '';
    final fullPost = newsItem['fullPost'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Full-size image ─────────────────────────────────────────
            if (imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () => FullScreenImageViewer.open(
                  context,
                  imageUrl: imageUrl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Heading ─────────────────────────────────────────────
                  Text(
                    heading,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.runBlue,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Full post content ───────────────────────────────────
                  Text(
                    fullPost,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
