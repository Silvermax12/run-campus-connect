import 'package:flutter/material.dart';

enum FlexibleOverlayState {
  downloading,
  paused,
  patching,
  patchFailed,
  readyToInstall,
  restartToUpdate,
}

class FlexibleOverlayData {
  const FlexibleOverlayData({
    required this.state,
    this.progressLabel = '',
    this.progress,
    this.onPrimaryAction,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final FlexibleOverlayState state;
  final String progressLabel;
  final double? progress;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
}

class FlexibleUpdateOverlay {
  FlexibleUpdateOverlay._();
  static final FlexibleUpdateOverlay instance = FlexibleUpdateOverlay._();

  OverlayEntry? _entry;
  bool _isSheetOpen = false;
  Offset? _customPosition;
  final ValueNotifier<FlexibleOverlayData> notifier = ValueNotifier(
    const FlexibleOverlayData(state: FlexibleOverlayState.downloading),
  );

  void show(BuildContext context) {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder:
          (_) => Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final safeBottom = media.viewPadding.bottom;
              final size = media.size;
              final defaultDx =
                  size.width - 72; // above create-post FAB, right side
              final defaultDy = size.height - (safeBottom + 180);
              final start = _customPosition ?? Offset(defaultDx, defaultDy);

              return Positioned(
                left: start.dx.clamp(8, size.width - 64),
                top: start.dy.clamp(
                  media.viewPadding.top + 8,
                  size.height - (safeBottom + 64),
                ),
                child: ValueListenableBuilder<FlexibleOverlayData>(
                  valueListenable: notifier,
                  builder: (context, data, _) {
                    return GestureDetector(
                      onPanUpdate: (details) {
                        final current = _customPosition ?? start;
                        _customPosition = Offset(
                          (current.dx + details.delta.dx).clamp(
                            8,
                            size.width - 64,
                          ),
                          (current.dy + details.delta.dy).clamp(
                            media.viewPadding.top + 8,
                            size.height - (safeBottom + 64),
                          ),
                        );
                        _entry?.markNeedsBuild();
                      },
                      child: FloatingActionButton.small(
                        onPressed: () => _showBottomSheet(context),
                        child: Icon(_iconForState(data.state)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }

  void clearConsumedState() {
    notifier.value = const FlexibleOverlayData(
      state: FlexibleOverlayState.downloading,
    );
    hide();
  }

  void update(FlexibleOverlayData data) {
    notifier.value = data;
  }

  IconData _iconForState(FlexibleOverlayState state) {
    switch (state) {
      case FlexibleOverlayState.downloading:
        return Icons.download;
      case FlexibleOverlayState.paused:
        return Icons.pause;
      case FlexibleOverlayState.patching:
        return Icons.hourglass_top;
      case FlexibleOverlayState.patchFailed:
        return Icons.error_outline;
      case FlexibleOverlayState.readyToInstall:
        return Icons.check_circle;
      case FlexibleOverlayState.restartToUpdate:
        return Icons.restart_alt;
    }
  }

  void _showBottomSheet(BuildContext context) {
    if (_isSheetOpen) return;
    _isSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      builder:
          (_) => SafeArea(
            child: ValueListenableBuilder<FlexibleOverlayData>(
              valueListenable: notifier,
              builder: (context, data, _) {
                final label =
                    data.progressLabel.isEmpty
                        ? _defaultLabelForState(data.state)
                        : data.progressLabel;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(label),
                      const SizedBox(height: 12),
                      if (data.progress != null) ...[
                        LinearProgressIndicator(
                          value: data.progress!.clamp(0.0, 1.0),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          if (data.state == FlexibleOverlayState.downloading &&
                              data.onPause != null)
                            TextButton(
                              onPressed: data.onPause,
                              child: const Text('Pause'),
                            ),
                          if (data.state == FlexibleOverlayState.paused &&
                              data.onResume != null)
                            TextButton(
                              onPressed: data.onResume,
                              child: const Text('Resume'),
                            ),
                          if (data.state == FlexibleOverlayState.patchFailed &&
                              data.onPrimaryAction != null)
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                data.onPrimaryAction?.call();
                              },
                              child: const Text('Retry patch'),
                            ),
                          if ((data.state == FlexibleOverlayState.downloading ||
                                  data.state == FlexibleOverlayState.paused) &&
                              data.onCancel != null)
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                data.onCancel?.call();
                              },
                              child: const Text('Cancel'),
                            ),
                          const Spacer(),
                          if (data.onPrimaryAction != null &&
                              data.state != FlexibleOverlayState.patchFailed)
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                data.onPrimaryAction?.call();
                              },
                              child: const Text('Continue'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    ).whenComplete(() {
      _isSheetOpen = false;
    });
  }

  String _defaultLabelForState(FlexibleOverlayState state) {
    switch (state) {
      case FlexibleOverlayState.downloading:
        return 'Preparing download...';
      case FlexibleOverlayState.paused:
        return 'Paused / waiting for internet...';
      case FlexibleOverlayState.patching:
        return 'Applying patch...';
      case FlexibleOverlayState.patchFailed:
        return 'Patching failed. Retry patch.';
      case FlexibleOverlayState.readyToInstall:
        return 'Ready to install update.';
      case FlexibleOverlayState.restartToUpdate:
        return 'Restart app to apply the update.';
    }
  }
}
