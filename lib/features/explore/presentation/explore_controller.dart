import 'package:cloud_firestore/cloud_firestore.dart';
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
      
      // Convert to uppercase to match display name format
      final upperQuery = query.toUpperCase();
      
      final snapshot = await firestore
          .collection('users')
          .orderBy('displayName')
          .startAt([upperQuery])
          .endAt(['$upperQuery\uf8ff'])
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}
