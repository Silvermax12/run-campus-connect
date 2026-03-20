import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/shimmer_box.dart';
import '../../application/like_service.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../profile/presentation/user_profile_screen.dart';
import '../comments/comment_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _viewCounted = false;

  bool get _isAuthor {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    return uid != null && uid == widget.post.author.uid;
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text(
          'Are you sure you want to delete this post? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref.read(postRepositoryProvider).deletePost(widget.post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _incrementView();
  }

  void _incrementView() {
    if (_viewCounted) return;
    _viewCounted = true;
    // Fire-and-forget unique view increment (excludes post author)
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    ref.read(postRepositoryProvider).incrementViewCount(
      widget.post.id,
      viewerUid: uid,
      authorUid: widget.post.author.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                GestureDetector(
                  onTap: () => context.push(
                    UserProfileScreen.routePath(widget.post.author.uid),
                  ),
                  child: CircleAvatar(
                    backgroundImage:
                        widget.post.author.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(
                                widget.post.author.photoUrl)
                            : null,
                    child:
                        widget.post.author.photoUrl.isEmpty
                            ? Text(
                              widget.post.author.name.isNotEmpty
                                  ? widget.post.author.name.characters.first
                                  : '?',
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.author.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.post.author.department,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(widget.post.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (_isAuthor) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') _showDeleteConfirm(context);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Delete post', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.post.content, style: theme.textTheme.bodyLarge),
            if (widget.post.imageUrl != null &&
                widget.post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => FullScreenImageViewer.open(
                  context,
                  imageUrl: widget.post.imageUrl!,
                  heroTag: 'post-image-${widget.post.id}',
                ),
                child: Hero(
                  tag: 'post-image-${widget.post.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 350),
                      child: CachedNetworkImage(
                        imageUrl: widget.post.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ShimmerBox(
                          width: double.infinity,
                          height: 350,
                          borderRadius: 16,
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _LikeButton(post: widget.post),
                const SizedBox(width: 16),
                _CommentButton(post: widget.post),
                const SizedBox(width: 16),
                _ViewCount(post: widget.post),
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

// ── View Count ────────────────────────────────────────────────────────────────

class _ViewCount extends ConsumerWidget {
  const _ViewCount({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only viewCount to avoid rebuilds when other Post fields change
    final viewCount = ref.watch(
      postStreamProvider(post.id).select(
        (v) => v.valueOrNull?.viewCount ?? post.viewCount,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            _formatCount(viewCount),
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k views';
    }
    return '$count views';
  }
}

// ── Like Button ───────────────────────────────────────────────────────────────

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
      if (next.hasValue &&
          next.value != null &&
          _likeCount != next.value!.likeCount) {
        setState(() => _likeCount = next.value!.likeCount);
      }
    });

    // Watch only isLiked and likeCount to avoid rebuilds when other Post fields change
    final isLikedFromProvider = ref.watch(
      checkPostLikedProvider(postId: widget.post.id).select(
        (v) => v.value ?? false,
      ),
    );
    final likeCountFromProvider = ref.watch(
      postStreamProvider(widget.post.id).select(
        (v) => v.value?.likeCount ?? widget.post.likeCount,
      ),
    );

    final isLiked = _isLiked ?? isLikedFromProvider;
    final likeCount = _likeCount ?? likeCountFromProvider;

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

// ── Comment Button ────────────────────────────────────────────────────────────

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
