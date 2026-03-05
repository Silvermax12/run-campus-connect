import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/like_service.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../comments/comment_screen.dart';

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      post.author.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(post.author.photoUrl)
                          : null,
                  child:
                      post.author.photoUrl.isEmpty
                          ? Text(
                            post.author.name.isNotEmpty
                                ? post.author.name.characters.first
                                : '?',
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        post.author.department,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(post.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post.content, style: theme.textTheme.bodyLarge),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _LikeButton(post: post),
                const SizedBox(width: 16),
                _CommentButton(post: post),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.post});

  final Post post;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  bool? _isLiked;
  int? _likeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time syncs from Firestore streams to update local state if it drifts.
    ref.listen(checkPostLikedProvider(postId: widget.post.id), (_, next) {
      if (next.hasValue && next.value != null && _isLiked != next.value) {
        setState(() => _isLiked = next.value);
      }
    });

    ref.listen(postStreamProvider(widget.post.id), (_, next) {
      if (next.hasValue && next.value != null && _likeCount != next.value!.likeCount) {
        setState(() => _likeCount = next.value!.likeCount);
      }
    });

    // We also eagerly watch the providers so the widget rebuilds when data changes.
    final isLikedAsync = ref.watch(checkPostLikedProvider(postId: widget.post.id));
    final postAsync = ref.watch(postStreamProvider(widget.post.id));

    final isLiked = _isLiked ?? isLikedAsync.value ?? false;
    final likeCount = _likeCount ?? postAsync.value?.likeCount ?? widget.post.likeCount;

    return InkWell(
      onTap: () => _toggleLike(isLiked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isLiked ? Colors.red : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              '$likeCount',
              style: TextStyle(
                color: isLiked ? Colors.red : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(bool currentLikeStatus) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    // Optimistic Update
    setState(() {
      _isLiked = !currentLikeStatus;
      _likeCount = (_likeCount ?? 0) + (currentLikeStatus ? -1 : 1);
    });

    try {
      await ref.read(likeServiceProvider).toggleLike(
            postId: widget.post.id,
            userId: user.uid,
          );
    } catch (error) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        _isLiked = currentLikeStatus;
        _likeCount = (_likeCount ?? 0) + (currentLikeStatus ? 1 : -1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like. Please try again.')),
      );
    }
  }
}

class _CommentButton extends StatelessWidget {
  const _CommentButton({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(CommentScreen.routePath(post.id)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              '${post.commentCount}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
