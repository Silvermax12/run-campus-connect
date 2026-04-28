import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/background_task_handler.dart';
import 'firebase_options.dart';

/// Top-level background handler — must be outside any class and annotated.
/// FCM calls this when the app is in the background or terminated.
/// The `notification` payload is shown automatically by the OS;
/// this function only handles any background data processing.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised before any Firebase calls in the isolate.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await BackgroundTaskHandler.initialize();
  await _preventGhostPatches();

  // Register the background message handler before runApp.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: App()));
}

Future<void> _preventGhostPatches() async {
  final prefs = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;
  final lastInstalledVersion = prefs.getString('last_installed_version');
  if (lastInstalledVersion != null && lastInstalledVersion != currentVersion) {
    // shorebird_code_push v1.x does not expose clearPatch(), so we only
    // track version transitions here to avoid stale state assumptions.
  }
  await prefs.setString('last_installed_version', currentVersion);
}
