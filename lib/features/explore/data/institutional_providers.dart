import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';

part 'institutional_providers.g.dart';

/// Fetches the single document from `run_our_history` collection.
@riverpod
Future<Map<String, dynamic>?> runHistory(RunHistoryRef ref) async {
  final firestore = ref.watch(firestoreProvider);
  final doc =
      await firestore.collection('run_our_history').doc('our_history').get();
  return doc.exists ? doc.data() : null;
}

/// Fetches the single document from `run_governance` collection.
@riverpod
Future<Map<String, dynamic>?> runGovernance(RunGovernanceRef ref) async {
  final firestore = ref.watch(firestoreProvider);
  final doc =
      await firestore.collection('run_governance').doc('governance').get();
  return doc.exists ? doc.data() : null;
}

/// Fetches the single document from `run_motto_logo_anthem` collection.
@riverpod
Future<Map<String, dynamic>?> runMottoLogoAnthem(
    RunMottoLogoAnthemRef ref) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore
      .collection('run_motto_logo_anthem')
      .doc('motto_logo_anthem')
      .get();
  return doc.exists ? doc.data() : null;
}

/// Fetches the single document from `run_vision_mission` collection.
@riverpod
Future<Map<String, dynamic>?> runVisionMission(
    RunVisionMissionRef ref) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore
      .collection('run_vision_mission')
      .doc('vision_mission')
      .get();
  return doc.exists ? doc.data() : null;
}
