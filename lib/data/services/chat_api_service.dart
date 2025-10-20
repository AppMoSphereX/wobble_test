import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CancellationToken {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

class ChatApiException implements Exception {
  final String message;
  final String type;
  final int? retryAfterMs;

  ChatApiException({
    required this.message,
    required this.type,
    this.retryAfterMs,
  });

  @override
  String toString() => 'ChatApiException: $message (type: $type)';
}

class ChatApiService {
  final _baseUrl = 'http://localhost:11434/api/generate';
  static const _defaultTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> sendPrompt(String prompt) async {
    final start = DateTime.now();

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': 'gemma3:4b', 'prompt': prompt}),
          )
          .timeout(_defaultTimeout);

      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;

      if (response.statusCode != 200) {
        throw ChatApiException(
          message: 'Server returned ${response.statusCode}',
          type: 'server_error',
          retryAfterMs: 1000,
        );
      }

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
    } on TimeoutException {
      throw ChatApiException(
        message: 'Request timed out after ${_defaultTimeout.inSeconds}s',
        type: 'timeout',
        retryAfterMs: 2000,
      );
    } on SocketException {
      throw ChatApiException(
        message: 'Cannot connect to Ollama. Is it running?',
        type: 'connection_error',
        retryAfterMs: 1500,
      );
    } on http.ClientException catch (e) {
      throw ChatApiException(
        message: 'Network error: ${e.message}',
        type: 'network_error',
        retryAfterMs: 1500,
      );
    } catch (e) {
      if (e is ChatApiException) rethrow;
      throw ChatApiException(
        message: 'Unexpected error: $e',
        type: 'unknown_error',
        retryAfterMs: 1000,
      );
    }
  }

  Stream<String> sendPromptStream(
    String prompt, {
    CancellationToken? cancelToken,
  }) async* {
    try {
      final request = http.Request('POST', Uri.parse(_baseUrl))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'model': 'gemma3:4b', 'prompt': prompt});

      final response = await request.send().timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw ChatApiException(
          message: 'Server returned ${response.statusCode}',
          type: 'server_error',
          retryAfterMs: 1000,
        );
      }

      final utf8Stream = response.stream.transform(utf8.decoder);

      await for (final chunk in utf8Stream) {
        if (cancelToken?.isCancelled ?? false) break;
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (cancelToken?.isCancelled ?? false) break;
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
        if (cancelToken?.isCancelled ?? false) break;
      }
    } on TimeoutException {
      throw ChatApiException(
        message: 'Request timed out after ${_defaultTimeout.inSeconds}s',
        type: 'timeout',
        retryAfterMs: 2000,
      );
    } on SocketException {
      throw ChatApiException(
        message: 'Cannot connect to Ollama. Is it running?',
        type: 'connection_error',
        retryAfterMs: 1500,
      );
    } on http.ClientException catch (e) {
      throw ChatApiException(
        message: 'Network error: ${e.message}',
        type: 'network_error',
        retryAfterMs: 1500,
      );
    } catch (e) {
      if (e is ChatApiException) rethrow;
      if (cancelToken?.isCancelled ?? false) return; // Don't throw on cancel
      throw ChatApiException(
        message: 'Unexpected error: $e',
        type: 'unknown_error',
        retryAfterMs: 1000,
      );
    }
  }
}
