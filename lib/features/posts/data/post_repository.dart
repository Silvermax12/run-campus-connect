import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/cloudinary_service.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/post.dart';

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

  Stream<List<Post>> watchRecentPosts({int limit = pageSize}) {
    return _postsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Post.fromSnapshot).toList());
  }

  Future<List<Post>> fetchMorePosts({
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

  Future<void> createPost({
    required String content,
    required UserProfile author,
    File? imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to create a post.');
    }
    final docRef = _postsRef.doc();

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _cloudinaryService.uploadFile(imageFile);
    }

    final payload = {
      'id': docRef.id,
      'content': content.trim(),
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
      'authorSnapshot': {
        'uid': author.uid,
        'name': author.displayName,
        'dept': author.department,
        'photo': author.photoUrl,
      },
    };

    await docRef.set(payload);
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
Stream<List<Post>> postsStream(rpd.Ref ref) {
  return ref.watch(postRepositoryProvider).watchRecentPosts();
}
