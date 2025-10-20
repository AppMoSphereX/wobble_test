import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/chat_viewmodel.dart';

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

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(chatViewModelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      drawer: _buildSessionDrawer(context, viewModel),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 68,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text('🤖', style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wobble Chat',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            if (viewModel.currentSession != null)
              Text(
                viewModel.currentSession!.displayTitle,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.deepPurple,
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
              color: Colors.deepPurple,
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
                  final isUser = msg.role == 'user';
                  final hasError = msg.hasError;
                  final bubbleColor = hasError
                      ? Colors.red[50]
                      : (isUser ? Colors.deepPurple[400] : Colors.white);
                  final textColor = isUser ? Colors.white : Colors.black87;
                  final align = isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft;
                  final isLastMessage = index == viewModel.messages.length - 1;
                  
                  return Align(
                    alignment: align,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        padding: EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.77,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          border: hasError
                              ? Border.all(color: Colors.red[300]!, width: 1.5)
                              : null,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hasError
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.07),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.red[700],
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        msg.errorMessage ?? 'An error occurred',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SelectableText(
                              msg.text,
                              style: TextStyle(
                                fontSize: 16.5,
                                color: hasError ? Colors.red[900] : textColor,
                                fontFamily: 'RobotoMono',
                              ),
                              textAlign: TextAlign.left,
                            ),
                            if (hasError && isLastMessage && viewModel.canRetry)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: viewModel.isLoading
                                        ? null
                                        : () => viewModel.retryLastMessage(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: Icon(Icons.refresh_rounded, size: 20),
                                    label: Text(
                                      'Retry',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!hasError)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTimestamp(msg.timestamp),
                                    style: TextStyle(fontSize: 11, color: Colors.black38),
                                  ),
                                  if (msg.latency != null && !isUser && msg.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 5.0),
                                      child: Text('⏱ ${msg.latency} ms', style: TextStyle(fontSize: 11.5, color: Colors.black45)),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: Offset(0, 1),
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
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.06),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !viewModel.isLoading && !viewModel.isCancelling,
                        onSubmitted: (_) {
                          _send(viewModel);
                        },
                        minLines: 1,
                        maxLines: 5,
                        style: TextStyle(fontSize: 16.7, color: Colors.black87),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if ((viewModel.isLoading && !viewModel.isCancelling))
                      Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: FloatingActionButton(
                          heroTag: 'stop_btn',
                          elevation: 0,
                          mini: true,
                          backgroundColor: Colors.redAccent,
                          onPressed: () {
                            viewModel.stopCurrentChat();
                            setState(() {});
                          },
                          child: Icon(Icons.stop, color: Colors.white, size: 24),
                        ),
                      ),
                    FloatingActionButton(
                      elevation: 0,
                      mini: true,
                      backgroundColor:
                          (_controller.text.trim().isEmpty || viewModel.isLoading || viewModel.isCancelling)
                          ? Colors.grey[300]
                          : Colors.deepPurpleAccent.shade200,
                      foregroundColor: Colors.white,
                      onPressed:
                          viewModel.isLoading || viewModel.isCancelling || _controller.text.trim().isEmpty
                          ? null
                          : () {
                              _send(viewModel);
                            },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2.0),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
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
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.deepPurple, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Chat Sessions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${viewModel.sessions.length} ${viewModel.sessions.length == 1 ? 'session' : 'sessions'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
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
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.add_rounded, size: 22),
                  label: Text(
                    'New Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            
            Divider(height: 1),
            
            // Session List
            Expanded(
              child: viewModel.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: viewModel.sessions.length,
                      itemBuilder: (context, index) {
                        final session = viewModel.sessions[index];
                        final isCurrentSession = session.sessionId == viewModel.currentSession?.sessionId;
                        final messageCount = session.messages.length;
                        
                        return Dismissible(
                          key: Key(session.sessionId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (viewModel.sessions.length == 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot delete the last session'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return false;
                            }
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Session?'),
                                content: Text('This will permanently delete this chat session.'),
                                actions: [
                                  TextButton(
                                    child: Text('Cancel'),
                                    onPressed: () => Navigator.pop(context, false),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text('Delete'),
                                    onPressed: () => Navigator.pop(context, true),
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
                                  content: Text('Session "${session.displayTitle}" deleted'),
                                  backgroundColor: Colors.deepPurple,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: ListTile(
                            selected: isCurrentSession,
                            selectedTileColor: Colors.deepPurple[50],
                            leading: CircleAvatar(
                              backgroundColor: isCurrentSession
                                  ? Colors.deepPurple
                                  : Colors.grey[300],
                              child: Icon(
                                Icons.chat_bubble,
                                color: isCurrentSession ? Colors.white : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            title: Text(
                              session.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentSession ? FontWeight.w600 : FontWeight.normal,
                                color: isCurrentSession ? Colors.deepPurple[700] : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '$messageCount ${messageCount == 1 ? 'message' : 'messages'} • ${_formatRelativeTime(session.lastUpdatedAt)}',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentSession)
                                  Icon(Icons.check_circle, color: Colors.deepPurple, size: 20),
                                if (!isCurrentSession)
                                  Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                                SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
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
                                                  onPressed: () => Navigator.pop(context, false),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: Text('Delete'),
                                                  onPressed: () => Navigator.pop(context, true),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await viewModel.deleteSession(session.sessionId);
                                          }
                                        },
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              if (!isCurrentSession) {
                                await viewModel.switchToSession(session.sessionId);
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
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});
  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        int tick = (_controller.value * 4).floor();
        String dots = '.' * (tick % 4);
        return Text(
          'Thinking$dots',
          style: TextStyle(fontSize: 15, color: Colors.deepPurple),
        );
      },
    );
  }
}
