import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/cloudinary_service.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/post.dart';
import '../domain/post_visibility.dart';

part 'post_repository.g.dart';

class PostRepository {
  const PostRepository({
    required FirebaseFirestore firestore,
    required CloudinaryService cloudinaryService,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _cloudinaryService = cloudinaryService,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinaryService;
  final FirebaseAuth _auth;

  static const int pageSize = 10;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  // ---------------------------------------------------------------------------
  // Streams (real-time)
  // ---------------------------------------------------------------------------

  /// Global feed — returns ALL posts regardless of visibility.
  Stream<List<Post>> watchGlobalPosts({int limit = pageSize}) {
    return _postsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Post.fromSnapshot).toList());
  }

  /// Faculty feed — only posts where visibility == 'faculty' AND matching
  /// faculty string.
  Stream<List<Post>> watchFacultyPosts(String faculty, {int limit = pageSize}) {
    return _postsRef
        .where('visibility', isEqualTo: 'faculty')
        .where('faculty', isEqualTo: faculty)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Post.fromSnapshot).toList());
  }

  /// Department feed — only posts where visibility == 'department' AND matching
  /// department string.
  Stream<List<Post>> watchDepartmentPosts(String department,
      {int limit = pageSize}) {
    return _postsRef
        .where('visibility', isEqualTo: 'department')
        .where('department', isEqualTo: department)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Post.fromSnapshot).toList());
  }

  /// Single post stream for real-time like counts and updates.
  Stream<Post?> watchPost(String postId) {
    return _postsRef.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Post.fromSnapshot(doc);
    });
  }

  // ---------------------------------------------------------------------------
  // Pagination (one-shot)
  // ---------------------------------------------------------------------------

  Future<List<Post>> fetchMoreGlobalPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _postsRef
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromSnapshot).toList();
  }

  Future<List<Post>> fetchMoreFacultyPosts({
    required String faculty,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _postsRef
        .where('visibility', isEqualTo: 'faculty')
        .where('faculty', isEqualTo: faculty)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromSnapshot).toList();
  }

  Future<List<Post>> fetchMoreDepartmentPosts({
    required String department,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _postsRef
        .where('visibility', isEqualTo: 'department')
        .where('department', isEqualTo: department)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(Post.fromSnapshot).toList();
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  Future<void> createPost({
    required String content,
    required UserProfile author,
    required PostVisibility visibility,
    File? imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to create a post.');
    }
    final docRef = _postsRef.doc();

    String? imageUrl;
    String? imageDeleteToken;
    String? imagePublicId;
    if (imageFile != null) {
      final uploaded = await _cloudinaryService.uploadPostImage(imageFile);
      imageUrl = uploaded.secureUrl;
      imageDeleteToken = uploaded.deleteToken;
      imagePublicId = uploaded.publicId;
    }

    final payload = {
      'id': docRef.id,
      'content': content.trim(),
      'imageUrl': imageUrl,
      'imageDeleteToken': imageDeleteToken,
      'imagePublicId': imagePublicId,
      'timestamp': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'viewCount': 0,
      'commentCount': 0,
      'authorSnapshot': {
        'uid': author.uid,
        'name': author.displayName,
        'dept': author.department,
        'photo': author.photoUrl,
      },
      'visibility': visibility.toFirestoreValue(),
      'faculty': author.faculty,
      'department': author.department,
    };

    await docRef.set(payload);
  }

  // ---------------------------------------------------------------------------
  // Delete (post + subcollections + Cloudinary image)
  // ---------------------------------------------------------------------------
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to delete a post.');
    }

    final postDocRef = _postsRef.doc(postId);
    final snap = await postDocRef.get();
    if (!snap.exists) {
      return;
    }

    final data = snap.data() ?? {};
    final authorUid =
        (data['authorSnapshot'] as Map?)?['uid']?.toString() ?? '';
    if (authorUid != user.uid) {
      throw Exception('You can only delete your own posts.');
    }

    final deleteToken = data['imageDeleteToken'] as String?;
    if (deleteToken != null && deleteToken.trim().isNotEmpty) {
      // Delete Cloudinary asset first so we don't lose the token.
      await _cloudinaryService.deleteByToken(deleteToken);
    }

    // Delete subcollections (best-effort batching)
    await _deleteSubcollection(postDocRef.collection('likes'));
    await _deleteSubcollection(postDocRef.collection('views'));
    await _deleteSubcollection(postDocRef.collection('comments'));

    // Finally delete the post document itself.
    await postDocRef.delete();
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> colRef,
  ) async {
    const batchLimit = 450;
    while (true) {
      final snapshot = await colRef.limit(batchLimit).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ---------------------------------------------------------------------------
  // View Count
  // ---------------------------------------------------------------------------

  /// Records a view for the given user. Each user can only count once.
  /// The post creator is excluded from view counting.
  /// Uses a transaction to prevent race conditions on refresh.
  Future<void> incrementViewCount(String postId, {required String viewerUid, required String authorUid}) async {
    // Don't count the creator as a viewer
    if (viewerUid == authorUid) return;

    final viewDocRef = _postsRef.doc(postId).collection('views').doc(viewerUid);
    final postDocRef = _postsRef.doc(postId);

    await _firestore.runTransaction((transaction) async {
      final viewSnapshot = await transaction.get(viewDocRef);
      if (viewSnapshot.exists) return; // Already viewed — do nothing

      transaction.set(viewDocRef, {'viewedAt': FieldValue.serverTimestamp()});
      transaction.update(postDocRef, {
        'viewCount': FieldValue.increment(1),
      });
    });
  }
}

@Riverpod(keepAlive: true)
PostRepository postRepository(rpd.Ref ref) {
  return PostRepository(
    firestore: ref.watch(firestoreProvider),
    cloudinaryService: ref.watch(cloudinaryServiceProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<List<Post>> globalPostsStream(rpd.Ref ref) {
  return ref.watch(postRepositoryProvider).watchGlobalPosts();
}

@Riverpod(keepAlive: true)
Stream<List<Post>> facultyPostsStream(rpd.Ref ref, String faculty) {
  return ref.watch(postRepositoryProvider).watchFacultyPosts(faculty);
}

@Riverpod(keepAlive: true)
Stream<List<Post>> departmentPostsStream(rpd.Ref ref, String department) {
  return ref.watch(postRepositoryProvider).watchDepartmentPosts(department);
}

@Riverpod(keepAlive: true)
Stream<Post?> postStream(rpd.Ref ref, String postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
}
