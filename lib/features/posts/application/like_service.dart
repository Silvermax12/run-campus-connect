import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';

part 'like_service.g.dart';

@Riverpod(keepAlive: true)
LikeService likeService(Ref ref) {
  return LikeService(
    firestore: ref.watch(firestoreProvider),
  );
}

class LikeService {
  const LikeService({required this.firestore});

  final FirebaseFirestore firestore;

  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final postRef = firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    await firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(postRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        transaction.set(likeRef, {
          'uid': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }
  Future<bool> isPostLiked({
    required String postId,
    required String userId,
  }) async {
    final doc = await firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .get();
    return doc.exists;
  }
}

@riverpod
Future<bool> checkPostLiked(Ref ref, {required String postId}) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  final service = ref.watch(likeServiceProvider);
  return service.isPostLiked(postId: postId, userId: user.uid);
}
