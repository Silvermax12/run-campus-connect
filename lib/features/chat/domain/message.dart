import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyTo {
  final String messageId;
  final String senderName;
  final String content;

  ReplyTo({
    required this.messageId,
    required this.senderName,
    required this.content,
  });

  factory ReplyTo.fromMap(Map<String, dynamic> data) {
    return ReplyTo(
      messageId: data['messageId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      content: data['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderName': senderName,
      'content': content,
    };
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final ReplyTo? replyTo;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.replyTo,
  });

  factory ChatMessage.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    ReplyTo? replyTo;
    
    if (data['replyTo'] != null) {
      replyTo = ReplyTo.fromMap(data['replyTo'] as Map<String, dynamic>);
    }
    
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyTo: replyTo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      if (replyTo != null) 'replyTo': replyTo!.toMap(),
    };
  }
}
