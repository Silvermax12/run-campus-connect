import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class UpdateCenterPage extends StatefulWidget {
  const UpdateCenterPage({
    super.key,
    required this.updateUrl,
    required this.newVersion,
    required this.currentVersion,
  });

  static const routeName = 'update-center';
  static const routePath = '/update-center';

  final String updateUrl;
  final String newVersion;
  final String currentVersion;

  @override
  State<UpdateCenterPage> createState() => _UpdateCenterPageState();
}

class _UpdateCenterPageState extends State<UpdateCenterPage>
    with WidgetsBindingObserver {
  static const _downloadNotificationId = 4001;
  static const _downloadChannelId = 'ota_update_downloads';
  static const _downloadChannelName = 'App updates';
  static const _downloadChannelDescription =
      'Shows app update download progress';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  OtaEvent? _currentEvent;
  bool _hasStarted = false;
  bool _wasInterruptedByBackground = false;
  bool _isOffline = false;
  int _retryAttempt = 0;
  int? _nextRetryInSeconds;
  Timer? _retryTimer;
  StreamSubscription<OtaEvent>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _watchConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isDownloadInProgress()) {
      OtaUpdate().cancel();
      _cancelScheduledRetry();
      setState(() {
        _wasInterruptedByBackground = true;
        _currentEvent = OtaEvent(
          OtaStatus.CANCELED,
          'Download paused in background. Reopen app and retry.',
        );
      });
      _showStateNotification(
        title: 'Update paused',
        body: 'Download paused because the app moved to background.',
      );
    }
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initSettings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _notificationsInitialized = true;
  }

  Future<void> _watchConnectivity() async {
    Future<void> refreshConnectivity() async {
      final results = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
    }

    await refreshConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _startDownload({bool isAutoRetry = false}) async {
    if (!Platform.isAndroid) {
      await _openStoreLink();
      return;
    }

    final permission = Permission.requestInstallPackages;
    var status = await permission.status;

    if (!status.isGranted) {
      status = await permission.request();
      if (!status.isGranted) {
        if (mounted && !isAutoRetry) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Install permission is required to update the app. '
                'Please grant it in Settings.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    if (_isOffline) {
      if (mounted && !isAutoRetry) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please reconnect and try again.'),
          ),
        );
      }
      return;
    }

    _cancelScheduledRetry();
    setState(() {
      _hasStarted = true;
      _wasInterruptedByBackground = false;
      _currentEvent = null;
      _nextRetryInSeconds = null;
      if (!isAutoRetry) {
        _retryAttempt = 0;
      }
    });
    _showProgressNotification(progress: 0, indeterminate: true);

    try {
      _subscription = OtaUpdate()
          .execute(
            widget.updateUrl,
            destinationFilename: 'run_campus_connect.apk',
          )
          .listen((OtaEvent event) {
        if (mounted) {
          setState(() => _currentEvent = event);
        }
        _handleEventNotifications(event);
      }, onError: (Object error) {
        if (mounted) {
          setState(() {
            _currentEvent = OtaEvent(OtaStatus.DOWNLOAD_ERROR, error.toString());
          });
        }
        _scheduleAutoRetry();
        _showStateNotification(
          title: 'Update failed',
          body: 'Download failed. Check network and try again.',
        );
      }, onDone: () {
        if (_currentEvent?.status != OtaStatus.INSTALLATION_DONE) {
          _notifications.cancel(_downloadNotificationId);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentEvent = OtaEvent(OtaStatus.INTERNAL_ERROR, e.toString());
        });
      }
      _scheduleAutoRetry();
      _showStateNotification(
        title: 'Update failed',
        body: 'Could not start update download.',
      );
    }
  }

  void _handleEventNotifications(OtaEvent event) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        _cancelScheduledRetry();
        final n = int.tryParse(event.value ?? '');
        _showProgressNotification(
          progress: n ?? 0,
          indeterminate: n == null,
        );
        break;
      case OtaStatus.INSTALLING:
        _cancelScheduledRetry();
        _showStateNotification(
          title: 'Installing update',
          body: 'Downloaded. Waiting for install confirmation.',
        );
        break;
      case OtaStatus.INSTALLATION_DONE:
        _cancelScheduledRetry();
        _showStateNotification(
          title: 'Update complete',
          body: 'Installation finished successfully.',
        );
        break;
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.INTERNAL_ERROR:
        _scheduleAutoRetry();
        _showStateNotification(
          title: 'Update failed',
          body: 'Network issue. Auto-retry will run shortly.',
        );
        break;
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.ALREADY_RUNNING_ERROR:
        _cancelScheduledRetry();
        _showStateNotification(
          title: 'Update failed',
          body: 'Download/installation failed. Retry from Update Center.',
        );
        break;
      case OtaStatus.CANCELED:
        _cancelScheduledRetry();
        _showStateNotification(
          title: 'Update canceled',
          body: event.value ?? 'Download canceled.',
        );
        break;
    }
  }

  void _scheduleAutoRetry() {
    if (!mounted || _isOffline) return;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached ||
        lifecycleState == AppLifecycleState.inactive) {
      return;
    }

    if (_retryTimer?.isActive == true) return;
    if (_retryAttempt >= 5) return;

    _retryAttempt += 1;
    final delaySeconds = [2, 4, 8, 16, 30][_retryAttempt - 1];

    setState(() {
      _nextRetryInSeconds = delaySeconds;
    });

    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _startDownload(isAutoRetry: true);
    });
  }

  void _cancelScheduledRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (mounted && _nextRetryInSeconds != null) {
      setState(() {
        _nextRetryInSeconds = null;
      });
    }
  }

  Future<void> _showProgressNotification({
    required int progress,
    required bool indeterminate,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelDescription: _downloadChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: indeterminate ? 0 : progress.clamp(0, 100),
      indeterminate: indeterminate,
    );

    await _notifications.show(
      _downloadNotificationId,
      'Downloading update',
      indeterminate ? 'Preparing download...' : 'Downloading... $progress%',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showStateNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelDescription: _downloadChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
      onlyAlertOnce: true,
    );

    await _notifications.show(
      _downloadNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _openStoreLink() async {
    final uri = Uri.parse(widget.updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: ${widget.updateUrl}')),
        );
      }
    }
  }

  String _statusText() {
    final event = _currentEvent;
    if (event == null) {
      return _hasStarted ? 'Preparing...' : '';
    }

    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final pct = event.value;
        return pct != null && pct.isNotEmpty
            ? 'Downloading... $pct'
            : 'Downloading...';
      case OtaStatus.INSTALLING:
        return 'Ready to Install';
      case OtaStatus.INSTALLATION_DONE:
        return 'Installation complete';
      case OtaStatus.DOWNLOAD_ERROR:
        if (_nextRetryInSeconds != null) {
          return 'Download failed. Retrying in ${_nextRetryInSeconds}s '
              '(attempt $_retryAttempt/5)...';
        }
        return 'Download failed: ${event.value ?? "Unknown error"}';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        return 'Permission denied. Please grant install permission.';
      case OtaStatus.INSTALLATION_ERROR:
        return 'Installation failed: ${event.value ?? "Unknown error"}';
      case OtaStatus.CHECKSUM_ERROR:
        return 'File verification failed';
      case OtaStatus.INTERNAL_ERROR:
        if (_nextRetryInSeconds != null) {
          return 'Temporary error. Retrying in ${_nextRetryInSeconds}s '
              '(attempt $_retryAttempt/5)...';
        }
        return 'Error: ${event.value ?? "Unknown error"}';
      case OtaStatus.ALREADY_RUNNING_ERROR:
        return 'Update already in progress';
      case OtaStatus.CANCELED:
        if (_wasInterruptedByBackground) {
          return 'Download paused in background. Keep app open and retry.';
        }
        return 'Download canceled';
    }
  }

  double? _progressValue() {
    final event = _currentEvent;
    if (event == null || event.status != OtaStatus.DOWNLOADING) return null;
    final pct = event.value;
    if (pct == null || pct.isEmpty) return null;
    final n = int.tryParse(pct);
    if (n == null) return null;
    return n / 100.0;
  }

  bool _showProgressBar() {
    if (!_hasStarted) return false;
    final event = _currentEvent;
    if (event == null) return true;
    return event.status == OtaStatus.DOWNLOADING ||
        event.status == OtaStatus.INSTALLING;
  }

  bool _isDownloadInProgress() {
    final event = _currentEvent;
    if (!_hasStarted) return false;
    if (event == null) return true;
    return event.status == OtaStatus.DOWNLOADING ||
        event.status == OtaStatus.INSTALLING;
  }

  bool _isError() {
    final event = _currentEvent;
    if (event == null) return false;
    return event.status == OtaStatus.DOWNLOAD_ERROR ||
        event.status == OtaStatus.INSTALLATION_ERROR ||
        event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR ||
        event.status == OtaStatus.CHECKSUM_ERROR ||
        event.status == OtaStatus.INTERNAL_ERROR;
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

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
                      (_hasStarted && !_isError()) || _isOffline ? null : _startDownload,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.runGold,
                    foregroundColor: AppTheme.runBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isAndroid ? 'Download & Install' : 'Update via App Store',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_showProgressBar()) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: _progressValue(),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.runGold),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
              if (_statusText().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _statusText(),
                  style: TextStyle(
                    fontSize: 14,
                    color: _isError() ? Colors.red : Colors.grey[700],
                  ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
