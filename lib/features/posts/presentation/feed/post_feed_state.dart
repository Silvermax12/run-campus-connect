import '../../domain/post.dart';

class PostFeedState {
  const PostFeedState({
    required this.latestPosts,
    required this.olderPosts,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
  });

  factory PostFeedState.initial() => const PostFeedState(
    latestPosts: [],
    olderPosts: [],
    isInitialLoading: true,
    isLoadingMore: false,
    hasMore: true,
  );

  final List<Post> latestPosts;
  final List<Post> olderPosts;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;

  List<Post> get posts => [...latestPosts, ...olderPosts];

  Post? get lastPost => posts.isNotEmpty ? posts.last : null;

  PostFeedState copyWith({
    List<Post>? latestPosts,
    List<Post>? olderPosts,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return PostFeedState(
      latestPosts: latestPosts ?? this.latestPosts,
      olderPosts: olderPosts ?? this.olderPosts,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
