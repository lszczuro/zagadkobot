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
  String? _modelName;

  /// Parametry inference.
  static const double temperature = 0.5;
  static const double topP = 0.9;
  static const int maxTokens = 60;
  static const int nThreads = 4;

  @override
  bool get isInitialized => _initialized;

  @override
  String? get modelName => _modelName;

  @override
  Future<void> initialize() async {
    _modelName = await _methodChannel.invokeMethod<String>('initialize', {
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      'n_threads': nThreads,
      'system_prompt': llmSystemPrompt,
    });
    _initialized = true;
    _modelName ??= 'nieznany';
  }

  @override
  Stream<String> generateStream(String prompt) {
    assert(isInitialized, 'Wywołaj initialize() przed generateStream()');

    final controller = StreamController<String>();

    // Najpierw podpinamy EventChannel (żeby EventSink był gotowy),
    // dopiero potem startujemy generowanie.
    final subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          controller.add(event);
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
