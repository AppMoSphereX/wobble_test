import '../services/chat_api_service.dart';

class ChatRepository {
  final ChatApiService _api;
  ChatRepository(this._api);

  Future<(String reply, int latencyMs)> sendMessage(String text) async {
    final result = await _api.sendPrompt(text);
    final reply = result['data']?['response']?.toString() ?? '';
    final latency = result['latencyMs'] is int ? result['latencyMs'] as int : int.tryParse('${result['latencyMs']}') ?? 0;
    return (reply, latency);
  }

  Stream<String> sendMessageStream(String text) {
    return _api.sendPromptStream(text);
  }
}
