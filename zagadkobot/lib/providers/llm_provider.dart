import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_llama_cpp.dart';

/// Provider LLM serwisu — keepAlive, bo model ładujemy raz i trzymamy w pamięci.
final llmProvider = Provider<LlmService>((ref) {
  final service = LlmServiceLlamaCpp();
  ref.onDispose(() => service.dispose());
  return service;
});
