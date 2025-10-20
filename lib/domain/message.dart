class Message {
  final String text;
  final String role; // 'user' or 'assistant'
  final int? latency; // ms, for assistant reply only
  
  Message({required this.text, required this.role, this.latency});

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    text: json['text'] as String,
    role: json['role'] as String,
    latency: json['latency'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'role': role,
    'latency': latency,
  };
}
