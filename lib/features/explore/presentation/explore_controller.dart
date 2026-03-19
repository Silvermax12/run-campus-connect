import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/firebase_providers.dart';

part 'explore_controller.g.dart';

@riverpod
class ExploreController extends _$ExploreController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return [];
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firestore = ref.read(firestoreProvider);
      final upperQuery = query.trim().toUpperCase();
      if (upperQuery.isEmpty) return <Map<String, dynamic>>[];

      // Query 1: prefix match on displayName (first name / full name)
      final byDisplayName = await firestore
          .collection('users')
          .orderBy('displayName')
          .startAt([upperQuery])
          .endAt(['$upperQuery\uf8ff'])
          .limit(20)
          .get();

      // Query 2: prefix match on lastName (last name)
      final byLastName = await firestore
          .collection('users')
          .orderBy('lastName')
          .startAt([upperQuery])
          .endAt(['$upperQuery\uf8ff'])
          .limit(20)
          .get();

      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final doc in byDisplayName.docs) {
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        if (seen.add(uid)) merged.add(data);
      }
      for (final doc in byLastName.docs) {
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        if (seen.add(uid)) merged.add(data);
      }
      return merged.take(20).toList();
    });
  }
}
