import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../providers/firebase_providers.dart';
import '../services/download_engine.dart';
import '../services/patching_service.dart';
import '../services/update_service.dart';
import 'flexible_update_overlay.dart';
import '../../features/update/presentation/update_center_page.dart';
import '../../router/app_router.dart';

/// Wraps route content and runs a version check when mounted.
/// Must be used inside the router tree (e.g. ShellRoute) so context has Navigator.
/// If an update is required, shows a non-dismissible dialog.
class UpdateCheckWrapper extends ConsumerStatefulWidget {
  const UpdateCheckWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends ConsumerState<UpdateCheckWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreReadyToInstallOverlay();
    _authSub = ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
      if (user != null) {
        _checkUpdate();
      }
    });
  }

  Future<void> _restoreReadyToInstallOverlay() async {
    final consumed = await _consumeInstalledUpdateIfDetected();
    if (consumed || !mounted) return;

    final box = await Hive.openBox<dynamic>('download_engine');
    final state = Map<String, dynamic>.from(
      box.get('state') ?? <String, dynamic>{},
    );
    final isReady = state['isReadyToInstall'] == true;
    final destination = state['destination'] as String?;
    final isPaused = state['isPaused'] == true;
    final pausedByNetwork = state['pausedByNetwork'] == true;
    final downloaded = (state['downloaded'] as num?)?.toInt() ?? 0;
    final totalBytes = (state['totalBytes'] as num?)?.toInt() ?? 0;
    final progress =
        totalBytes > 0 ? (downloaded / totalBytes).clamp(0.0, 1.0) : null;
    final docs = await getApplicationDocumentsDirectory();
    final patchExists = File('${docs.path}/diff.patch').existsSync();
    if (!mounted) return;

    if (isPaused) {
      FlexibleUpdateOverlay.instance.show(context);
      FlexibleUpdateOverlay.instance.update(
        FlexibleOverlayData(
          state: FlexibleOverlayState.paused,
          progressLabel: pausedByNetwork ? 'Waiting for internet...' : 'Paused',
          progress: progress,
          onResume: () async {
            FlexibleUpdateOverlay.instance.update(
              const FlexibleOverlayData(
                state: FlexibleOverlayState.downloading,
                progressLabel: 'Resuming download...',
              ),
            );
            await DownloadEngine.instance.resume();
            await _restoreReadyToInstallOverlay();
          },
          onCancel: () => DownloadEngine.instance.cancel(),
        ),
      );
      return;
    }

    if (patchExists && progress == 1 && !isReady) {
      FlexibleUpdateOverlay.instance.show(context);
      FlexibleUpdateOverlay.instance.update(
        const FlexibleOverlayData(
          state: FlexibleOverlayState.patchFailed,
          progressLabel:
              'Patching pending or failed. Open update center to retry patch.',
          progress: 1,
        ),
      );
      return;
    }

    if (!isReady || destination == null || !File(destination).existsSync()) {
      FlexibleUpdateOverlay.instance.clearConsumedState();
      return;
    }

    FlexibleUpdateOverlay.instance.show(context);
    FlexibleUpdateOverlay.instance.update(
      FlexibleOverlayData(
        state: FlexibleOverlayState.readyToInstall,
        progressLabel: 'Update package ready to install.',
        onPrimaryAction: () => PatchingService.triggerInstall(destination),
      ),
    );
  }

  Future<bool> _consumeInstalledUpdateIfDetected() async {
    final state = await DownloadEngine.instance.readState();
    final attemptedVersion =
        state[DownloadEngine.installAttemptVersionKey] as String?;
    final attemptedBuildNumber =
        state[DownloadEngine.installAttemptBuildNumberKey] as String?;
    if ((attemptedVersion == null || attemptedVersion.isEmpty) &&
        (attemptedBuildNumber == null || attemptedBuildNumber.isEmpty)) {
      return false;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final sameVersion = attemptedVersion == packageInfo.version;
    final sameBuild = attemptedBuildNumber == packageInfo.buildNumber;
    if (sameVersion && sameBuild) {
      return false;
    }

    await DownloadEngine.instance.clearPostInstallState();
    if (!mounted) return true;
    FlexibleUpdateOverlay.instance.clearConsumedState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update installed successfully.')),
    );
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreReadyToInstallOverlay();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreReadyToInstallOverlay();
      }
    });
  }

  Future<void> _checkUpdate() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForRequiredUpdate();

      if (!mounted) return;
      if (result.majorUpdateRequired) {
        final router = ref.read(appRouterProvider);
        router.go(
          UpdateCenterPage.routePath,
          extra: {
            'packageType': result.packageType.name,
            'downloadUrl': result.selectedUrl,
            'downloadSha256': result.selectedSha256,
            'newVersion': result.minVersion,
            'currentVersion': result.currentVersion,
            'downloadSizeBytes': result.selectedSizeBytes,
          },
        );
        return;
      }

      if (result.minorPatchAvailable) {
        final updater = ShorebirdCodePush();
        await updater.downloadUpdateIfAvailable();
        if (!mounted) return;
        FlexibleUpdateOverlay.instance.show(context);
        FlexibleUpdateOverlay.instance.update(
          const FlexibleOverlayData(
            state: FlexibleOverlayState.restartToUpdate,
            progressLabel: 'Minor update ready. Restart to update.',
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[UpdateCheckWrapper] Update check failed: $e');
      debugPrint('[UpdateCheckWrapper] $stack');
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
