import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/post_repository.dart';
import '../../domain/post.dart';
import 'post_feed_state.dart';

part 'post_feed_controller.g.dart';

/// Determines which stream / pagination query the controller uses.
enum FeedType { global, faculty, department }

@riverpod
class PostFeedController extends _$PostFeedController {
  @override
  PostFeedState build(FeedType feedType, String filterValue) {
    ref.keepAlive();

    // Pick the right stream provider based on feedType.
    rpd.ProviderListenable<rpd.AsyncValue<List<Post>>> streamProvider;
    switch (feedType) {
      case FeedType.global:
        streamProvider = globalPostsStreamProvider;
        break;
      case FeedType.faculty:
        streamProvider = facultyPostsStreamProvider(filterValue);
        break;
      case FeedType.department:
        streamProvider = departmentPostsStreamProvider(filterValue);
        break;
    }

    ref.listen<rpd.AsyncValue<List<Post>>>(streamProvider, (previous, next) {
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
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final lastSnapshot = state.lastPost?.snapshot;
      final repo = ref.read(postRepositoryProvider);

      List<Post> olderPosts;
      switch (feedType) {
        case FeedType.global:
          olderPosts = await repo.fetchMoreGlobalPosts(
            startAfter: lastSnapshot,
          );
          break;
        case FeedType.faculty:
          olderPosts = await repo.fetchMoreFacultyPosts(
            faculty: filterValue,
            startAfter: lastSnapshot,
          );
          break;
        case FeedType.department:
          olderPosts = await repo.fetchMoreDepartmentPosts(
            department: filterValue,
            startAfter: lastSnapshot,
          );
          break;
      }

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
