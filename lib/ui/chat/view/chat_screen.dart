import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/chat_viewmodel.dart';

class ChatScreen extends ConsumerWidget {
  ChatScreen({super.key});

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(chatViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wobble Chat - Ollama LLM')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: viewModel.messages.length,
              itemBuilder: (context, index) {
                final msg = viewModel.messages[index];
                return ListTile(
                  title: Align(
                    alignment: msg.role == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.role == 'user'
                            ? Colors.blue[200]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.text),
                          if (msg.latency != null)
                            Text('⏱ ${msg.latency} ms',
                                style: TextStyle(fontSize: 11, color: Colors.black54))
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (viewModel.isLoading)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(viewModel),
                    decoration: const InputDecoration(
                      labelText: 'Enter message...'
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: viewModel.isLoading
                      ? null
                      : () => _send(viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send(ChatViewModel viewModel) {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      viewModel.sendMessageStream(text);
      _controller.clear();
    }
  }
}
