import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String senderPic;
  final String type;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? referenceId; // Optional: for navigation (e.g., userId)

  Notification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.senderPic,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.referenceId,
  });

  factory Notification.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Notification(
      id: doc.id,
      recipientId: data['recipientId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderPic: data['senderPic'] as String? ?? '',
      type: data['type'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      referenceId: data['referenceId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPic': senderPic,
      'type': type,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      if (referenceId != null) 'referenceId': referenceId,
    };
  }
}
