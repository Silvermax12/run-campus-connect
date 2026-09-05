import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_service.g.dart';

abstract final class AnalyticsEvents {
  static const createPost = 'create_post';
  static const sendMessage = 'send_message';
  static const directorySearch = 'directory_search';
  static const updateProfile = 'update_profile';
  static const likePost = 'like_post';
  static const commentPost = 'comment_post';
  static const viewFeed = 'view_feed';
  static const viewProfile = 'view_profile';
  static const openChat = 'open_chat';
}

/// Wraps [FirebaseAnalytics] for core feature adoption events.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics, bool noop = false})
      : _noop = noop,
        _analytics = noop ? null : (analytics ?? FirebaseAnalytics.instance);

  static final AnalyticsService noop = AnalyticsService(noop: true);

  final FirebaseAnalytics? _analytics;
  final bool _noop;

  /// Sets the user ID for all subsequent events to enable per-user tracking.
  Future<void> setUserId(String? uid) async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.setUserId(id: uid);
    } catch (e) {
      debugPrint('[AnalyticsService] setUserId failed: $e');
    }
  }

  // ── WRITES ─────────────────────────────────────────────────────────────────

  Future<void> logCreatePost() async {
    final analytics = _analytics;
    if (_noop || analytics == null) return;
    try {
      await analytics.logEvent(name: AnalyticsEvents.createPost);
      await analytics.setUserProperty(name: 'engaged_posting', value: 'true');
    } catch (e) {
      debugPrint('[AnalyticsService] logCreatePost failed: $e');
    }
  }

  Future<void> logSendMessage() async {
    final analytics = _analytics;
    if (_noop || analytics == null) return;
    try {
      await analytics.logEvent(name: AnalyticsEvents.sendMessage);
      await analytics.setUserProperty(name: 'engaged_messaging', value: 'true');
    } catch (e) {
      debugPrint('[AnalyticsService] logSendMessage failed: $e');
    }
  }

  Future<void> logUpdateProfile() async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(name: AnalyticsEvents.updateProfile);
    } catch (e) {
      debugPrint('[AnalyticsService] logUpdateProfile failed: $e');
    }
  }

  Future<void> logLikePost() async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(name: AnalyticsEvents.likePost);
    } catch (e) {
      debugPrint('[AnalyticsService] logLikePost failed: $e');
    }
  }

  Future<void> logCommentPost() async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(name: AnalyticsEvents.commentPost);
    } catch (e) {
      debugPrint('[AnalyticsService] logCommentPost failed: $e');
    }
  }

  // ── READS & SEARCH ─────────────────────────────────────────────────────────

  Future<void> logDirectorySearch({required int resultCount}) async {
    final analytics = _analytics;
    if (_noop || analytics == null) return;
    try {
      await analytics.logEvent(
        name: AnalyticsEvents.directorySearch,
        parameters: {'result_count': resultCount},
      );
      await analytics.setUserProperty(name: 'engaged_search', value: 'true');
    } catch (e) {
      debugPrint('[AnalyticsService] logDirectorySearch failed: $e');
    }
  }

  Future<void> logViewFeed({required String feedType}) async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.viewFeed,
        parameters: {'feed_type': feedType},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logViewFeed failed: $e');
    }
  }

  Future<void> logViewProfile({required String viewedUserId}) async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.viewProfile,
        parameters: {'viewed_user_id': viewedUserId},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logViewProfile failed: $e');
    }
  }

  Future<void> logOpenChat({required String targetUserId}) async {
    if (_noop || _analytics == null) return;
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.openChat,
        parameters: {'target_user_id': targetUserId},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logOpenChat failed: $e');
    }
  }
}


@Riverpod(keepAlive: true)
AnalyticsService analyticsService(AnalyticsServiceRef ref) {
  return AnalyticsService();
}
