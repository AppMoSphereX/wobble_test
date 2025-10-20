import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/chat_viewmodel.dart';
import 'widgets/message_bubble.dart';
import 'widgets/loading_dots.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(chatViewModelProvider);
    final theme = Theme.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return Scaffold(
      backgroundColor: theme.chatBackgroundColor,
      drawer: _buildSessionDrawer(context, viewModel),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => Semantics(
            label: 'Open chat sessions menu',
            button: true,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Text('🤖', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wobble Chat',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (viewModel.currentSession != null)
              Text(
                viewModel.currentSession!.displayTitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            tooltip: 'New Chat',
            onPressed: () async {
              await viewModel.createNewSession();
              _scrollController.jumpTo(0);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            tooltip: 'Clear Current Chat',
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Clear This Chat?'),
                  content: Text(
                    'This will remove all messages from this chat session. Continue?',
                  ),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Clear'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await viewModel.clearCurrentSession();
                _scrollController.jumpTo(0);
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                itemCount: viewModel.messages.length,
                itemBuilder: (context, index) {
                  final msg = viewModel.messages[index];
                  final isLastMessage = index == viewModel.messages.length - 1;

                  return MessageBubble(
                    message: msg,
                    showRetry:
                        isLastMessage &&
                        viewModel.canRetry &&
                        !viewModel.isLoading,
                    onRetry: () => viewModel.retryLastMessage(),
                  );
                },
              ),
            ),
            if (viewModel.isLoading &&
                (viewModel.messages.isEmpty ||
                    viewModel.messages.last.role == 'assistant'))
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.assistantBubbleColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const LoadingDots(),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(
                left: 10.0,
                right: 10.0,
                bottom: 18.0,
                top: 7,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.inputBackgroundColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Message input field',
                        textField: true,
                        child: TextField(
                          controller: _controller,
                          enabled:
                              !viewModel.isLoading && !viewModel.isCancelling,
                          onSubmitted: (_) {
                            _send(viewModel);
                          },
                          minLines: 1,
                          maxLines: 5,
                          style: TextStyle(
                            fontSize: 16.7,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type your message...',
                            hintStyle: TextStyle(color: theme.hintColor),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if ((viewModel.isLoading && !viewModel.isCancelling))
                      Semantics(
                        label: 'Stop generating message',
                        button: true,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: FloatingActionButton(
                            heroTag: 'stop_btn',
                            elevation: 0,
                            mini: true,
                            backgroundColor: theme.colorScheme.error,
                            tooltip: 'Stop generating',
                            onPressed: () {
                              viewModel.stopCurrentChat();
                              setState(() {});
                            },
                            child: const Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    Semantics(
                      label: _controller.text.trim().isEmpty
                          ? 'Send button disabled, enter a message first'
                          : 'Send message',
                      button: true,
                      enabled:
                          !viewModel.isLoading &&
                          !viewModel.isCancelling &&
                          _controller.text.trim().isNotEmpty,
                      child: FloatingActionButton(
                        elevation: 0,
                        mini: true,
                        backgroundColor:
                            (_controller.text.trim().isEmpty ||
                                viewModel.isLoading ||
                                viewModel.isCancelling)
                            ? theme.disabledColor
                            : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        tooltip: 'Send message',
                        onPressed:
                            viewModel.isLoading ||
                                viewModel.isCancelling ||
                                _controller.text.trim().isEmpty
                            ? null
                            : () {
                                _send(viewModel);
                              },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 2.0),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(ChatViewModel viewModel) {
    // If already loading/cancelling, cancel in-progress request before sending
    if (viewModel.isLoading || viewModel.isCancelling) {
      viewModel.stopCurrentChat();
    }
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      viewModel.sendMessageStream(text);
      _controller.clear();
    }
  }

  Widget _buildSessionDrawer(BuildContext context, ChatViewModel viewModel) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.drawerHeaderColor,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Chat Sessions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${viewModel.sessions.length} ${viewModel.sessions.length == 1 ? 'session' : 'sessions'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await viewModel.createNewSession();
                    _scrollController.jumpTo(0);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(
                      double.infinity,
                      48,
                    ), // Ensure minimum tap target
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text(
                    'New Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Theme Settings
            _buildThemeSettings(context, ref),

            const Divider(height: 1),

            // Session List
            Expanded(
              child: viewModel.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: viewModel.sessions.length,
                      itemBuilder: (context, index) {
                        final session = viewModel.sessions[index];
                        final isCurrentSession =
                            session.sessionId ==
                            viewModel.currentSession?.sessionId;
                        final messageCount = session.messages.length;

                        return Dismissible(
                          key: Key(session.sessionId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: theme.colorScheme.error,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (viewModel.sessions.length == 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cannot delete the last session',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return false;
                            }
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Session?'),
                                content: Text(
                                  'This will permanently delete this chat session.',
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('Cancel'),
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text('Delete'),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            await viewModel.deleteSession(session.sessionId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Session "${session.displayTitle}" deleted',
                                  ),
                                  backgroundColor: Colors.deepPurple,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: ListTile(
                            selected: isCurrentSession,
                            selectedTileColor: theme.selectedTileColor,
                            leading: CircleAvatar(
                              backgroundColor: isCurrentSession
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.chat_bubble,
                                color: isCurrentSession
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              session.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentSession
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isCurrentSession
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              '$messageCount ${messageCount == 1 ? 'message' : 'messages'} • ${_formatRelativeTime(session.lastUpdatedAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentSession)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                if (!isCurrentSession)
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.hintColor,
                                    size: 20,
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete session',
                                  onPressed: viewModel.sessions.length == 1
                                      ? null
                                      : () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Delete Session?'),
                                              content: Text(
                                                'This will permanently delete "${session.displayTitle}".',
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: Text('Cancel'),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  child: Text('Delete'),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await viewModel.deleteSession(
                                              session.sessionId,
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              if (!isCurrentSession) {
                                await viewModel.switchToSession(
                                  session.sessionId,
                                );
                                _scrollController.jumpTo(0);
                                setState(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildThemeSettings(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final currentThemeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Light Mode
          ListTile(
            dense: true,
            leading: Icon(
              Icons.light_mode,
              color: currentThemeMode == ThemeMode.light
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Light Mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: currentThemeMode == ThemeMode.light
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: currentThemeMode == ThemeMode.light
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            trailing: currentThemeMode == ThemeMode.light
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                : null,
            onTap: () async {
              await themeNotifier.setLightMode();
            },
          ),

          // Dark Mode
          ListTile(
            dense: true,
            leading: Icon(
              Icons.dark_mode,
              color: currentThemeMode == ThemeMode.dark
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: currentThemeMode == ThemeMode.dark
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: currentThemeMode == ThemeMode.dark
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            trailing: currentThemeMode == ThemeMode.dark
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                : null,
            onTap: () async {
              await themeNotifier.setDarkMode();
            },
          ),

          // System Default
          ListTile(
            dense: true,
            leading: Icon(
              Icons.brightness_auto,
              color: currentThemeMode == ThemeMode.system
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'System Default',
              style: TextStyle(
                fontSize: 15,
                fontWeight: currentThemeMode == ThemeMode.system
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: currentThemeMode == ThemeMode.system
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Follow device settings',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            trailing: currentThemeMode == ThemeMode.system
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                : null,
            onTap: () async {
              await themeNotifier.setSystemMode();
            },
          ),
        ],
      ),
    );
  }
}
