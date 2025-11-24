
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../posts/domain/post.dart';

part 'profile_controller.g.dart';

@riverpod
Future<List<Post>> userPosts(Ref ref, {required String userId}) async {
  ref.keepAlive();
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
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
    required String department,
    required String bio,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firestore = ref.read(firestoreProvider);
      
      // Update Auth Profile
      await user.updateDisplayName(name);
      
      // Update Firestore User Doc
      await firestore.collection('users').doc(user.uid).update({
        'displayName': name,
        'department': department,
        'bio': bio,
      });

      // Note: We are NOT updating all past posts here. 
      // In a real app, we might use a Cloud Function for that.
      // For this project, we accept that old posts might show old data 
      // until the next write, or we rely on the user doc for the profile view.
    });
  }
}
