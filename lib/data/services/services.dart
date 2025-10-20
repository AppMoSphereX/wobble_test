import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_api_service.dart';

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService();
});
