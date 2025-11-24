import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/post_repository.dart';
import '../../domain/post.dart';
import 'post_feed_state.dart';

part 'post_feed_controller.g.dart';

@riverpod
class PostFeedController extends _$PostFeedController {
  @override
  PostFeedState build() {
    ref.keepAlive();
    ref.listen<rpd.AsyncValue<List<Post>>>(postsStreamProvider, (
      previous,
      next,
    ) {
      next.when(
        data: (posts) {
          state = state.copyWith(
            latestPosts: posts,
            isInitialLoading: false,
            hasMore: true,
          );
        },
        loading: () {
          if (state.posts.isEmpty) {
            state = state.copyWith(isInitialLoading: true);
          }
        },
        error: (_, __) {
          state = state.copyWith(isInitialLoading: false);
        },
      );
    }, fireImmediately: true);
    return PostFeedState.initial();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final lastSnapshot = state.lastPost?.snapshot;
      final olderPosts = await ref
          .read(postRepositoryProvider)
          .fetchMorePosts(startAfter: lastSnapshot);
      if (olderPosts.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
      } else {
        state = state.copyWith(
          olderPosts: [...state.olderPosts, ...olderPosts],
          isLoadingMore: false,
          hasMore: olderPosts.length >= PostRepository.pageSize,
        );
      }
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = PostFeedState.initial();
  }
}
