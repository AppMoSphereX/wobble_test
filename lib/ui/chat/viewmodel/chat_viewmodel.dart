import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import '../../../domain/message.dart';
import '../../../domain/chat_session.dart';
import '../../../domain/ticket.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/chat_api_service.dart'
    show CancellationToken, ChatApiException;

class SupportContext {
  String? product;
  String? issue;
  String? urgency;
  String? ticketId;
  String
  state; // greeting | collecting_product | collecting_issue | collecting_urgency | confirming | complete
  bool
  waitingForConfirmation; // True when we've asked for confirmation and waiting for response

  SupportContext({
    this.product,
    this.issue,
    this.urgency,
    this.ticketId,
    this.state = 'greeting',
    this.waitingForConfirmation = false,
  });

  factory SupportContext.fromJson(Map<String, dynamic> json) => SupportContext(
    product: json['product'],
    issue: json['issue'],
    urgency: json['urgency'],
    ticketId: json['ticketId'],
    state: json['state'] ?? 'greeting',
    waitingForConfirmation: json['waitingForConfirmation'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'product': product,
    'issue': issue,
    'urgency': urgency,
    'ticketId': ticketId,
    'state': state,
    'waitingForConfirmation': waitingForConfirmation,
  };

  void reset() {
    product = null;
    issue = null;
    urgency = null;
    ticketId = null;
    state = 'greeting';
    waitingForConfirmation = false;
  }
}

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repo;
  final _uuid = const Uuid();

  ChatViewModel(this._repo) {
    _loadSessions();
  }

  // Session management
  List<ChatSession> _sessions = [];
  String? _currentSessionId;

  // Ticket management
  List<Ticket> _tickets = [];

  // Current session state
  bool isLoading = false;
  bool _isCancelling = false;
  SupportContext supportContext = SupportContext();
  CancellationToken? _currentCancelToken;
  String? _lastUserMessage; // For retry
  int _retryCount = 0;
  static const _maxRetries = 3;

  static const _sessionsKey = 'chat_sessions';
  static const _currentSessionKey = 'current_session_id';
  static const _contextKeyPrefix = 'support_context_';
  static const _ticketsKey = 'tickets';

