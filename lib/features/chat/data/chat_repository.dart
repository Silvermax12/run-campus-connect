import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/notification_service.dart';
import '../domain/chat.dart';
import '../domain/message.dart';

part 'chat_repository.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return ChatRepository(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
}

class ChatRepository {
  ChatRepository(this._firestore, this._notificationService);

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<void> ensureChatExists({
    required String myUid,
    required String targetUid,
  }) async {
    final chatId = getChatId(myUid, targetUid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await chatDoc.set({
      'participants': [myUid, targetUid],
      // Do not touch lastTime/lastMessage here to avoid inbox reordering
      // when a user simply opens a chat.
      'unreadCounts': {myUid: 0, targetUid: 0},
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage({
    required String myUid,
    required String senderName,
    required String targetUid,
    required String content,
    ReplyTo? replyTo,
  }) async {
    final chatId = getChatId(myUid, targetUid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    final messagesCol = chatDoc.collection('messages');
    final receiverDoc = _firestore.collection('users').doc(targetUid);

    final batch = _firestore.batch();

    // Action 1: Add message to chats/{chatId}/messages
    // CRITICAL: Use FieldValue.serverTimestamp() for proper interleaving
    final newMessageDoc = messagesCol.doc();
    final messageData = {
      'senderId': myUid,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'deliveredTo': [myUid],
      'readBy': [myUid],
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    };
    batch.set(newMessageDoc, messageData);

    // Action 2: Update chats/{chatId} metadata (lastMessage, lastTime)
    // Also increment unread count for the target user in the chat document
    batch.set(chatDoc, {
      'participants': [myUid, targetUid],
      'lastMessage': content,
      'lastTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        targetUid: FieldValue.increment(1),
      },
    }, SetOptions(merge: true));

    // Action 3 (CRITICAL): Increment the Receiver's global counter
    // FIXED: Use merge to prevent error if field doesn't exist
    batch.set(receiverDoc, {
      'totalUnreadMessages': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();

    // Fire-and-forget push notification to the recipient.
    // Errors are swallowed inside NotificationService to never disrupt the UX.
    _notificationService.sendChatNotification(
      recipientUid: targetUid,
      senderName: senderName,
      messagePreview: content.length > 80 ? '${content.substring(0, 80)}…' : content,
      chatId: chatId,
      targetUserId: myUid, // recipient taps → opens chat with the sender
    );
  }

  Future<void> markChatAsRead(String chatId, String myUid) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final userRef = _firestore.collection('users').doc(myUid);
    final messagesRef = chatRef.collection('messages');

    try {
      await _firestore.runTransaction((transaction) async {
        final chatSnapshot = await transaction.get(chatRef);
        if (!chatSnapshot.exists) return;

        final data = chatSnapshot.data();
        if (data == null) return;

        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
        final myUnreadCount = (unreadCounts?[myUid] as num?)?.toInt() ?? 0;

        if (myUnreadCount <= 0) return;

        // Reset my unread count in the chat.
        transaction.set(chatRef, {
          'unreadCounts': {
            myUid: 0,
          }
        }, SetOptions(merge: true));

        // Decrement my global unread count.
        transaction.set(userRef, {
          'totalUnreadMessages': FieldValue.increment(-myUnreadCount),
        }, SetOptions(merge: true));
      });

      // Mark the newest unread incoming messages as delivered/read for sender ticks.
      // Keep this outside transaction for simplicity and speed.
      final unreadIncoming =
          await messagesRef.orderBy('timestamp', descending: true).limit(50).get();

      if (unreadIncoming.docs.isEmpty) return;

      final batch = _firestore.batch();
      var touched = 0;
      for (final doc in unreadIncoming.docs) {
        final data = doc.data();
        if ((data['senderId'] as String?) == myUid) continue;
        final readBy = List<String>.from(data['readBy'] as List? ?? const []);
        final deliveredTo =
            List<String>.from(data['deliveredTo'] as List? ?? const []);

        final needsRead = !readBy.contains(myUid);
        final needsDelivered = !deliveredTo.contains(myUid);
        if (!needsRead && !needsDelivered) continue;

        batch.set(doc.reference, {
          'readBy': FieldValue.arrayUnion([myUid]),
          'deliveredTo': FieldValue.arrayUnion([myUid]),
        }, SetOptions(merge: true));
        touched += 1;
      }

      if (touched > 0) {
        await batch.commit();
      }
    } catch (e) {
      // Silently catch errors to prevent UI disruption
      debugPrint('Error marking chat as read: $e');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  Future<void> setPresence({
    required String uid,
    required bool isOnline,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markIncomingAsDelivered({
    required String chatId,
    required String myUid,
  }) async {
    try {
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      if (messages.docs.isEmpty) return;

      final batch = _firestore.batch();
      var touched = 0;
      for (final doc in messages.docs) {
        final data = doc.data();
        if ((data['senderId'] as String?) == myUid) continue;
        final deliveredTo =
            List<String>.from(data['deliveredTo'] as List? ?? const []);
        if (deliveredTo.contains(myUid)) continue;
        batch.set(doc.reference, {
          'deliveredTo': FieldValue.arrayUnion([myUid]),
        }, SetOptions(merge: true));
        touched += 1;
      }

      if (touched > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking delivered: $e');
    }
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromSnapshot(doc)).toList());
  }

  Stream<List<Chat>> watchChats(String myUid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Chat.fromSnapshot(doc)).toList());
  }
}
