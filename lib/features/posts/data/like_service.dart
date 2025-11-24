import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';

part 'like_service.g.dart';

class LikeService {
  const LikeService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<bool> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to like posts.');
    }

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    final postRef = _firestore.collection('posts').doc(postId);

    return _firestore.runTransaction<bool>((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
        throw Exception('Post not found.');
      }

      final currentLikeCount =
          (postDoc.data()?['likeCount'] as num?)?.toInt() ?? 0;
      bool isLiking;

      if (likeDoc.exists) {
        // Unlike: remove like and decrement count
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': currentLikeCount - 1});
        isLiking = false;
      } else {
        // Like: add like and increment count
        transaction.set(likeRef, {
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': currentLikeCount + 1});
        isLiking = true;
      }

      return isLiking;
    });
  }

  Stream<bool> watchIsLiked(String postId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }
}

@Riverpod(keepAlive: true)
LikeService likeService(rpd.Ref ref) {
  return LikeService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<bool> isPostLiked(rpd.Ref ref, String postId) {
  return ref.watch(likeServiceProvider).watchIsLiked(postId);
}
