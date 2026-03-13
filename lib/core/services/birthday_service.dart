import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../providers/firebase_providers.dart';

part 'birthday_service.g.dart';

class BirthdayService {
  BirthdayService(this._chatRepository, this._firestore);

  final ChatRepository _chatRepository;
  final FirebaseFirestore _firestore;

  /// A fixed UID used as the "Campus Connect Bot" sender.
  static const botUid = 'campus_connect_bot';

  /// Sends a birthday greeting via chat from the system bot.
  Future<void> sendBirthdayMessage(String userId) async {
    // Check if we already sent a birthday message today to prevent duplicates.
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    final flagDoc = _firestore
        .collection('users')
        .doc(userId)
        .collection('birthday_flags')
        .doc(todayKey);

    final existing = await flagDoc.get();
    if (existing.exists) return; // Already sent

    // Send the message
    await _chatRepository.sendMessage(
      myUid: botUid,
      targetUid: userId,
      content:
          '🎂 Happy Birthday from Campus Connect! Wishing you an amazing day! 🎉',
    );

    // Mark as sent
    await flagDoc.set({'sentAt': FieldValue.serverTimestamp()});
  }
}

@Riverpod(keepAlive: true)
BirthdayService birthdayService(rpd.Ref ref) {
  return BirthdayService(
    ref.watch(chatRepositoryProvider),
    ref.watch(firestoreProvider),
  );
}

/// Provider that checks if the current user's birthday is today.
@riverpod
bool isTodayUserBirthday(rpd.Ref ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  final profile = profileAsync.valueOrNull;
  if (profile == null) return false;

  final now = DateTime.now();
  return profile.birthDay == now.day && profile.birthMonth == now.month;
}
