
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../domain/notification.dart';

/// All post-related notifications for a user.
final notificationsProvider = StreamProvider.family<List<Notification>, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .where('type', isEqualTo: 'new_post')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Notification.fromSnapshot(doc)).toList());
});

/// Post notifications filtered by category (global, faculty, department).
final filteredNotificationsProvider =
    Provider.family<AsyncValue<List<Notification>>, ({String uid, String category})>(
        (ref, params) {
  final allNotifications = ref.watch(notificationsProvider(params.uid));
  return allNotifications.whenData(
    (notifications) => notifications
        .where((n) => n.category == params.category)
        .toList(),
  );
});
