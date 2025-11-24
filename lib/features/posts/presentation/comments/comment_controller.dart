import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../domain/comment.dart';

part 'comment_controller.g.dart';

@riverpod
Stream<List<Comment>> comments(Ref ref, {required String postId}) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Comment.fromSnapshot(doc)).toList(),
      );
}

@riverpod
class CommentController extends _$CommentController {
  @override
  FutureOr<void> build() {}

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firestore = ref.read(firestoreProvider);
      final postRef = firestore.collection('posts').doc(postId);
      final commentsRef = postRef.collection('comments');

      await firestore.runTransaction((transaction) async {
        // Create comment
        final newCommentRef = commentsRef.doc();
        transaction.set(newCommentRef, {
          'text': text,
          'authorId': user.uid,
          'authorName': user.displayName ?? 'Anonymous',
          'authorPhotoUrl': user.photoURL ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Increment comment count
        transaction.update(postRef, {
          'commentCount': FieldValue.increment(1),
        });
      });
    });
  }
}
