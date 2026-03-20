import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart' as domain;
import '../domain/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.targetUserId,
    this.targetUserName,
  });

  final String targetUserId;
  final String? targetUserName;

  static const routeName = 'chat';
  static String routePath(String userId) => '/chat/$userId';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  domain.ChatMessage? _replyingTo;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid != null) {
      final chatId = ref.read(chatRepositoryProvider).getChatId(myUid, widget.targetUserId);
      ref.read(chatRepositoryProvider).markChatAsRead(chatId, myUid);
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return;

    ReplyTo? replyTo;
    if (_replyingTo != null && _replyingToUserName != null) {
      replyTo = ReplyTo(
        messageId: _replyingTo!.id,
        senderName: _replyingToUserName!,
        content: _replyingTo!.content,
      );
    }

    ref.read(chatRepositoryProvider).sendMessage(
          myUid: myUid,
          targetUid: widget.targetUserId,
          content: content,
          replyTo: replyTo,
        );
    _messageController.clear();
    setState(() {
      _replyingTo = null;
      _replyingToUserName = null;
    });
  }

  void _setReplyMessage(domain.ChatMessage message, String senderName) {
    setState(() {
      _replyingTo = message;
      _replyingToUserName = senderName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToUserName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final chatId = ref.read(chatRepositoryProvider).getChatId(myUid, widget.targetUserId);
    final messagesStream = ref.watch(chatMessagesStreamProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUserName ?? 'Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesStream.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hello!'));
                }
                return ListView.builder(
                  reverse: true,
                  cacheExtent: 400,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == myUid;
                    final senderName = isMe ? 'You' : (widget.targetUserName ?? 'User');
                    return RepaintBoundary(
                      child: _MessageBubble(
                        message: message,
                        isMe: isMe,
                        senderName: senderName,
                        onLongPress: () => _setReplyMessage(message, senderName),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to $_replyingToUserName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingTo!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.onLongPress,
  });

  final domain.ChatMessage message;
  final bool isMe;
  final String senderName;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe ? theme.primaryColor : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyTo != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? Colors.white.withOpacity(0.2) 
                        : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? Colors.white : theme.primaryColor,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.replyTo!.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isMe ? Colors.white : theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.replyTo!.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe 
                              ? Colors.white.withOpacity(0.8) 
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Provider for messages stream
final chatMessagesStreamProvider = StreamProvider.family<List<domain.ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});
