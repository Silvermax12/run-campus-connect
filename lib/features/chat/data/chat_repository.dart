import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/chat.dart';
import '../domain/message.dart';

part 'chat_repository.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return ChatRepository(ref.watch(firestoreProvider));
}

class ChatRepository {
  ChatRepository(this._firestore);

  final FirebaseFirestore _firestore;

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<void> sendMessage({
    required String myUid,
    required String targetUid,
    required String content,
  }) async {
    final chatId = getChatId(myUid, targetUid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    final messagesCol = chatDoc.collection('messages');

    final now = DateTime.now();

    // Use a batch or transaction if strict consistency is needed, 
    // but for simple chat, sequential writes are often okay. 
    // We'll use set(merge: true) for the chat doc to ensure it exists.
    
    await chatDoc.set({
      'participants': [myUid, targetUid],
      'lastMessage': content,
      'lastTime': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await messagesCol.add({
      'senderId': myUid,
      'content': content,
      'timestamp': Timestamp.fromDate(now),
    });
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
