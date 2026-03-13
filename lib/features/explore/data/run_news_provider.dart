import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';

part 'run_news_provider.g.dart';

@riverpod
Stream<List<Map<String, dynamic>>> runNews(RunNewsRef ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('run_news')
      .orderBy('scrapedAt', descending: false)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
}
