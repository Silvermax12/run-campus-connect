import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/background_task_handler.dart';
import '../../../core/services/download_engine.dart';
import '../../../core/services/patching_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flexible_update_overlay.dart';
import '../../home/presentation/home_screen.dart';

class UpdateCenterPage extends StatefulWidget {
  const UpdateCenterPage({
    super.key,
    required this.packageType,
    required this.downloadUrl,
    required this.downloadSha256,
    required this.newVersion,
    required this.currentVersion,
    required this.downloadSizeBytes,
  });

  static const routeName = 'update-center';
  static const routePath = '/update-center';

  final UpdatePackageType packageType;
  final String downloadUrl;
  final String downloadSha256;
  final String newVersion;
  final String currentVersion;
  final int downloadSizeBytes;

  @override
  State<UpdateCenterPage> createState() => _UpdateCenterPageState();
}

class _UpdateCenterPageState extends State<UpdateCenterPage> {
  static const _notifId = 4001;
  static const _notifChannelId = 'update_downloads';
  static const _notifChannelName = 'App update downloads';
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;
  static StreamSubscription<DownloadProgress>? _globalProgressSub;
  bool _isOffline = false;
  bool _isReadyToInstall = false;
  String? _readyApkPath;
  bool _isPatching = false;
  static const _installAttemptVersionKey = 'installAttemptVersion';
  static const _installAttemptBuildNumberKey = 'installAttemptBuildNumber';
  static const _installAttemptAtKey = 'installAttemptAt';

  bool get _usesFullApk => widget.packageType == UpdatePackageType.apk;

