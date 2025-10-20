class Message {
  final String text;
  final String role; // 'user' or 'assistant'
  final int? latency; // ms
  final DateTime timestamp;

  Message({
    required this.text,
    required this.role,
    this.latency,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    text: json['text'] as String,
    role: json['role'] as String,
    latency: json['latency'] as int?,
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'role': role,
    'latency': latency,
    'timestamp': timestamp.toIso8601String(),
  };
}
