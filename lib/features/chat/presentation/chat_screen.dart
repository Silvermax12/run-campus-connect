import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart' as domain;
import '../domain/message.dart';
import 'chat_search_controller.dart';

// ── Chat background / colour constants ────────────────────────────────────────
const _chatBgTopDark = Color(0xFF0A1628);
const _chatBgBottomDark = Color(0xFF0A1628);
const _chatBubbleBlueDark = Color(0xFF1A3A5C);
const _chatSurfaceDark = Color(0xFF1E2A3D);
const _incomingBubbleDark = Color(0xFF252F3D);
const _chatTextWhite = Colors.white;
const _incomingTextDark = Color(0xFFE4EAF4);
const _premiumGold = Color(0xFFB8954F);
const _timestampColor = Color(0xFF8A96A8);

// ── Search highlight colours ───────────────────────────────────────────────────
/// Strong gold for the currently-focused match.
const _activeHighlight = Color(0xFFFFCC00);

/// Subtle tint for non-focused matches.
const _inactiveHighlight = Color(0x55FFCC00);

// ═════════════════════════════════════════════════════════════════════════════
// ChatScreen
// ═════════════════════════════════════════════════════════════════════════════

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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  // ── Message input ──────────────────────────────────────────────────────────
  final _messageController = TextEditingController();

  // ── Reply state ────────────────────────────────────────────────────────────
  domain.ChatMessage? _replyingTo;
  String? _replyingToUserName;
  bool _didInitialRead = false;

  // ── Search ─────────────────────────────────────────────────────────────────

  /// TextEditingController for the search TextField inside the AppBar.
  final _searchInput = TextEditingController();

  /// Owns all search logic: debouncing, match indexing, navigation.
  late final ChatSearchController _chatSearch;

  /// Last known messages list — kept in sync from the stream so that
  /// [_chatSearch] can be refreshed when new messages arrive.
  List<domain.ChatMessage> _messages = [];

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  /// Per-message GlobalKeys used by [Scrollable.ensureVisible] to scroll to an
  /// exact message without knowing its height. Keyed by message ID.
  final Map<String, GlobalKey> _messageKeys = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chatSearch = ChatSearchController();
    _chatSearch.addListener(_onSearchStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .ensureChatExists(myUid: myUid, targetUid: widget.targetUserId);
      await _updateMyPresence(true);
      await ref
          .read(chatRepositoryProvider)
          .markIncomingAsDelivered(
            chatId: ref
                .read(chatRepositoryProvider)
                .getChatId(myUid, widget.targetUserId),
            myUid: myUid,
          );
      _markAsRead();
    } catch (e) {
      debugPrint('Chat init error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateMyPresence(false);
    _messageController.dispose();
    _searchInput.dispose();
    _chatSearch
      ..removeListener(_onSearchStateChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateMyPresence(true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateMyPresence(false);
    }
  }

  // ── Presence / read helpers ────────────────────────────────────────────────

  Future<void> _updateMyPresence(bool isOnline) async {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .setPresence(uid: myUid, isOnline: isOnline);
    } catch (e) {
      debugPrint('Presence update error: $e');
    }
  }

  void _markAsRead() {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid != null) {
      final chatId = ref
          .read(chatRepositoryProvider)
          .getChatId(myUid, widget.targetUserId);
      ref.read(chatRepositoryProvider).markChatAsRead(chatId, myUid);
    }
  }

  // ── Message sending ────────────────────────────────────────────────────────

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

    ref
        .read(chatRepositoryProvider)
        .sendMessage(
          myUid: myUid,
          senderName:
              ref.read(firebaseAuthProvider).currentUser?.displayName ??
              'Someone',
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

  // ── Search helpers ─────────────────────────────────────────────────────────

  /// Listener attached to [_chatSearch]. Triggers a rebuild and, if a match
  /// is focused, scrolls to it.
  void _onSearchStateChanged() {
    setState(() {});
    final idx = _chatSearch.currentAbsoluteIndex;
    if (idx >= 0 && idx < _messages.length) {
      // Delay one frame so the list has rebuilt with the new highlight before
      // we attempt to scroll — ensures the key's context is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMatch(idx);
      });
    }
  }

  /// Smooth-scrolls to the message at [absoluteIndex] in [_messages], centring
  /// it in the viewport. Uses [Scrollable.ensureVisible] so it works correctly
  /// with variable-height items and a reversed ListView.
  void _scrollToMatch(int absoluteIndex) {
    final message = _messages[absoluteIndex];
    final key = _messageKeys[message.id];
    final context = key?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      // 0.5 centres the item; adjust toward 0.3 to keep it slightly above
      // centre so surrounding messages remain visible.
      alignment: 0.35,
    );
  }

  /// Enters search mode.
  void _enterSearch() => _chatSearch.activate();

  /// Exits search mode, clears the input, and restores normal AppBar.
  void _exitSearch() {
    _searchInput.clear();
    _chatSearch.deactivate();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.forTheme(Theme.of(context));
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatId = ref
        .read(chatRepositoryProvider)
        .getChatId(myUid, widget.targetUserId);
    final messagesStream = ref.watch(chatMessagesStreamProvider(chatId));
    final targetUserStream = ref.watch(
      userDocStreamProvider(widget.targetUserId),
    );

    return Scaffold(
      appBar: _buildAppBar(
        colors: colors,
        myUid: myUid,
        messagesStream: messagesStream,
        targetUserStream: targetUserStream,
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.backgroundTop, colors.backgroundBottom],
                ),
              ),
              child: messagesStream.when(
                data:
                    (messages) => _buildMessageList(
                      messages: messages,
                      myUid: myUid,
                      colors: colors,
                    ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
          if (_replyingTo != null) _buildReplyBanner(colors),
          _buildInputRow(colors),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar({
    required _ChatColors colors,
    required String myUid,
    required AsyncValue<List<domain.ChatMessage>> messagesStream,
    required AsyncValue<DocumentSnapshot> targetUserStream,
  }) {
    final isSearching = _chatSearch.isActive;

    if (isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitSearch,
          tooltip: 'Close search',
        ),
        title: TextField(
          controller: _searchInput,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search messages…',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => _chatSearch.onQueryChanged(v, _messages),
        ),
        actions: [
          // ── Result counter ──────────────────────────────────────────────
          if (_chatSearch.query.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _chatSearch.counterText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // ── Navigate upward (↑ = newer match) ──────────────────────────
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: 'Previous match',
            onPressed:
                _chatSearch.totalMatches > 0
                    ? () => _chatSearch.previousMatch()
                    : null,
          ),
          // ── Navigate downward (↓ = older match) ────────────────────────
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Next match',
            onPressed:
                _chatSearch.totalMatches > 0
                    ? () => _chatSearch.nextMatch()
                    : null,
          ),
        ],
      );
    }

    // ── Normal AppBar ────────────────────────────────────────────────────────
    return AppBar(
      title: targetUserStream.when(
        data: (doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final title =
              widget.targetUserName ?? data['displayName'] as String? ?? 'Chat';
          final isOnlineRaw = data['isOnline'] as bool? ?? false;
          final lastSeenAt = data['lastSeenAt'];
          final isOnline = _isActuallyOnline(
            isOnlineFlag: isOnlineRaw,
            lastSeenAt: lastSeenAt,
          );
          final subtitle = isOnline ? 'online' : _formatLastSeen(lastSeenAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
        loading: () => Text(widget.targetUserName ?? 'Chat'),
        error: (_, __) => Text(widget.targetUserName ?? 'Chat'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search messages',
          onPressed: _enterSearch,
        ),
      ],
    );
  }

  // ── Message list ───────────────────────────────────────────────────────────

  Widget _buildMessageList({
    required List<domain.ChatMessage> messages,
    required String myUid,
    required _ChatColors colors,
  }) {
    // Keep a local reference so search callbacks can access it without
    // a closure capture over a mutable variable.
    _messages = messages;

    // When search is active and the message list changes (e.g. new message
    // arrives), refresh match indexes so the counter stays accurate.
    if (_chatSearch.isActive && _chatSearch.query.isNotEmpty) {
      // Use addPostFrameCallback to avoid calling setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chatSearch.refreshMatches(messages);
      });
    }

    if (!_didInitialRead) {
      _didInitialRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    }

    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Say hello!',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.text),
        ),
      );
    }

    // "No results" banner — shown as a Stack overlay so the full message list
    // remains mounted and the user can still see the conversation.
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          cacheExtent: 600,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == myUid;
            final senderName = isMe ? 'You' : (widget.targetUserName ?? 'User');
            final isGroupedTop =
                index + 1 < messages.length &&
                messages[index + 1].senderId == message.senderId;
            final isGroupedBottom =
                index > 0 && messages[index - 1].senderId == message.senderId;

            // Lazily create a GlobalKey per message for precise scrolling.
            final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

            final isActiveMatch = _chatSearch.currentAbsoluteIndex == index;
            final isMatch = _chatSearch.matchIndexes.contains(index);

            return RepaintBoundary(
              key: key,
              child: _MessageBubble(
                message: message,
                isMe: isMe,
                isGroupedTop: isGroupedTop,
                isGroupedBottom: isGroupedBottom,
                myUid: myUid,
                targetUid: widget.targetUserId,
                senderName: senderName,
                colors: colors,
                onLongPress: () => _setReplyMessage(message, senderName),
                onSwipeReply: () => _setReplyMessage(message, senderName),
                // ── Search highlighting props ──────────────────────────
                searchQuery: _chatSearch.query,
                isActiveMatch: isActiveMatch,
                isMatch: isMatch,
              ),
            );
          },
        ),

        // ── No results overlay ─────────────────────────────────────────
        if (_chatSearch.hasNoResults)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  'No results found',
                  style: TextStyle(
                    color: colors.text.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Reply banner ───────────────────────────────────────────────────────────

  Widget _buildReplyBanner(_ChatColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $_replyingToUserName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.text.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: colors.text),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  // ── Input row ──────────────────────────────────────────────────────────────

  Widget _buildInputRow(_ChatColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: colors.inputBorder),
              ),
              child: TextField(
                controller: _messageController,
                cursorColor: colors.text,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: colors.text.withValues(alpha: 0.74),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colors.outgoingBubble,
            shape: const CircleBorder(),
            child: IconButton(
              icon: Icon(Icons.send, color: colors.sendIcon),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _MessageBubble
// ═════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isGroupedTop,
    required this.isGroupedBottom,
    required this.myUid,
    required this.targetUid,
    required this.senderName,
    required this.colors,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.searchQuery,
    required this.isActiveMatch,
    required this.isMatch,
  });

  final domain.ChatMessage message;
  final bool isMe;
  final bool isGroupedTop;
  final bool isGroupedBottom;
  final String myUid;
  final String targetUid;
  final String senderName;
  final _ChatColors colors;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  // ── Search highlighting ────────────────────────────────────────────────────
  /// Normalised (trimmed, lowercase) search query. Empty when not searching.
  final String searchQuery;

  /// True when this bubble is the currently-focused search match.
  final bool isActiveMatch;

  /// True when this bubble contains at least one match (may or may not be the
  /// focused one).
  final bool isMatch;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const double _maxDragDx = 72;
  static const double _replyTriggerDx = 44;
  double _dragDx = 0;
  bool _replyTriggered = false;

  void _handleDragStart(DragStartDetails _) {
    _replyTriggered = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = (_dragDx + details.delta.dx).clamp(0.0, _maxDragDx);
    if (next == _dragDx) return;
    setState(() => _dragDx = next);
  }

  void _handleDragEnd([DragEndDetails? _]) {
    if (_dragDx >= _replyTriggerDx && !_replyTriggered) {
      _replyTriggered = true;
      widget.onSwipeReply();
    }
    if (_dragDx == 0) return;
    setState(() => _dragDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = widget.colors;
    final isMe = widget.isMe;
    final message = widget.message;
    final dragProgress = (_dragDx / _replyTriggerDx).clamp(0.0, 1.0);
    final bubbleColor = isMe ? colors.outgoingBubble : colors.incomingBubble;
    final messageColor = isMe ? colors.outgoingText : colors.incomingText;

    // Active match: add a glowing gold border on the bubble.
    final activeBorderWidth = widget.isActiveMatch ? 1.8 : 0.0;
    final border =
        isMe
            ? Border.all(
              // Active match overrides the normal gold border.
              color: widget.isActiveMatch ? _activeHighlight : _premiumGold,
              width: widget.isActiveMatch ? activeBorderWidth : 0.8,
            )
            : widget.isActiveMatch
            ? Border.all(color: _activeHighlight, width: activeBorderWidth)
            : null;
    final boxShadow =
        widget.isActiveMatch
            ? [
              BoxShadow(
                color: _activeHighlight.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ]
            : null;

    return Padding(
      padding: EdgeInsets.only(
        top: widget.isGroupedTop ? 1 : 2,
        bottom: widget.isGroupedBottom ? 1 : 2,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: widget.onLongPress,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragEnd,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // ── Swipe-to-reply icon ─────────────────────────────────────
              Positioned(
                left: 8,
                child: Opacity(
                  opacity: dragProgress,
                  child: Icon(
                    Icons.reply,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              // ── Bubble ──────────────────────────────────────────────────
              Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: ChatBubble(
                  message: message.content,
                  time: _formatTime(message.timestamp),
                  isMe: isMe,
                  isGroupedTop: widget.isGroupedTop,
                  isGroupedBottom: widget.isGroupedBottom,
                  bubbleColor: bubbleColor,
                  messageColor: messageColor,
                  timestampColor: colors.timestamp,
                  border: border,
                  boxShadow: boxShadow,
                  transform: Matrix4.translationValues(_dragDx, 0, 0),
                  tailBorderColor: isMe ? colors.outgoingBorder : null,
                  reply:
                      message.replyTo == null
                          ? null
                          : _ReplyPreview(
                            replyTo: message.replyTo!,
                            isMe: isMe,
                            messageColor: messageColor,
                            accentColor:
                                isMe ? colors.replyAccent : theme.primaryColor,
                          ),
                  messageContent: _buildHighlightedText(
                    text: message.content,
                    query: widget.searchQuery,
                    isActiveMatch: widget.isActiveMatch,
                    isMatch: widget.isMatch,
                    baseStyle:
                        theme.textTheme.bodyMedium?.copyWith(
                          color: messageColor,
                          height: 1.3,
                        ) ??
                        TextStyle(color: messageColor, height: 1.3),
                  ),
                  trailing:
                      isMe
                          ? _MessageStatusTicks(
                            message: message,
                            targetUid: widget.targetUid,
                            colors: colors,
                          )
                          : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Highlighted text ─────────────────────────────────────────────────────

  /// Builds a [RichText] widget that highlights every occurrence of [query]
  /// inside [text].
  ///
  /// - Active match bubble: strong gold background, black text, bold.
  /// - Non-active match bubble: subtle semi-transparent gold background.
  /// - No query / no match: falls back to a plain [Text].
  Widget _buildHighlightedText({
    required String text,
    required String query,
    required bool isActiveMatch,
    required bool isMatch,
    required TextStyle baseStyle,
  }) {
    // No search active or this message has no match → plain text.
    if (query.isEmpty || !isMatch) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    int cursor = 0;

    while (cursor < text.length) {
      final matchStart = lower.indexOf(query, cursor);
      if (matchStart == -1) {
        // Remaining text after the last match.
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }

      // Plain text before this match.
      if (matchStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchStart)));
      }

      // The matched substring.
      final matchEnd = matchStart + query.length;
      spans.add(
        TextSpan(
          text: text.substring(matchStart, matchEnd),
          style: TextStyle(
            backgroundColor:
                isActiveMatch ? _activeHighlight : _inactiveHighlight,
            // Black text on the bright gold active highlight for contrast.
            color: isActiveMatch ? Colors.black : null,
            fontWeight: isActiveMatch ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );

      cursor = matchEnd;
    }

    return RichText(text: TextSpan(children: spans, style: baseStyle));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ChatBubble
// ═════════════════════════════════════════════════════════════════════════════

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.time,
    required this.isMe,
    required this.isGroupedTop,
    required this.isGroupedBottom,
    required this.bubbleColor,
    required this.messageColor,
    required this.timestampColor,
    this.border,
    this.boxShadow,
    this.transform,
    this.tailBorderColor,
    this.reply,
    this.messageContent,
    this.trailing,
  });

  final String message;
  final String time;
  final bool isMe;
  final bool isGroupedTop;
  final bool isGroupedBottom;
  final Color bubbleColor;
  final Color messageColor;
  final Color timestampColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Matrix4? transform;
  final Color? tailBorderColor;
  final Widget? reply;
  final Widget? messageContent;
  final Widget? trailing;

  static const double _largeRadius = 16;
  static const double _groupedRadius = 8;
  static const double _speechRadius = 1.2;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: transform,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.67,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: _bubbleRadius(
            isMe: isMe,
            isGroupedTop: isGroupedTop,
            isGroupedBottom: isGroupedBottom,
          ),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null) ...[reply!, const SizedBox(height: 8)],
            messageContent ??
                Text(
                  message,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: messageColor, height: 1.3),
                ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: timestampColor,
                      height: 1,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static BorderRadius _bubbleRadius({
    required bool isMe,
    required bool isGroupedTop,
    required bool isGroupedBottom,
  }) {
    final topSenderRadius = isGroupedTop ? _groupedRadius : _largeRadius;
    final bottomOuterRadius = isGroupedBottom ? _groupedRadius : _largeRadius;

    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(_largeRadius),
        topRight: Radius.circular(topSenderRadius),
        bottomLeft: Radius.circular(bottomOuterRadius),
        bottomRight: Radius.elliptical(
          isGroupedBottom ? _groupedRadius : _speechRadius,
          isGroupedBottom ? _groupedRadius : 6.2,
        ),
      );
    }

    return BorderRadius.only(
      topLeft: Radius.circular(topSenderRadius),
      topRight: const Radius.circular(_largeRadius),
      bottomLeft: Radius.elliptical(
        isGroupedBottom ? _groupedRadius : _speechRadius,
        isGroupedBottom ? _groupedRadius : 6.2,
      ),
      bottomRight: Radius.circular(bottomOuterRadius),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.replyTo,
    required this.isMe,
    required this.messageColor,
    required this.accentColor,
  });

  final ReplyTo replyTo;
  final bool isMe;
  final Color messageColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: messageColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replyTo.senderName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: messageColor.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _MessageStatusTicks  (unchanged)
// ═════════════════════════════════════════════════════════════════════════════

class _MessageStatusTicks extends StatelessWidget {
  const _MessageStatusTicks({
    required this.message,
    required this.targetUid,
    required this.colors,
  });

  final domain.ChatMessage message;
  final String targetUid;
  final _ChatColors colors;

  @override
  Widget build(BuildContext context) {
    final isRead = message.readBy.contains(targetUid);
    final isDelivered = message.deliveredTo.contains(targetUid);

    if (isRead) {
      return Icon(Icons.done_all, size: 16, color: colors.readTick);
    }
    if (isDelivered) {
      return Icon(Icons.done_all, size: 16, color: colors.secondaryTick);
    }
    return Icon(Icons.done, size: 16, color: colors.secondaryTick);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ChatColors  (unchanged)
// ═════════════════════════════════════════════════════════════════════════════

class _ChatColors {
  const _ChatColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.text,
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingText,
    required this.outgoingBorder,
    required this.readTick,
    required this.secondaryTick,
    required this.replyAccent,
    required this.sendIcon,
    required this.inputBorder,
    required this.timestamp,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color text;
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingText;
  final Color outgoingBorder;
  final Color readTick;
  final Color secondaryTick;
  final Color replyAccent;
  final Color sendIcon;
  final Color inputBorder;
  final Color timestamp;

  factory _ChatColors.forTheme(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return const _ChatColors(
        backgroundTop: _chatBgTopDark,
        backgroundBottom: _chatBgBottomDark,
        surface: _chatSurfaceDark,
        text: _chatTextWhite,
        incomingBubble: _incomingBubbleDark,
        outgoingBubble: _chatBubbleBlueDark,
        outgoingText: _chatTextWhite,
        incomingText: _incomingTextDark,
        outgoingBorder: _premiumGold,
        readTick: _premiumGold,
        secondaryTick: Color(0xFF8A96A8),
        replyAccent: _premiumGold,
        sendIcon: _chatTextWhite,
        inputBorder: Color(0x40FFFFFF),
        timestamp: _timestampColor,
      );
    }

    return _ChatColors(
      backgroundTop: theme.colorScheme.surface,
      backgroundBottom: theme.scaffoldBackgroundColor,
      surface: theme.colorScheme.surface,
      text: theme.colorScheme.onSurface,
      incomingBubble: theme.colorScheme.surfaceContainerHighest,
      outgoingBubble: theme.colorScheme.primaryContainer,
      outgoingText: theme.colorScheme.onPrimaryContainer,
      incomingText: theme.colorScheme.onSurface,
      outgoingBorder: theme.colorScheme.primary.withValues(alpha: 0.45),
      readTick: theme.colorScheme.primary,
      secondaryTick: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      replyAccent: theme.colorScheme.primary,
      sendIcon: theme.colorScheme.onPrimary,
      inputBorder: theme.colorScheme.outline.withValues(alpha: 0.42),
      timestamp: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Utility functions  (unchanged)
// ═════════════════════════════════════════════════════════════════════════════

bool _isActuallyOnline({
  required bool isOnlineFlag,
  required dynamic lastSeenAt,
}) {
  if (!isOnlineFlag) return false;
  final dt = (lastSeenAt as Timestamp?)?.toDate();
  if (dt == null) return false;
  return DateTime.now().difference(dt).inMinutes < 2;
}

String _formatLastSeen(dynamic lastSeenAt) {
  final dt = (lastSeenAt as Timestamp?)?.toDate();
  if (dt == null) return 'last seen recently';

  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'last seen just now';
  if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
  return 'last seen ${dt.day}/${dt.month}';
}

String _formatTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

// ═════════════════════════════════════════════════════════════════════════════
// Providers  (unchanged)
// ═════════════════════════════════════════════════════════════════════════════

final chatMessagesStreamProvider =
    StreamProvider.family<List<domain.ChatMessage>, String>((ref, chatId) {
      return ref.watch(chatRepositoryProvider).watchMessages(chatId);
    });

final userDocStreamProvider = StreamProvider.family<DocumentSnapshot, String>((
  ref,
  userId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots();
});
