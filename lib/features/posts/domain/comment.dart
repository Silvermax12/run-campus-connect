import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  const Comment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.timestamp,
    required this.snapshot,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final DateTime timestamp;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  factory Comment.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Comment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      snapshot: doc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
