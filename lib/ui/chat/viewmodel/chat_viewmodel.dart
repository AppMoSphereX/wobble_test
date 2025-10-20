import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../../../domain/message.dart';
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
  ChatViewModel(this._repo) {
    _loadMessages();
  }

  List<Message> messages = [];
  bool isLoading = false;
  bool _isCancelling = false;
  SupportContext supportContext = SupportContext();
  CancellationToken? _currentCancelToken;
  String? _lastUserMessage; // For retry
  int _retryCount = 0;
  static const _maxRetries = 3;

  static const _storageKey = 'messages';
  static const _contextKey = 'supportContext';

  bool get isCancelling => _isCancelling;
  bool get canRetry => _retryCount < _maxRetries;

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    final ctxJson = prefs.getString(_contextKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      messages = decoded.map((m) => Message.fromJson(m)).toList().cast<Message>();
      notifyListeners();
    }
    if (ctxJson != null) {
      supportContext = SupportContext.fromJson(jsonDecode(ctxJson));
    }
    // Greet if empty
    if (messages.isEmpty) {
      await greet();
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(messages.map((m) => m.toJson()).toList()));
    await prefs.setString(_contextKey, jsonEncode(supportContext.toJson()));
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_contextKey);
    messages = [];
    supportContext.reset();
    notifyListeners();
    await greet();
  }

  Future<void> greet() async {
    messages.add(Message(
      text: "Hi! I’m your support assistant. What product can I help you with today?",
      role: 'assistant',
    ));
    await _saveMessages();
    notifyListeners();
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
      messages.add(Message(text: text, role: 'user'));
      notifyListeners();
    }

    // Compose prompt for LLM: include support context
    final prompt = _buildPromptWithContext(text);

    // Add partial assistant message
    messages.add(Message(text: '', role: 'assistant'));
    notifyListeners();
    int assistantIndex = messages.length - 1;
    String fullText = '';

    final stream = _repo.sendMessageStream(prompt, cancelToken: _currentCancelToken);

    final start = DateTime.now();

    try {
      await for (final chunk in stream) {
        if (_isCancelling || (_currentCancelToken?.isCancelled ?? false)) {
          isLoading = false;
          await _saveMessages();
          notifyListeners();
          return; // cut off streaming instantly and keep partial response
        }
        fullText += chunk;
        messages[assistantIndex] = Message(
          text: fullText,
          role: 'assistant',
        );
        notifyListeners();
      }
      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;
      
      // Success - reset retry count
      _retryCount = 0;
      
      // Analyze fullText and slot-fill context
      _updateSupportContext(fullText, userInput: text);
      
      // Write the last chunk with latency
      messages[assistantIndex] = Message(
        text: fullText,
        role: 'assistant',
        latency: latency,
      );
      isLoading = false;
      await _saveMessages();
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
      
      await _saveMessages();
      notifyListeners();
    }
  }

  Future<void> retryLastMessage() async {
    if (_lastUserMessage == null) return;
    
    // Remove the error message
    if (messages.isNotEmpty && messages.last.hasError) {
      messages.removeLast();
      notifyListeners();
    }
    
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
