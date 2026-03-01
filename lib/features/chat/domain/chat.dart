import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastTime;
  final Map<String, int> unreadCounts;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCounts = const {},
  });

  factory Chat.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final unreadCountsData = data['unreadCounts'] as Map<String, dynamic>?;
    final unreadCounts = <String, int>{};
    
    if (unreadCountsData != null) {
      unreadCountsData.forEach((key, value) {
        unreadCounts[key] = (value as num?)?.toInt() ?? 0;
      });
    }
    
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastTime: (data['lastTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: unreadCounts,
    );
  }
}
