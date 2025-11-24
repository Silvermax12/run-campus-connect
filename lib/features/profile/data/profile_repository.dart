import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/user_profile.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Stream<UserProfile?> watchProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserProfile.fromMap(snapshot.id, snapshot.data() ?? {});
    });
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromMap(snapshot.id, snapshot.data() ?? {});
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(rpd.Ref ref) {
  return ProfileRepository(ref.watch(firestoreProvider));
}

@Riverpod(keepAlive: true)
Stream<UserProfile?> currentUserProfile(rpd.Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) {
    return Stream<UserProfile?>.value(null);
  }
  final repository = ref.watch(profileRepositoryProvider);
  return repository.watchProfile(uid);
}
