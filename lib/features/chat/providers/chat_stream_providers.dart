import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';

/// Stream of chats for the current user.
final userChatsStreamProvider =
    StreamProvider.family<List<Chat>, String>((ref, myUid) {
  return ref.watch(chatRepositoryProvider).watchChats(myUid);
});

/// Stream of a user document (for inbox search result display).
final userDocProvider =
    StreamProvider.family<DocumentSnapshot, String>((ref, userId) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots();
});
