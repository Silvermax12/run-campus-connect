import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/firebase_providers.dart';

part 'presence_service.g.dart';

/// App-wide presence tracking (WhatsApp-style).
///
/// While the app is in the foreground the signed-in user is marked online
/// and a heartbeat refreshes `lastSeenAt` every [_heartbeatInterval] so
/// peers can distinguish a live "online" from a stale flag (the chat UI
/// treats `isOnline` as genuine only when `lastSeenAt` is recent).
///
/// When the app is paused/closed the user is marked offline with a final
/// `lastSeenAt`, which becomes their "last seen" time.
class PresenceService with WidgetsBindingObserver {
  PresenceService(this._firestore);

  final FirebaseFirestore _firestore;

  static const _heartbeatInterval = Duration(seconds: 60);

  String? _uid;
  Timer? _heartbeat;
  bool _observing = false;

  /// Invoked each time the user comes online (login or app resume).
  /// Used to mark pending incoming messages as delivered (double tick).
  void Function(String uid)? onOnline;

  /// Start tracking presence for [uid]. Call after login.
  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _goOnline();
  }

  /// Stop tracking and mark the user offline. Call on logout.
  Future<void> stop() async {
    final uid = _uid;
    _uid = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    if (uid != null) {
      await _write(uid, isOnline: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _goOnline();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _goOffline();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient states (e.g. permission dialogs, app switcher peek):
        // keep the user online, like WhatsApp does.
        break;
    }
  }

  void _goOnline() {
    final uid = _uid;
    if (uid == null) return;
    unawaited(_write(uid, isOnline: true));
    onOnline?.call(uid);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      if (_uid == null) return;
      unawaited(_write(uid, isOnline: true));
    });
  }

  void _goOffline() {
    final uid = _uid;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (uid == null) return;
    unawaited(_write(uid, isOnline: false));
  }

  Future<void> _write(String uid, {required bool isOnline}) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Presence] write failed: $e');
    }
  }
}

@Riverpod(keepAlive: true)
PresenceService presenceService(Ref ref) {
  return PresenceService(ref.watch(firestoreProvider));
}