  bool get isCancelling => _isCancelling;
  bool get canRetry => _retryCount < _maxRetries;

  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession {
    if (_currentSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.sessionId == _currentSessionId);
    } catch (e) {
      return null;
    }
  }

  List<Message> get messages => currentSession?.messages ?? [];

  // Ticket getters
  List<Ticket> get tickets => _tickets;
  List<Ticket> get openTickets =>
      _tickets.where((t) => t.status == 'open').toList();
  List<Ticket> get resolvedTickets =>
      _tickets.where((t) => t.status == 'resolved').toList();
  Ticket? get currentTicket {
    if (supportContext.ticketId == null) return null;
    try {
      return _tickets.firstWhere((t) => t.ticketId == supportContext.ticketId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();

    // Load all sessions
    final sessionsJson = prefs.getString(_sessionsKey);
    if (sessionsJson != null) {
      final List decoded = jsonDecode(sessionsJson);
      _sessions = decoded
          .map((s) => ChatSession.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    // Load all tickets
    final ticketsJson = prefs.getString(_ticketsKey);
    if (ticketsJson != null) {
      final List decoded = jsonDecode(ticketsJson);
      _tickets = decoded
          .map((t) => Ticket.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    // Load current session ID
    _currentSessionId = prefs.getString(_currentSessionKey);

    // Load support context for current session
    if (_currentSessionId != null) {
      final ctxJson = prefs.getString('$_contextKeyPrefix$_currentSessionId');
      if (ctxJson != null) {
        supportContext = SupportContext.fromJson(jsonDecode(ctxJson));
      }
    }

    // Create first session if no sessions exist
    if (_sessions.isEmpty) {
      await createNewSession();
    } else {
      // If no current session set, use the most recent
      if (_currentSessionId == null || currentSession == null) {
        _currentSessionId = _sessions.first.sessionId;
      }
      notifyListeners();

      // Greet if current session is empty
      if (currentSession?.messages.isEmpty ?? true) {
        await greet();
      }
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();

    // Save all sessions
    final sessionsJson = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, sessionsJson);

    // Save current session ID
    if (_currentSessionId != null) {
      await prefs.setString(_currentSessionKey, _currentSessionId!);

      // Save support context for current session
      await prefs.setString(
        '$_contextKeyPrefix$_currentSessionId',
        jsonEncode(supportContext.toJson()),
      );
    }
  }

  Future<void> _saveTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final ticketsJson = jsonEncode(_tickets.map((t) => t.toJson()).toList());
    await prefs.setString(_ticketsKey, ticketsJson);
  }

  Future<void> createNewSession() async {
    final sessionId = _uuid.v4();
    final newSession = ChatSession.create(sessionId);

    _sessions.insert(0, newSession); // Add to beginning (most recent)
    _currentSessionId = sessionId;
    supportContext.reset();

    await _saveSessions();
    notifyListeners();
    await greet();
  }

  Future<void> switchToSession(String sessionId) async {
    if (_currentSessionId == sessionId) return;

    _currentSessionId = sessionId;

    // Load support context for this session
    final prefs = await SharedPreferences.getInstance();
    final ctxJson = prefs.getString('$_contextKeyPrefix$sessionId');
    if (ctxJson != null) {
      supportContext = SupportContext.fromJson(jsonDecode(ctxJson));
    } else {
      supportContext.reset();
    }

    await prefs.setString(_currentSessionKey, sessionId);
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.sessionId == sessionId);

    // If we deleted the current session, switch to another
    if (_currentSessionId == sessionId) {
      if (_sessions.isNotEmpty) {
        await switchToSession(_sessions.first.sessionId);
      } else {
        await createNewSession();
      }
    }

    // Clean up context for deleted session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_contextKeyPrefix$sessionId');

    await _saveSessions();
    notifyListeners();
  }

  Future<void> clearCurrentSession() async {
    if (_currentSessionId == null) return;

    final sessionIndex = _sessions.indexWhere(
      (s) => s.sessionId == _currentSessionId,
    );
    if (sessionIndex != -1) {
      final clearedSession = _sessions[sessionIndex].copyWith(
        messages: [],
        lastUpdatedAt: DateTime.now(),
      );
      _sessions[sessionIndex] = clearedSession;
      supportContext.reset();

      await _saveSessions();
      notifyListeners();
      await greet();
    }
  }

  Future<void> greet() async {
    if (_currentSessionId == null) return;

    // Reset context for new conversation
    supportContext.reset();

    _updateCurrentSessionMessages((messages) {
      messages.add(
        Message(
          text:
              "Hi! I'm your support assistant. 👋\n\n"
              "I can help you create a support ticket. I'll need to collect a few details:\n"
              "📦 Product name\n"
              "⚠️ Issue description\n"
              "🎯 Priority level\n\n"
              "What product can I help you with today?",
          role: 'assistant',
        ),
      );
    });

    await _saveSessions();
    notifyListeners();
  }

  void _updateCurrentSessionMessages(void Function(List<Message>) updater) {
    if (_currentSessionId == null) return;

    final sessionIndex = _sessions.indexWhere(
      (s) => s.sessionId == _currentSessionId,
    );
    if (sessionIndex != -1) {
      final currentMessages = List<Message>.from(
        _sessions[sessionIndex].messages,
      );
      updater(currentMessages);

      _sessions[sessionIndex] = _sessions[sessionIndex].copyWith(
        messages: currentMessages,
        lastUpdatedAt: DateTime.now(),
      );
    }
  }

  void stopCurrentChat() {
    _isCancelling = true;
    isLoading = false;
    _currentCancelToken?.cancel();
    notifyListeners();
    // Immediately re-enable UI after cancel
    _isCancelling = false;
    notifyListeners();
  }

  Future<void> sendMessageStream(String text, {bool isRetry = false}) async {
    if (_currentSessionId == null) return;

    _isCancelling = false;
    isLoading = true;
    notifyListeners();

    _currentCancelToken?.cancel(); // Cancel previous token if exists
    _currentCancelToken = CancellationToken(); // New token for this run

    // Store for potential retry
    if (!isRetry) {
      _lastUserMessage = text;
      _retryCount = 0;

      // Add user message
      _updateCurrentSessionMessages((messages) {
        messages.add(Message(text: text, role: 'user'));
      });
      notifyListeners();
    }

    // Compose prompt for LLM: include support context
    final prompt = _buildPromptWithContext(text);

    // Add partial assistant message
    _updateCurrentSessionMessages((messages) {
      messages.add(Message(text: '', role: 'assistant'));
    });
    notifyListeners();

    final currentMessages = messages;
    int assistantIndex = currentMessages.length - 1;
    String fullText = '';

    final stream = _repo.sendMessageStream(
      prompt,
      cancelToken: _currentCancelToken,
    );

    final start = DateTime.now();

    try {
      await for (final chunk in stream) {
        if (_isCancelling || (_currentCancelToken?.isCancelled ?? false)) {
          isLoading = false;
          await _saveSessions();
          notifyListeners();
          return; // cut off streaming instantly and keep partial response
        }
        fullText += chunk;

        _updateCurrentSessionMessages((messages) {
          if (assistantIndex < messages.length) {
            messages[assistantIndex] = Message(
              text: fullText,
              role: 'assistant',
            );
          }
        });
        notifyListeners();
      }
      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;

      // Success - reset retry count
      _retryCount = 0;

      // Analyze fullText and slot-fill context
      _updateSupportContext(fullText, userInput: text);

      // Write the last chunk with latency
      _updateCurrentSessionMessages((messages) {
        if (assistantIndex < messages.length) {
          messages[assistantIndex] = Message(
            text: fullText,
            role: 'assistant',
            latency: latency,
          );
        }
      });

      isLoading = false;
      await _saveSessions();
      notifyListeners();
    } catch (e) {
      isLoading = false;
      _retryCount++;

      // Handle the error and create error message
      String errorMessage;
      String errorType;

      if (e is ChatApiException) {
        errorMessage = e.message;
        errorType = e.type;
      } else {
        errorMessage = 'An unexpected error occurred';
        errorType = 'unknown_error';
      }

      // Remove empty assistant message if exists
      _updateCurrentSessionMessages((messages) {
        if (messages.isNotEmpty &&
            messages.last.role == 'assistant' &&
            messages.last.text.isEmpty) {
          messages.removeLast();
        }

        // Add error message
        messages.add(
          Message(
            text: 'Failed to get response',
            role: 'assistant',
            hasError: true,
            errorMessage: errorMessage,
            errorType: errorType,
          ),
        );
      });

      await _saveSessions();
      notifyListeners();
    }
  }

  Future<void> retryLastMessage() async {
    if (_lastUserMessage == null) return;

    // Remove the error message
    _updateCurrentSessionMessages((messages) {
      if (messages.isNotEmpty && messages.last.hasError) {
        messages.removeLast();
      }
    });
    notifyListeners();

    // Retry with the last user message
    await sendMessageStream(_lastUserMessage!, isRetry: true);
  }

  void clearErrorState() {
    _retryCount = 0;
    _lastUserMessage = null;
    notifyListeners();
  }

  Future<void> createTicket() async {
    if (_currentSessionId == null) return;
    if (supportContext.product == null || supportContext.issue == null) return;

    final ticketId = 'T-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final ticket = Ticket(
      ticketId: ticketId,
      sessionId: _currentSessionId!,
      product: supportContext.product!,
      issue: supportContext.issue!,
      urgency: supportContext.urgency ?? 'medium',
      createdAt: DateTime.now(),
    );

    // Store in tickets list
    _tickets.insert(0, ticket); // Most recent first

    // Store in session context
    supportContext.ticketId = ticketId;
    supportContext.state = 'complete';

    await _saveTickets();
    await _saveSessions();
    notifyListeners();

    // Add completion message to chat
    _updateCurrentSessionMessages((messages) {
      messages.add(
        Message(
          text:
              '✅ Ticket #$ticketId created successfully!\n\n'
              '📦 Product: ${ticket.product}\n'
              '⚠️ Issue: ${ticket.issue}\n'
              '${ticket.urgencyEmoji} Priority: ${ticket.urgency}\n\n'
              'We\'ll follow up with you shortly. Is there anything else I can help you with?',
          role: 'assistant',
        ),
      );
    });

    await _saveSessions();
    notifyListeners();
  }

  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    final ticketIndex = _tickets.indexWhere((t) => t.ticketId == ticketId);
    if (ticketIndex != -1) {
      _tickets[ticketIndex] = _tickets[ticketIndex].copyWith(
        status: newStatus,
        resolvedAt: newStatus == 'resolved' ? DateTime.now() : null,
      );
      await _saveTickets();
      notifyListeners();
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    _tickets.removeWhere((t) => t.ticketId == ticketId);
    await _saveTickets();
    notifyListeners();
  }

  // Smart prompting with field extraction
  void _updateSupportContext(
    String assistantReply, {
    required String userInput,
  }) {
    // Parse extracted data from LLM response
    _parseExtractedData(assistantReply);

    // Handle state transitions based on collected data
    switch (supportContext.state) {
      case 'greeting':
        if (supportContext.product != null &&
            supportContext.product != 'none') {
          supportContext.state = 'collecting_issue';
          supportContext.waitingForConfirmation = false;
        }
        break;
      case 'collecting_issue':
        if (supportContext.issue != null && supportContext.issue != 'none') {
          supportContext.state = 'collecting_urgency';
          supportContext.waitingForConfirmation = false;
        }
        break;
      case 'collecting_urgency':
        if (supportContext.urgency != null &&
            supportContext.urgency != 'none') {
          supportContext.state = 'confirming';
          // Mark that we're now waiting for confirmation
          supportContext.waitingForConfirmation = true;
        }
        break;
      case 'confirming':
        // Only process confirmation if we're actively waiting for it
        if (supportContext.waitingForConfirmation) {
          final userLower = userInput.toLowerCase();
          if (userLower.contains('yes') ||
              userLower.contains('confirm') ||
              userLower.contains('submit') ||
              userLower.contains('ok') ||
              userLower.contains('sure')) {
            supportContext.waitingForConfirmation = false;
            createTicket();
          } else if (userLower.contains('no') ||
              userLower.contains('cancel') ||
              userLower.contains('wait')) {
            // Reset for new input
            supportContext.reset();
            supportContext.state = 'greeting';
          }
        }
        break;
      case 'complete':
        // Check if user wants to create another ticket
        final userLower = userInput.toLowerCase();
        if (userLower.contains('new ticket') ||
            userLower.contains('another issue') ||
            userLower.contains('different problem')) {
          supportContext.reset();
          supportContext.state = 'greeting';
        }
        break;
      default:
        break;
    }
  }

  void _parseExtractedData(String llmResponse) {
    // Look for [DATA] markers in LLM response
    final dataMatch = RegExp(
      r'\[DATA\](.*?)\[/DATA\]',
      dotAll: true,
    ).firstMatch(llmResponse);

    if (dataMatch != null) {
      final data = dataMatch.group(1)!;

      // Parse product
      final productMatch = RegExp(
        r'product:\s*(.+?)(?:\n|$)',
        caseSensitive: false,
      ).firstMatch(data);
      if (productMatch != null) {
        final product = productMatch.group(1)!.trim();
        if (product != 'none' && product != 'unknown' && product.isNotEmpty) {
          supportContext.product = product;
        }
      }

      // Parse issue
      final issueMatch = RegExp(
        r'issue:\s*(.+?)(?:\n|$)',
        caseSensitive: false,
      ).firstMatch(data);
      if (issueMatch != null) {
        final issue = issueMatch.group(1)!.trim();
        if (issue != 'none' && issue != 'unknown' && issue.isNotEmpty) {
          supportContext.issue = issue;
        }
      }

      // Parse urgency
      final urgencyMatch = RegExp(
        r'urgency:\s*(.+?)(?:\n|$)',
        caseSensitive: false,
      ).firstMatch(data);
      if (urgencyMatch != null) {
        final urgency = urgencyMatch.group(1)!.trim().toLowerCase();
        if (urgency == 'high' || urgency == 'medium' || urgency == 'low') {
          supportContext.urgency = urgency;
        }
      }
    }
  }

  String _buildPromptWithContext(String userInput) {
    final ctx = supportContext;

    String prompt = '';

    switch (ctx.state) {
      case 'greeting':
        prompt =
            '''You are a helpful support ticket assistant. Your job is to collect information about a support issue.

Currently collecting: PRODUCT NAME

User said: "$userInput"

IMPORTANT: Extract information and format your response like this:

[DATA]
product: <extracted product name or "none" if not mentioned>
issue: none
urgency: none
[/DATA]

Then respond naturally, asking about the product if you couldn't extract it, or moving to ask about the issue if you did extract it.

Remember: Be friendly, clear, and concise. Ask one question at a time.''';
        break;

      case 'collecting_issue':
        prompt =
            '''You are a helpful support ticket assistant collecting issue details.

Product: ${ctx.product}

Currently collecting: ISSUE DESCRIPTION

User said: "$userInput"

IMPORTANT: Extract information and format your response like this:

[DATA]
product: ${ctx.product}
issue: <extracted issue description or "none">
urgency: none
[/DATA]

Then respond naturally, acknowledging the issue if you understood it, or asking for clarification if unclear.''';
        break;

      case 'collecting_urgency':
        prompt =
            '''You are a helpful support ticket assistant collecting urgency level.

Product: ${ctx.product}
Issue: ${ctx.issue}

Currently collecting: URGENCY LEVEL (low, medium, or high)

User said: "$userInput"

IMPORTANT: Extract information and format your response like this:

[DATA]
product: ${ctx.product}
issue: ${ctx.issue}
urgency: <low/medium/high or "none">
[/DATA]

Then respond naturally. If urgency was provided, move to confirmation. Otherwise, ask about urgency.

Note: Interpret "urgent", "asap", "critical" as "high", "not urgent" as "low", and "moderate" as "medium".''';
        break;

      case 'confirming':
        prompt =
            '''You are a helpful support ticket assistant ready to create a ticket.

Ticket Details:
- Product: ${ctx.product}
- Issue: ${ctx.issue}
- Urgency: ${ctx.urgency}

User said: "$userInput"

[DATA]
product: ${ctx.product}
issue: ${ctx.issue}
urgency: ${ctx.urgency}
[/DATA]

IMPORTANT: Summarize the ticket details and ask for confirmation:
"I'm ready to create a support ticket with these details:
📦 Product: ${ctx.product}
⚠️ Issue: ${ctx.issue}
${_getUrgencyEmoji(ctx.urgency)} Priority: ${ctx.urgency}

Should I create this ticket? (Reply yes to confirm)"''';
        break;

      case 'complete':
        prompt =
            '''You are a helpful support ticket assistant. A ticket has been created.

Ticket: ${ctx.ticketId}
Product: ${ctx.product}
Issue: ${ctx.issue}

User said: "$userInput"

[DATA]
product: ${ctx.product}
issue: ${ctx.issue}
urgency: ${ctx.urgency}
[/DATA]

Respond helpfully to the user's message. They may have follow-up questions or want to create another ticket.''';
        break;

      default:
        prompt =
            '''You are a helpful support ticket assistant.

User: $userInput

[DATA]
product: none
issue: none
urgency: none
[/DATA]

Respond helpfully and guide them to create a support ticket.''';
    }

    return prompt;
  }

  String _getUrgencyEmoji(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }
}

final chatViewModelProvider = ChangeNotifierProvider((ref) {
  final repo = ref.read(chatRepositoryProvider);
  return ChatViewModel(repo);
});
