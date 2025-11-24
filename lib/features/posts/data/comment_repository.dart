import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/comment.dart';

part 'comment_repository.g.dart';

class CommentRepository {
  const CommentRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) {
    return _firestore.collection('posts').doc(postId).collection('comments');
  }

  Stream<List<Comment>> watchComments(String postId) {
    return _commentsRef(postId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Comment.fromSnapshot).toList());
  }

  Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to comment.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception('Profile not found. Please complete your profile.');
    }

    final commentRef = _commentsRef(postId).doc();
    final comment = Comment(
      id: commentRef.id,
      text: text.trim(),
      authorId: user.uid,
      authorName: userData['displayName'] as String? ?? '',
      authorPhotoUrl: userData['photoUrl'] as String? ?? '',
      timestamp: DateTime.now(),
      snapshot: commentRef as DocumentSnapshot<Map<String, dynamic>>,
    );

    // Add comment and increment count atomically
    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, comment.toMap());
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await transaction.get(postRef);
      if (postDoc.exists) {
        final currentCount =
            (postDoc.data()?['commentCount'] as num?)?.toInt() ?? 0;
        transaction.update(postRef, {'commentCount': currentCount + 1});
      }
    });
  }
}

@Riverpod(keepAlive: true)
CommentRepository commentRepository(rpd.Ref ref) {
  return CommentRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<List<Comment>> postCommentsStream(rpd.Ref ref, String postId) {
  return ref.watch(commentRepositoryProvider).watchComments(postId);
}