  String get _downloadFileName =>
      _usesFullApk ? 'full_update.apk' : 'diff.patch';

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(() => _isOffline = results.contains(ConnectivityResult.none));
    });
    _initNotifications();
    _loadInstallReadyState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initNotifications() async {
    if (_notificationsReady) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await _notifications.initialize(init);
    final android =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.requestNotificationsPermission();
    _notificationsReady = true;
  }

  Future<void> _showStateNotification(String title, String body) async {
    await _initNotifications();
    const details = AndroidNotificationDetails(
      _notifChannelId,
      _notifChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
    );
    await _notifications.show(
      _notifId,
      title,
      body,
      const NotificationDetails(android: details),
    );
  }

  Future<void> _loadInstallReadyState() async {
    final box = await Hive.openBox<dynamic>('download_engine');
    final state = Map<String, dynamic>.from(
      box.get('state') ?? <String, dynamic>{},
    );
    final destination = state['destination'] as String?;
    final isReady = state['isReadyToInstall'] == true;
    final downloaded = (state['downloaded'] as num?)?.toInt() ?? 0;
    final totalBytes = (state['totalBytes'] as num?)?.toInt() ?? 0;
    final isPaused = state['isPaused'] == true;
    final pausedByNetwork = state['pausedByNetwork'] == true;
    if (!mounted) return;
    if (isPaused) {
      final progress = totalBytes > 0 ? (downloaded / totalBytes) : null;
      FlexibleUpdateOverlay.instance.show(context);
      FlexibleUpdateOverlay.instance.update(
        FlexibleOverlayData(
          state: FlexibleOverlayState.paused,
          progressLabel: pausedByNetwork ? 'Waiting for internet...' : 'Paused',
          progress: progress,
          onResume: _resumeDownload,
          onCancel: () => DownloadEngine.instance.cancel(),
        ),
      );
    }
    final readyExists =
        destination != null &&
        destination.isNotEmpty &&
        File(destination).existsSync();
    setState(() {
      _isReadyToInstall = isReady && readyExists;
      _readyApkPath = readyExists ? destination : null;
    });
  }

  Future<void> _triggerInstallIfReady() async {
    final apkPath = _readyApkPath;
    if (apkPath == null || apkPath.isEmpty) return;
    if (!File(apkPath).existsSync()) {
      await _loadInstallReadyState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Install package missing. Please download again.'),
        ),
      );
      return;
    }
    await _triggerInstallWithTracking(apkPath);
  }

  Future<void> _retryPatchFromExistingDiff() async {
    if (_isPatching) return;
    final docs = await getApplicationDocumentsDirectory();
    final patchPath = '${docs.path}/diff.patch';
    if (!File(patchPath).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patch file not found. Please download again.'),
        ),
      );
      return;
    }
    await _applyPatchAndPrepareInstall(patchPath: patchPath);
  }

  Future<void> _applyPatchAndPrepareInstall({required String patchPath}) async {
    if (_isPatching) return;
    _isPatching = true;
    try {
      FlexibleUpdateOverlay.instance.update(
        const FlexibleOverlayData(
          state: FlexibleOverlayState.patching,
          progressLabel: 'Applying patch...',
          progress: null,
        ),
      );
      await _showStateNotification(
        'Applying update',
        'Patching downloaded file...',
      );

      final docs = await getApplicationDocumentsDirectory();
      final patched = await PatchingService.applyPatch(
        patchFilePath: patchPath,
        outputApkPath: '${docs.path}/combined_update.apk',
      );
      final box = await Hive.openBox<dynamic>('download_engine');
      final state = Map<String, dynamic>.from(
        box.get('state') ?? <String, dynamic>{},
      );
      final persistedTotalBytes = (state['totalBytes'] as num?)?.toInt() ?? 0;
      state['destination'] = patched.path;
      state['downloaded'] = persistedTotalBytes;
      state['totalBytes'] = persistedTotalBytes;
      state['isReadyToInstall'] = true;
      state['isDownloading'] = false;
      state['isPaused'] = false;
      state['pausedByNetwork'] = false;
      state.remove(_installAttemptVersionKey);
      state.remove(_installAttemptBuildNumberKey);
      state.remove(_installAttemptAtKey);
      await box.put('state', state);
      if (mounted) {
        setState(() {
          _isReadyToInstall = true;
          _readyApkPath = patched.path;
        });
      }
      FlexibleUpdateOverlay.instance.update(
        FlexibleOverlayData(
          state: FlexibleOverlayState.readyToInstall,
          progressLabel: 'Ready to install',
          progress: 1,
          onPrimaryAction: () => _triggerInstallWithTracking(patched.path),
        ),
      );
      await _showStateNotification(
        'Update Downloaded',
        'Tap to install the update.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patch applied successfully. Your update is ready to install.',
          ),
        ),
      );
    } catch (e) {
      FlexibleUpdateOverlay.instance.update(
        FlexibleOverlayData(
          state: FlexibleOverlayState.patchFailed,
          progressLabel: 'Patching failed. Retry patch.',
          progress: 1,
          onPrimaryAction: _retryPatchFromExistingDiff,
          onCancel: () => DownloadEngine.instance.cancel(),
        ),
      );
      await _showStateNotification(
        'Patch failed',
        'Patch could not be applied. Open update panel and retry patch.',
      );
      rethrow;
    } finally {
      _isPatching = false;
    }
  }

  Future<void> _prepareDownloadedApkInstall({required String apkPath}) async {
    final apkFile = File(apkPath);
    if (!apkFile.existsSync()) {
      throw Exception('Downloaded APK file not found at $apkPath');
    }

    final box = await Hive.openBox<dynamic>('download_engine');
    final state = Map<String, dynamic>.from(
      box.get('state') ?? <String, dynamic>{},
    );
    state['destination'] = apkFile.path;
    state['isReadyToInstall'] = true;
    state['isDownloading'] = false;
    state['isPaused'] = false;
    state['pausedByNetwork'] = false;
    state.remove(_installAttemptVersionKey);
    state.remove(_installAttemptBuildNumberKey);
    state.remove(_installAttemptAtKey);
    await box.put('state', state);

    if (mounted) {
      setState(() {
        _isReadyToInstall = true;
        _readyApkPath = apkFile.path;
      });
    }
    FlexibleUpdateOverlay.instance.update(
      FlexibleOverlayData(
        state: FlexibleOverlayState.readyToInstall,
        progressLabel: 'Ready to install',
        progress: 1,
        onPrimaryAction: () => _triggerInstallWithTracking(apkFile.path),
      ),
    );
    await _showStateNotification(
      'Update Downloaded',
      'Tap to install the update.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Update downloaded. Your update is ready to install.'),
      ),
    );
  }

  Future<void> _triggerInstallWithTracking(String apkPath) async {
    await _recordInstallAttemptMetadata();
    await PatchingService.triggerInstall(apkPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Installer opened. Complete installation to finish updating.',
        ),
      ),
    );
  }

  Future<void> _recordInstallAttemptMetadata() async {
    final info = await PackageInfo.fromPlatform();
    final box = await Hive.openBox<dynamic>('download_engine');
    final state = Map<String, dynamic>.from(
      box.get('state') ?? <String, dynamic>{},
    );
    state[_installAttemptVersionKey] = info.version;
    state[_installAttemptBuildNumberKey] = info.buildNumber;
    state[_installAttemptAtKey] = DateTime.now().toIso8601String();
    await box.put('state', state);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  Future<void> _startDownload() async {
    if (_isOffline) return;
    if (widget.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usesFullApk
                ? 'Full update URL is missing. Please try again later.'
                : 'Patch update URL is missing. Please try again later.',
          ),
        ),
      );
      return;
    }

    final onMobileData = (await Connectivity().checkConnectivity()).contains(
      ConnectivityResult.mobile,
    );
    if (onMobileData && widget.downloadSizeBytes > 50 * 1024 * 1024) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Large update download'),
              content: const Text(
                'This update is larger than 50MB and you are on mobile data. Continue anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      if (confirmed != true) return;
    }

    if (!mounted) return;
    FlexibleUpdateOverlay.instance.show(context);
    FlexibleUpdateOverlay.instance.update(
      FlexibleOverlayData(
        state: FlexibleOverlayState.downloading,
        progressLabel: 'Preparing download...',
        progress: 0,
        onPause: () async {
          await DownloadEngine.instance.pause(pausedByNetwork: false);
          FlexibleUpdateOverlay.instance.update(
            FlexibleOverlayData(
              state: FlexibleOverlayState.paused,
              progressLabel: 'Paused',
              onResume: _resumeDownload,
              onCancel: () => DownloadEngine.instance.cancel(),
            ),
          );
        },
        onCancel: () => DownloadEngine.instance.cancel(),
      ),
    );
    await _globalProgressSub?.cancel();
    _globalProgressSub = DownloadEngine.instance.progressStream.listen((
      progress,
    ) {
      final progressValue =
          progress.totalBytes == 0
              ? 0.0
              : (progress.bytesDownloaded / progress.totalBytes).clamp(
                0.0,
                1.0,
              );
      final pct =
          progress.totalBytes == 0
              ? 0
              : ((progress.bytesDownloaded / progress.totalBytes) * 100)
                  .round();
      FlexibleUpdateOverlay.instance.update(
        FlexibleOverlayData(
          state:
              progress.waitingForInternet
                  ? FlexibleOverlayState.paused
                  : FlexibleOverlayState.downloading,
          progressLabel:
              progress.waitingForInternet
                  ? 'Waiting for internet...'
                  : 'Downloading $pct% • ${(progress.speedBps / 1024).toStringAsFixed(1)} KB/s • ETA ${progress.smoothedEta?.inSeconds ?? '--'}s',
          progress: progressValue,
          onPause: () async {
            await DownloadEngine.instance.pause(pausedByNetwork: false);
            FlexibleUpdateOverlay.instance.update(
              FlexibleOverlayData(
                state: FlexibleOverlayState.paused,
                progressLabel: 'Paused',
                progress: progressValue,
                onResume: _resumeDownload,
                onCancel: () => DownloadEngine.instance.cancel(),
              ),
            );
          },
          onResume: _resumeDownload,
          onCancel: () => DownloadEngine.instance.cancel(),
        ),
      );
    });

    if (!mounted) return;
    // Do not pop directly here; this page was opened via go_router `go()`,
    // and popping can leave navigator in a locked/disposed transition state.
    GoRouter.of(context).go(HomeScreen.routePath);

    try {
      await DownloadEngine.instance.start(
        url: widget.downloadUrl,
        destinationFileName: _downloadFileName,
        expectedSha256: widget.downloadSha256,
        readyToInstallOnComplete: _usesFullApk,
      );
      final downloadedPath = await _completedDownloadPath();
      if (downloadedPath == null) return;
      if (_usesFullApk) {
        await _prepareDownloadedApkInstall(apkPath: downloadedPath);
      } else {
        await _applyPatchAndPrepareInstall(patchPath: downloadedPath);
      }
    } catch (e) {
      final errorText = e.toString();
      final errorLower = errorText.toLowerCase();
      if (errorLower.contains('cancel') || errorLower.contains('paused')) {
        // The download was intentionally paused or cancelled.
        // Do not display an error message.
        return;
      }

      await BackgroundTaskHandler.scheduleRetryWatchdog();
      final box = await Hive.openBox<dynamic>('download_engine');
      final state = Map<String, dynamic>.from(
        box.get('state') ?? <String, dynamic>{},
      );
      final downloaded = (state['downloaded'] as num?)?.toInt() ?? 0;
      final totalBytes = (state['totalBytes'] as num?)?.toInt() ?? 0;
      final progressValue =
          totalBytes > 0 ? (downloaded / totalBytes).clamp(0.0, 1.0) : null;
      final pausedByNetwork = state['pausedByNetwork'] == true || _isOffline;
      final looksLikeNetworkIssue =
          pausedByNetwork ||
          errorText.contains('SocketException') ||
          errorText.contains('Connection') ||
          errorText.contains('timed out');
      final looksLikePatchIssue =
          !_usesFullApk &&
          (errorText.contains('hpatchz failed') ||
              errorText.contains('Patch file not found') ||
              errorText.contains('Split APK install detected') ||
              errorText.contains('hpatchz binary missing'));

      if (looksLikePatchIssue) {
        FlexibleUpdateOverlay.instance.update(
          FlexibleOverlayData(
            state: FlexibleOverlayState.patchFailed,
            progress: progressValue ?? 1,
            progressLabel: 'Patching failed. Retry patch.',
            onPrimaryAction: _retryPatchFromExistingDiff,
            onCancel: () => DownloadEngine.instance.cancel(),
          ),
        );
      } else {
        FlexibleUpdateOverlay.instance.update(
          FlexibleOverlayData(
            state: FlexibleOverlayState.paused,
            progress: progressValue,
            progressLabel:
                looksLikeNetworkIssue
                    ? 'Waiting for internet...'
                    : 'Download failed. Tap Resume to retry.',
            onResume: _resumeDownload,
            onCancel: () => DownloadEngine.instance.cancel(),
          ),
        );
      }
      await _showStateNotification(
        looksLikeNetworkIssue ? 'Download paused' : 'Update error',
        looksLikeNetworkIssue
            ? 'Waiting for internet connection.'
            : (looksLikePatchIssue
                ? 'Patching failed. Open update panel and retry patch.'
                : 'Update download failed. Open update panel to retry.'),
      );
    }
  }

  Future<void> _resumeDownload() async {
    FlexibleUpdateOverlay.instance.update(
      FlexibleOverlayData(
        state: FlexibleOverlayState.downloading,
        progressLabel: 'Resuming download...',
        onPause: () => DownloadEngine.instance.pause(pausedByNetwork: false),
        onCancel: () => DownloadEngine.instance.cancel(),
      ),
    );
    await DownloadEngine.instance.resume();
    await _loadInstallReadyState();
  }

  Future<String?> _completedDownloadPath() async {
    final state = await DownloadEngine.instance.readState();
    if (state['isPaused'] == true || state['isDownloading'] == true) {
      return null;
    }

    final destination = state['destination'] as String?;
    if (destination == null || destination.isEmpty) return null;

    final file = File(destination);
    return file.existsSync() ? file.path : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/run_logo.jpg',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              Text(
                'Update Center',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.runBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildVersionComparison(),
              const SizedBox(height: 32),
              if (_isOffline) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    'No internet connection. Reconnect to continue update.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isReadyToInstall
                          ? _triggerInstallIfReady
                          : (_isOffline ? null : _startDownload),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.runGold,
                    foregroundColor: AppTheme.runBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isReadyToInstall ? 'Install update' : 'Download update',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Update size: ${_formatBytes(widget.downloadSizeBytes)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              if (_isReadyToInstall) ...[
                const SizedBox(height: 12),
                Text(
                  'Update package is already downloaded. Tap Install update to continue.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionComparison() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                'Current',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                widget.currentVersion,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.runBlue,
                ),
              ),
            ],
          ),
          Icon(Icons.arrow_forward, color: Colors.grey[400]),
          Column(
            children: [
              Text(
                'New',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                widget.newVersion,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.runGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
