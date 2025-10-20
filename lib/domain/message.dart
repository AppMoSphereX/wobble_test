class Message {
  final String text;
  final String role; // 'user' or 'assistant'
  final int? latency; // ms, for assistant reply only
  
  Message({required this.text, required this.role, this.latency});
}
