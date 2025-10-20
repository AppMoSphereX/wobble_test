import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import '../../../domain/message.dart';
import '../../../domain/chat_session.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/chat_api_service.dart' show CancellationToken, ChatApiException;

class SupportContext {
  String? product;
  String? issue;
  String? urgency;
  String? ticketId;
  String state; // greeting | collecting_product | collecting_issue | collecting_urgency | confirming | complete

  SupportContext({
    this.product,
    this.issue,
    this.urgency,
    this.ticketId,
    this.state = 'greeting',
  });

  factory SupportContext.fromJson(Map<String, dynamic> json) => SupportContext(
    product: json['product'],
    issue: json['issue'],
    urgency: json['urgency'],
    ticketId: json['ticketId'],
    state: json['state'] ?? 'greeting',
  );

  Map<String, dynamic> toJson() => {
    'product': product,
    'issue': issue,
    'urgency': urgency,
    'ticketId': ticketId,
    'state': state,
  };

  void reset() {
    product = null;
    issue = null;
    urgency = null;
    ticketId = null;
    state = 'greeting';
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
    
    final sessionIndex = _sessions.indexWhere((s) => s.sessionId == _currentSessionId);
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
    
    _updateCurrentSessionMessages((messages) {
      messages.add(Message(
        text: "Hi! I'm your support assistant. What product can I help you with today?",
        role: 'assistant',
      ));
    });
    
    await _saveSessions();
    notifyListeners();
  }

  void _updateCurrentSessionMessages(void Function(List<Message>) updater) {
    if (_currentSessionId == null) return;
    
    final sessionIndex = _sessions.indexWhere((s) => s.sessionId == _currentSessionId);
    if (sessionIndex != -1) {
      final currentMessages = List<Message>.from(_sessions[sessionIndex].messages);
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

    final stream = _repo.sendMessageStream(prompt, cancelToken: _currentCancelToken);

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
        messages.add(Message(
          text: 'Failed to get response',
          role: 'assistant',
          hasError: true,
          errorMessage: errorMessage,
          errorType: errorType,
        ));
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

  // Demo implementation: simple keyword fill and state management
  void _updateSupportContext(String assistantReply, {required String userInput}) {
    // Only change state if currently in-greeting
    switch (supportContext.state) {
      case 'greeting':
        // Assume user is naming a product
        supportContext.product = userInput.trim();
        supportContext.state = 'collecting_issue';
        break;
      case 'collecting_issue':
        supportContext.issue = userInput.trim();
        supportContext.state = 'collecting_urgency';
        break;
      case 'collecting_urgency':
        // Try to extract urgency
        var urg = _extractUrgency(userInput.trim());
        supportContext.urgency = urg;
        supportContext.state = 'confirming';
        break;
      case 'confirming':
        // If user says yes/confirm
        if (userInput.toLowerCase().contains('yes')) {
          supportContext.ticketId = 'T-${DateTime.now().millisecondsSinceEpoch % 100000}';
          supportContext.state = 'complete';
        } else {
          // Reset for new input
          supportContext.state = 'collecting_product';
        }
        break;
      case 'complete':
        // Stay or potentially restart if needed
        break;
      default:
        break;
    }
  }

  String _extractUrgency(String input) {
    final l = input.toLowerCase();
    if (l.contains('high')) return 'high';
    if (l.contains('medium')) return 'medium';
    if (l.contains('low')) return 'low';
    return 'unknown';
  }

  String _buildPromptWithContext(String userInput) {
    final ctx = supportContext;
    // Dynamic system prompt to steer the LLM
    final system = '''\nYou are a support assistant.\nCurrent context:\nProduct: ${ctx.product ?? 'not yet provided'}\nIssue: ${ctx.issue ?? 'not yet provided'}\nUrgency: ${ctx.urgency ?? 'not yet provided'}\nTicket ID: ${ctx.ticketId ?? ''}\nState: ${ctx.state}\nIf product is missing, ask about product. If issue is missing, ask about issue. If urgency missing, ask for urgency. After all, summarize and ask to confirm. If confirmed, show ticket ID. Always be clear and concise.''';
    return "$system\nUser: $userInput";
  }
}

final chatViewModelProvider = ChangeNotifierProvider((ref) {
  final repo = ref.read(chatRepositoryProvider);
  return ChatViewModel(repo);
});
