import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../domain/notification.dart';

/// All post-related notifications for a user.
final notificationsProvider = StreamProvider.family<List<Notification>, String>(
  (ref, uid) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Notification.fromSnapshot(doc))
                  .toList(),
        );
  },
);

/// Post notifications filtered by category (global, faculty, department).
final filteredNotificationsProvider = StreamProvider.family<
  List<Notification>,
  ({String uid, String category})
>((ref, params) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: params.uid)
      .where('category', isEqualTo: params.category)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Notification.fromSnapshot(doc)).toList(),
      );
});
