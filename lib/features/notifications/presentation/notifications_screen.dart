import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../data/notifications_provider.dart';
import '../domain/notification.dart' as domain;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static const routeName = 'notifications';
  static const routePath = '/notifications';

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Faculty'),
            Tab(text: 'Department'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NotificationTab(uid: myUid, category: 'global'),
          _NotificationTab(uid: myUid, category: 'faculty'),
          _NotificationTab(uid: myUid, category: 'department'),
        ],
      ),
    );
  }
}

class _NotificationTab extends ConsumerWidget {
  const _NotificationTab({required this.uid, required this.category});

  final String uid;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(
      filteredNotificationsProvider((uid: uid, category: category)),
    );

    return notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
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
      tileColor:
          notification.isRead ? null : theme.primaryColor.withValues(alpha: 0.1),
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
          ref
              .read(profileRepositoryProvider)
              .markNotificationAsRead(notification.id);
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
