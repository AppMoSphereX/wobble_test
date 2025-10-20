class Message {
  final String text;
  final String role; // 'user' or 'assistant'
  final int? latency; // ms
  final DateTime timestamp;
  final bool hasError;
  final String? errorMessage;
  final String? errorType;

  Message({
    required this.text,
    required this.role,
    this.latency,
    DateTime? timestamp,
    this.hasError = false,
    this.errorMessage,
    this.errorType,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    text: json['text'] as String,
    role: json['role'] as String,
    latency: json['latency'] as int?,
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    hasError: json['hasError'] as bool? ?? false,
    errorMessage: json['errorMessage'] as String?,
    errorType: json['errorType'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'role': role,
    'latency': latency,
    'timestamp': timestamp.toIso8601String(),
    'hasError': hasError,
    'errorMessage': errorMessage,
    'errorType': errorType,
  };

  Message copyWith({
    String? text,
    String? role,
    int? latency,
    DateTime? timestamp,
    bool? hasError,
    String? errorMessage,
    String? errorType,
  }) {
    return Message(
      text: text ?? this.text,
      role: role ?? this.role,
      latency: latency ?? this.latency,
      timestamp: timestamp ?? this.timestamp,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      errorType: errorType ?? this.errorType,
    );
  }
}
