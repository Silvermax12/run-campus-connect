import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/friend_repository.dart';

part 'user_profile_screen_providers.g.dart';

@riverpod
Stream<FriendStatus> friendStatusStream(
  FriendStatusStreamRef ref, {
  required String myUid,
  required String targetUid,
}) {
  return ref
      .watch(friendRepositoryProvider)
      .watchFriendStatus(myUid: myUid, targetUid: targetUid);
}
