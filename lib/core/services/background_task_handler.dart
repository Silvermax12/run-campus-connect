import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:workmanager/workmanager.dart';

import 'download_engine.dart';

const retryDownloadTaskName = 'retryDownload';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == retryDownloadTaskName) {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await DownloadEngine.instance.resume();
      }
    }
    return Future.value(true);
  });
}

@pragma('vm:entry-point')
void startForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(UpdateTaskHandler());
}

class UpdateTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BackgroundTaskHandler {
  const BackgroundTaskHandler._();

  static Future<void> initialize() async {
    await Workmanager().initialize(workmanagerCallbackDispatcher, isInDebugMode: false);
    
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'campus_connect_update_channel',
        channelName: 'App Updates',
        channelDescription: 'Shows progress for app updates.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> scheduleRetryWatchdog() async {
    await Workmanager().registerOneOffTask(
      'retryDownload_${DateTime.now().millisecondsSinceEpoch}',
      retryDownloadTaskName,
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
