import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';

part 'friend_repository.g.dart';

enum FriendStatus {
  none,
  pending_outgoing,
  pending_incoming,
  accepted,
}

@riverpod
FriendRepository friendRepository(FriendRepositoryRef ref) {
  return FriendRepository(ref.watch(firestoreProvider));
}

class FriendRepository {
  FriendRepository(this._firestore);

  final FirebaseFirestore _firestore;

  // Helper to get friend doc reference
  DocumentReference _friendDoc(String myUid, String targetUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid);
  }

  Future<void> sendFriendRequest({
    required String myUid,
    required String targetUid,
    required String myName,
    required String myPhotoUrl,
  }) async {
    final batch = _firestore.batch();

    // My side: pending_outgoing
    batch.set(
      _friendDoc(myUid, targetUid),
      {'status': FriendStatus.pending_outgoing.name},
    );

    // Target side: pending_incoming
    batch.set(
      _friendDoc(targetUid, myUid),
      {'status': FriendStatus.pending_incoming.name},
    );

    // Create notification for target user
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'recipientId': targetUid,
      'senderId': myUid,
      'senderName': myName,
      'senderPic': myPhotoUrl,
      'type': 'friend_request',
      'message': 'sent you a friend request',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'referenceId': myUid, // To navigate to sender's profile
    });

    await batch.commit();
  }

  Future<void> cancelFriendRequest({
    required String myUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();

    // Delete both docs
    batch.delete(_friendDoc(myUid, targetUid));
    batch.delete(_friendDoc(targetUid, myUid));

    await batch.commit();
  }

  Future<void> acceptFriendRequest({
    required String myUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();

    // Both sides: accepted
    batch.update(
      _friendDoc(myUid, targetUid),
      {'status': FriendStatus.accepted.name},
    );
    batch.update(
      _friendDoc(targetUid, myUid),
      {'status': FriendStatus.accepted.name},
    );

    await batch.commit();
  }

  Future<void> unfriend({
    required String myUid,
    required String targetUid,
  }) async {
    // Same as cancel - remove the relationship
    await cancelFriendRequest(myUid: myUid, targetUid: targetUid);
  }

  Stream<FriendStatus> watchFriendStatus({
    required String myUid,
    required String targetUid,
  }) {
    return _friendDoc(myUid, targetUid).snapshots().map((snapshot) {
      if (!snapshot.exists) return FriendStatus.none;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return FriendStatus.none;
      
      final statusStr = data['status'] as String?;
      return FriendStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => FriendStatus.none,
      );
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }
}
