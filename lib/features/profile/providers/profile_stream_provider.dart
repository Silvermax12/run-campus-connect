import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider for Firestore document snapshots.
/// Used by profile_screen and user_profile_screen for real-time user data.
final profileDocumentStreamProvider =
    StreamProvider.family<DocumentSnapshot, DocumentReference>((ref, docRef) {
  return docRef.snapshots();
});
