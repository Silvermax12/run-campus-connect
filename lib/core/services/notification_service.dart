import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';

part 'notification_service.g.dart';

/// Secure HTTP client that calls the Vercel serverless notification gateway.
///
/// Authentication is done via the caller's Firebase ID Token (JWT), which is
/// verified server-side with Firebase Admin SDK — no shared secrets in the app.
class NotificationService {
  NotificationService(this._auth);

  final FirebaseAuth _auth;

  static final Uri _endpoint =
      Uri.parse('${AppConfig.vercelBaseUrl}/api/send-notification');

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends a push notification to a specific user's device for a chat message.
  ///
  /// The Vercel function will:
  ///   1. Verify the caller's ID token
  ///   2. Check if the recipient has muted the sender
  ///   3. Look up the recipient's FCM token from Firestore
  ///   4. Send the push via Firebase Admin SDK
  Future<void> sendChatNotification({
    required String recipientUid,
    required String senderName,
    required String messagePreview,
    required String chatId,
    required String targetUserId,
  }) async {
    await _post({
      'type': 'chat',
      'recipientUid': recipientUid,
      'title': senderName,
      'body': messagePreview,
      'data': {
        'type': 'chat',
        'chatId': chatId,
        'targetUserId': targetUserId,
      },
    });
  }

  /// Sends a broadcast notification to an FCM topic.
  ///
  /// [topic] should be one of: 'global', 'faculty_{id}', 'department_{id}'.
  Future<void> sendBroadcastNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    await _post({
      'type': 'broadcast',
      'topic': topic,
      'title': title,
      'body': body,
      'data': {'type': 'broadcast'},
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String?> _getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[NotificationService] Failed to get ID token: $e');
      return null;
    }
  }

  Future<void> _post(Map<String, dynamic> body) async {
    final idToken = await _getIdToken();
    if (idToken == null) {
      debugPrint('[NotificationService] No authenticated user — skipping push.');
      return;
    }

    try {
      final response = await http.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        debugPrint(
            '[NotificationService] Non-200 response: ${response.statusCode} — ${response.body}');
      } else {
        debugPrint('[NotificationService] Push sent: ${response.body}');
      }
    } catch (e) {
      // Swallow errors so a failed push never disrupts the chat UX.
      debugPrint('[NotificationService] HTTP error: $e');
    }
  }
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService(FirebaseAuth.instance);
}
