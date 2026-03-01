import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../profile/data/friend_repository.dart';
import '../../profile/presentation/user_profile_screen.dart';
import '../data/notifications_provider.dart';
import '../domain/notification.dart' as domain;

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const routeName = 'notifications';
  static const routePath = '/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    
    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    final notificationsStream = ref.watch(notificationsProvider(myUid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notificationsStream.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final domain.Notification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return ListTile(
      tileColor: notification.isRead ? null : theme.primaryColor.withOpacity(0.1),
      leading: CircleAvatar(
        backgroundImage: notification.senderPic.isNotEmpty
            ? CachedNetworkImageProvider(notification.senderPic)
            : null,
        child: notification.senderPic.isEmpty
            ? Text(notification.senderName.isNotEmpty 
                ? notification.senderName.characters.first 
                : '?')
            : null,
      ),
      title: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: notification.senderName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' ${notification.message}'),
          ],
        ),
      ),
      subtitle: Text(
        _formatTimestamp(notification.timestamp),
        style: theme.textTheme.bodySmall,
      ),
      onTap: () {
        // Mark as read
        if (!notification.isRead) {
          ref.read(friendRepositoryProvider).markNotificationAsRead(notification.id);
        }
        
        // Navigate based on type
        if (notification.type == 'friend_request' && notification.referenceId != null) {
          context.push(UserProfileScreen.routePath(notification.referenceId!));
        }
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
