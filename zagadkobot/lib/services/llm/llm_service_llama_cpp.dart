import 'dart:async';

import 'package:flutter/services.dart';

import 'llm_service.dart';
import 'llm_prompt.dart';

/// Implementacja [LlmService] oparta na llama.cpp via platform channel.
///
/// Komunikuje się z natywnym kodem Kotlin/C++ przez MethodChannel i
/// EventChannel do streamowania tokenów.
class LlmServiceLlamaCpp implements LlmService {
  static const _methodChannel = MethodChannel('com.zagadkownik/llama');
  static const _eventChannel = EventChannel('com.zagadkownik/llama_stream');

  bool _initialized = false;

  /// Parametry inference.
  static const double temperature = 0.8;
  static const double topP = 0.9;
  static const int maxTokens = 100;
  static const int nThreads = 8;

  /// Regex detecting a complete riddle response — stops generation early.
  static final _completeRiddlePattern =
      RegExp(r'CORRECT:\s*[ABC]', caseSensitive: false);

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    await _methodChannel.invokeMethod<void>('initialize', {
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      'n_threads': nThreads,
      'system_prompt': llmSystemPrompt,
    });
    _initialized = true;
  }

  @override
  Stream<String> generateStream(String prompt) {
    assert(isInitialized, 'Wywołaj initialize() przed generateStream()');

    final controller = StreamController<String>();
    final buffer = StringBuffer();

    // Najpierw podpinamy EventChannel (żeby EventSink był gotowy),
    // dopiero potem startujemy generowanie.
    final subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          buffer.write(event);
          controller.add(event);

          // Stop generation once we have a complete riddle
          if (_completeRiddlePattern.hasMatch(buffer.toString())) {
            _methodChannel.invokeMethod<void>('stopGeneration');
            controller.close();
          }
        }
      },
      onError: (Object error) {
        controller.addError(
          error is Exception ? error : Exception(error.toString()),
        );
        controller.close();
      },
      onDone: () => controller.close(),
    );

    controller.onCancel = () {
      subscription.cancel();
      _methodChannel.invokeMethod<void>('stopGeneration');
    };

    // Teraz startujemy generowanie — EventSink jest już podpięty po stronie Kotlin
    _methodChannel
        .invokeMethod<void>('startGeneration', {'prompt': prompt})
        .catchError((Object error) {
      controller.addError(
        error is Exception ? error : Exception(error.toString()),
      );
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
    _initialized = false;
  }
}
