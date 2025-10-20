import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/message.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/repositories.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repo;
  final Ref _ref;

  ChatViewModel(this._repo, this._ref);

  List<Message> messages = [];
  bool isLoading = false;

  Future<void> sendMessage(String text) async {
    isLoading = true;
    notifyListeners();

    final (reply, latency) = await _repo.sendMessage(text);
    messages.add(Message(text: text, role: 'user'));
    messages.add(Message(text: reply, role: 'assistant', latency: latency));

    isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessageStream(String text) async {
    isLoading = true;
    notifyListeners();
    final start = DateTime.now();
    // Add user message
    messages.add(Message(text: text, role: 'user'));
    // Add assistant partial message
    messages.add(Message(text: '', role: 'assistant'));
    notifyListeners();
    int assistantIndex = messages.length - 1;
    String fullText = '';
    await for (var chunk in _repo.sendMessageStream(text)) {
      fullText += chunk;
      messages[assistantIndex] = Message(
        text: fullText,
        role: 'assistant',
      );
      notifyListeners();
    }
    final end = DateTime.now();
    final latency = end.difference(start).inMilliseconds;
    // Write the last chunk with latency
    messages[assistantIndex] = Message(
      text: fullText,
      role: 'assistant',
      latency: latency,
    );
    isLoading = false;
    notifyListeners();
  }
}

final chatViewModelProvider = ChangeNotifierProvider((ref) {
  final repo = ref.read(chatRepositoryProvider);
  return ChatViewModel(repo, ref);
});
