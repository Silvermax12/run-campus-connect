import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/services/fcm_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../posts/domain/post.dart';
import '../domain/user_profile.dart';

part 'profile_controller.g.dart';

@riverpod
Future<List<Post>> userPosts(Ref ref, {required String userId}) async {
  ref.keepAlive();
  final firestore = ref.watch(firestoreProvider);
  final snapshot =
      await firestore
          .collection('posts')
          .where('authorSnapshot.uid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
  return snapshot.docs.map((doc) => Post.fromSnapshot(doc)).toList();
}

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  Future<void> updateProfile({
    required String name,
    required String faculty,
    required String department,
    required String bio,
    int? birthDay,
    int? birthMonth,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firestore = ref.read(firestoreProvider);
      final userRef = firestore.collection('users').doc(user.uid);
      final oldSnapshot = await userRef.get();
      final oldProfile =
          oldSnapshot.exists
              ? UserProfile.fromMap(user.uid, oldSnapshot.data() ?? {})
              : null;

      // Update Auth Profile
      await user.updateDisplayName(name);

      final parts =
          name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final lastName = parts.isEmpty ? name : parts.last;

      // Update Firestore User Doc
      await userRef.update({
        'displayName': name,
        'lastName': lastName,
        'faculty': faculty,
        'department': department,
        'bio': bio,
        'birthDay': birthDay,
        'birthMonth': birthMonth,
      });

      final newSnapshot = await userRef.get();
      final newProfile = UserProfile.fromMap(
        user.uid,
        newSnapshot.data() ?? {},
      );
      await ref
          .read(fcmServiceProvider)
          .updateTopicSubscriptions(oldProfile, newProfile);
    });
  }
}
