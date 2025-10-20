import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatApiService {
  final _baseUrl = 'http://localhost:11434/api/generate';

  Future<Map<String, dynamic>> sendPrompt(String prompt) async {
    final start = DateTime.now();
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'gemma3:4b',
        'prompt': prompt,
      }),
    );
    final end = DateTime.now();
    final latency = end.difference(start).inMilliseconds;

    debugPrint(response.body); // Still print for debug

    // Combine all 'response' fields from each JSON line
    final lines = response.body.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final jsonObj = jsonDecode(line);
        final piece = jsonObj['response'];
        if (piece != null && piece is String) buffer.write(piece);
      } catch (_) {
        // Ignore lines that aren't valid JSON
      }
    }

    return {
      'data': {'response': buffer.toString()},
      'latencyMs': latency,
    };
  }

  Stream<String> sendPromptStream(String prompt) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'model': 'gemma3:4b', 'prompt': prompt});
    final response = await request.send();
    final utf8Stream = response.stream.transform(utf8.decoder);

    await for (final chunk in utf8Stream) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final jsonObj = jsonDecode(line);
          final piece = jsonObj['response'];
          if (piece != null && piece is String) {
            yield piece;
          }
        } catch (_) {
          // Ignore lines that aren't valid JSON
        }
      }
    }
  }
}
