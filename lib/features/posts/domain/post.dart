import 'package:cloud_firestore/cloud_firestore.dart';

class PostAuthorSnapshot {
  const PostAuthorSnapshot({
    required this.uid,
    required this.name,
    required this.department,
    required this.photoUrl,
  });

  final String uid;
  final String name;
  final String department;
  final String photoUrl;

  factory PostAuthorSnapshot.fromMap(Map<String, dynamic> data) {
    return PostAuthorSnapshot(
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      department: data['dept'] as String? ?? '',
      photoUrl: data['photo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'name': name, 'dept': department, 'photo': photoUrl};
  }
}

class Post {
  Post({
    required this.id,
    required this.content,
    required this.imageUrl,
    required this.timestamp,
    required this.likeCount,
    required this.commentCount,
    required this.author,
    required this.snapshot,
  });

  final String id;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final int likeCount;
  final int commentCount;
  final PostAuthorSnapshot author;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  factory Post.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      author: PostAuthorSnapshot.fromMap(
        (data['authorSnapshot'] as Map<String, dynamic>? ?? {}),
      ),
      snapshot: doc,
    );
  }
}
