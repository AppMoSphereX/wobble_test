import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final api = ref.read(chatApiServiceProvider);
  return ChatRepository(api);
});
