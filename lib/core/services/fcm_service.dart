import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/firebase_providers.dart';
import '../../features/profile/domain/user_profile.dart';

part 'fcm_service.g.dart';

// ---------------------------------------------------------------------------
// Android notification channel
// ---------------------------------------------------------------------------
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'campus_connect_channel',
  'Campus Connect Notifications',
  description: 'RUN Campus Connect push notifications',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ---------------------------------------------------------------------------
// Background handler — must be a top-level function
// ---------------------------------------------------------------------------
// This is registered in main.dart via FirebaseMessaging.onBackgroundMessage().
// FCM automatically shows the notification from the `notification` payload
// when the app is in the background/terminated, so no extra work is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// FcmService
// ---------------------------------------------------------------------------

/// Manages the full FCM lifecycle: permissions, token storage, topic
/// subscriptions, foreground message display, and background tap routing.
class FcmService {
  FcmService(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Call once after the user logs in.
  /// [profile] is used to subscribe to faculty/department topics.
  Future<void> initialize(String uid, UserProfile? profile) async {
    if (_initialized) return;
    _initialized = true;

    await _setupLocalNotifications();
    await requestPermission();
    await _saveAndWatchToken(uid);
    await _subscribeToTopics(profile);
    _listenForeground();
    _handleInitialMessage();
    _listenOnMessageOpenedApp();
  }

  /// Requests Android 13+ notification permission.
  /// Safe to call multiple times — only prompts when not yet granted.
  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[FCM] Permission status: ${settings.authorizationStatus}');
  }

  /// Returns the current permission status without prompting.
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Call when the user's profile changes (faculty/dept) to re-subscribe topics.
  Future<void> updateTopicSubscriptions(
      UserProfile? oldProfile, UserProfile? newProfile) async {
    if (oldProfile != null && oldProfile.faculty.isNotEmpty) {
      await _messaging
          .unsubscribeFromTopic('faculty_${oldProfile.faculty}');
    }
    if (oldProfile != null && oldProfile.department.isNotEmpty) {
      await _messaging
          .unsubscribeFromTopic('department_${oldProfile.department}');
    }
    await _subscribeToTopics(newProfile);
  }

  /// Call on logout to clean the token from Firestore and unsubscribe topics.
  Future<void> onLogout(String uid, UserProfile? profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (_) {}
    await _messaging.unsubscribeFromTopic('global');
    if (profile != null && profile.faculty.isNotEmpty) {
      await _messaging
          .unsubscribeFromTopic('faculty_${profile.faculty}');
    }
    if (profile != null && profile.department.isNotEmpty) {
      await _messaging
          .unsubscribeFromTopic('department_${profile.department}');
    }
    await _messaging.deleteToken();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _setupLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(initSettings);

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Needed so FCM foreground messages can show heads-up notifications
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _saveAndWatchToken(String uid) async {
    // Get current token and save
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);

    // Watch for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  Future<void> _subscribeToTopics(UserProfile? profile) async {
    await _messaging.subscribeToTopic('global');
    if (profile != null && profile.faculty.isNotEmpty) {
      await _messaging.subscribeToTopic('faculty_${profile.faculty}');
    }
    if (profile != null && profile.department.isNotEmpty) {
      await _messaging.subscribeToTopic('department_${profile.department}');
    }
    debugPrint('[FCM] Topic subscriptions updated');
  }

  /// Shows a local heads-up notification while the app is in the foreground.
  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.messageId}');
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
            ),
          ),
          payload: _encodePayload(message.data),
        );
      }
    });
  }

  /// Handles taps when the app is launched from a terminated state.
  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _routeFromMessage(message);
    }
  }

  /// Handles taps when the app is in the background (not terminated).
  void _listenOnMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
  }

  /// Routes to the correct screen based on the message `data` payload.
  /// Navigation is done imperatively so this works from any state.
  void _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    debugPrint('[FCM] Routing from message, type=$type data=$data');

    // Navigation is handled by emitting a state change that the router listens
    // to via `_pendingRoute`. The router (app_router or shell) reads this.
    // For now we store the pending route; integrate with your go_router below.
    if (type == 'chat') {
      final targetUserId = data['targetUserId'] as String?;
      if (targetUserId != null) {
        // TODO: navigate using go_router:
        // router.push('/chat/$targetUserId');
        debugPrint('[FCM] Should navigate to /chat/$targetUserId');
      }
    } else if (type == 'broadcast') {
      // TODO: navigate using go_router:
      // router.push('/notifications');
      debugPrint('[FCM] Should navigate to /notifications');
    }
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }
}

@Riverpod(keepAlive: true)
FcmService fcmService(Ref ref) {
  return FcmService(
    ref.watch(firebaseMessagingProvider),
    ref.watch(firestoreProvider),
  );
}
