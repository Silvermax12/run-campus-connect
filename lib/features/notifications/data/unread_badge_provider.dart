import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

final unreadBadgeProvider = StreamProvider.family<int, String>((ref, myUid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').doc(myUid).snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null || !data.containsKey('totalUnreadMessages')) return 0;
    return (data['totalUnreadMessages'] as num?)?.toInt() ?? 0;
  });
});
