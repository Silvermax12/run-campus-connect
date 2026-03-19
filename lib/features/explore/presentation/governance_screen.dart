import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/institutional_providers.dart';

class GovernanceScreen extends ConsumerWidget {
  const GovernanceScreen({super.key});

  static const routeName = 'governance';
  static const routePath = '/governance';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final govAsync = ref.watch(runGovernanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Governance'),
        backgroundColor: AppTheme.runBlue,
        foregroundColor: Colors.white,
      ),
      body: govAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No governance info available.'));
          }

          // Shape from gov.py:
          // {
          //   "officers": [
          //     { "name": "...", "role": "...", "image_url": "..." },
          //   ],
          //   "senate": [
          //     { "name": "...", "designation": "..." },
          //   ],
          //   ...
          // }
          final officers =
              (data['officers'] as List<dynamic>? ?? []).whereType<Map>().toList();
          final senate =
              (data['senate'] as List<dynamic>? ?? []).whereType<Map>().toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // ── Leadership / Officers grid ─────────────────────
                      if (officers.isNotEmpty) ...[
                        Text(
                          'University Leadership',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.runBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _OfficersGrid(officers: officers),
                        const SizedBox(height: 32),
                      ],

                      // ── Senate Members ─────────────────────────────────
                      if (senate.isNotEmpty) ...[
                        Text(
                          'University Senate Members',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.runBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SenateTable(senate: senate),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _OfficersGrid extends StatelessWidget {
  final List<Map> officers;

  const _OfficersGrid({required this.officers});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: officers.length,
      itemBuilder: (context, index) {
        final o = officers[index];
        final name = (o['name'] as String? ?? '').trim();
        final role = (o['role'] as String? ?? '').trim();
        final imageUrl = (o['image_url'] as String? ?? '').trim();

        return Card(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: AppTheme.runBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (role.isNotEmpty)
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppTheme.runGold,
                          fontSize: 11,
                        ),
                      ),
                    if (role.isNotEmpty) const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SenateTable extends StatelessWidget {
  final List<Map> senate;

  const _SenateTable({required this.senate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(AppTheme.runBlue.withOpacity(0.1)),
        columns: const [
          DataColumn(
            label: Text(
              'Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Designation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: senate
            .map(
              (m) => DataRow(
                cells: [
                  DataCell(Text((m['name'] as String? ?? '').trim())),
                  DataCell(Text((m['designation'] as String? ?? '').trim())),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

