import 'message.dart';

class ChatSession {
  final String sessionId;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final String? title; // Auto-generated or user-provided

  ChatSession({
    required this.sessionId,
    required this.messages,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.title,
  });

  factory ChatSession.create(String sessionId) {
    final now = DateTime.now();
    return ChatSession(
      sessionId: sessionId,
      messages: [],
      createdAt: now,
      lastUpdatedAt: now,
      title: null,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['sessionId'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'title': title,
    };
  }

  ChatSession copyWith({
    String? sessionId,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    String? title,
  }) {
    return ChatSession(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      title: title ?? this.title,
    );
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (messages.isEmpty) return 'New Chat';
    // Generate title from first user message
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => messages.first,
    );
    final text = firstUserMessage.text;
    if (text.length > 40) {
      return '${text.substring(0, 40)}...';
    }
    return text.isNotEmpty ? text : 'New Chat';
  }
}

