import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastTime;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTime,
  });

  factory Chat.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastTime: (data['lastTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
