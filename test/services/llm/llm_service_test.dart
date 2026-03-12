import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/services/llm/llm_service.dart';
import 'package:zagadkobot/services/llm/llm_prompt.dart';

// ---------------------------------------------------------------------------
// Fake LLM service — zwraca zadaną odpowiedź token po tokenie (słowo = token)
// ---------------------------------------------------------------------------

class FakeLlmService implements LlmService {
  final String _response;
  bool _initialized = false;

  FakeLlmService(this._response);

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Stream<String> generateStream(String prompt) async* {
    final tokens = _response.split(' ');
    for (var i = 0; i < tokens.length; i++) {
      yield i == 0 ? tokens[i] : ' ${tokens[i]}';
    }
  }

  @override
  Future<void> dispose() async => _initialized = false;
}

// ---------------------------------------------------------------------------
// Fake LLM — rzuca błąd w połowie streama
// ---------------------------------------------------------------------------

class ErrorLlmService implements LlmService {
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Stream<String> generateStream(String prompt) async* {
    yield 'Brawo!';
    throw Exception('Połączenie przerwane');
  }

  @override
  Future<void> dispose() async => _initialized = false;
}

// ---------------------------------------------------------------------------
// Testy
// ---------------------------------------------------------------------------

void main() {
  group('FakeLlmService', () {
    test('initialize ustawia isInitialized = true', () async {
      final service = FakeLlmService('test');
      expect(service.isInitialized, isFalse);
      await service.initialize();
      expect(service.isInitialized, isTrue);
    });

    test('dispose resetuje isInitialized', () async {
      final service = FakeLlmService('test');
      await service.initialize();
      await service.dispose();
      expect(service.isInitialized, isFalse);
    });

    test('generateStream emituje pełną odpowiedź', () async {
      final service = FakeLlmService('Brawo jesteś super');
      await service.initialize();

      final buffer = StringBuffer();
      await for (final token in service.generateStream('prompt')) {
        buffer.write(token);
      }

      expect(buffer.toString(), 'Brawo jesteś super');
    });

    test('generateStream scala tokeny w kolejności', () async {
      final service = FakeLlmService('A B C');
      await service.initialize();

      final tokens = <String>[];
      await for (final token in service.generateStream('')) {
        tokens.add(token);
      }

      expect(tokens.join(), 'A B C');
    });
  });

  group('ErrorLlmService', () {
    test('strumień rzuca wyjątek, ale wcześniejsze tokeny są dostępne', () async {
      final service = ErrorLlmService();
      await service.initialize();

      final buffer = StringBuffer();
      Object? caughtError;
      try {
        await for (final token in service.generateStream('')) {
          buffer.write(token);
        }
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isA<Exception>());
      expect(buffer.toString(), contains('Brawo'));
    });
  });

  group('llmSystemPrompt', () {
    test('nie jest pustym stringiem', () {
      expect(llmSystemPrompt.trim(), isNotEmpty);
    });

    test('wspomina o dzieciach', () {
      expect(llmSystemPrompt.toLowerCase(), contains('dzieci'));
    });

    test('wspomina o Zgadusiu', () {
      expect(llmSystemPrompt, contains('Zgadusiem'));
    });
  });

  group('buildCommentaryPrompt', () {
    test('zawiera treść zagadki', () {
      final prompt = buildCommentaryPrompt(
        question: 'Kto szczeka?',
        correctAnswer: 'Pies',
        chosenAnswer: 'Pies',
        isCorrect: true,
      );
      expect(prompt, contains('Kto szczeka?'));
    });

    test('zawiera poprawną odpowiedź', () {
      final prompt = buildCommentaryPrompt(
        question: 'Kto szczeka?',
        correctAnswer: 'Pies',
        chosenAnswer: 'Pies',
        isCorrect: true,
      );
      expect(prompt, contains('Pies'));
    });

    test('dodaje ✓ przy poprawnej odpowiedzi', () {
      final prompt = buildCommentaryPrompt(
        question: 'Kto szczeka?',
        correctAnswer: 'Pies',
        chosenAnswer: 'Pies',
        isCorrect: true,
      );
      expect(prompt, contains('✓'));
      expect(prompt, isNot(contains('✗')));
    });

    test('dodaje ✗ przy błędnej odpowiedzi', () {
      final prompt = buildCommentaryPrompt(
        question: 'Kto szczeka?',
        correctAnswer: 'Pies',
        chosenAnswer: 'Kot',
        isCorrect: false,
      );
      expect(prompt, contains('✗'));
      expect(prompt, isNot(contains('✓')));
    });

    test('format zgodny z danymi treningowymi', () {
      final prompt = buildCommentaryPrompt(
        question: 'Kto szczeka?',
        correctAnswer: 'Pies',
        chosenAnswer: 'Kot',
        isCorrect: false,
      );
      // Sprawdź że format jest dokładnie taki jak w training_chatml.json
      expect(prompt, contains('Zagadka: Kto szczeka?'));
      expect(prompt, contains('Prawidłowa odpowiedź: Pies'));
      expect(prompt, contains('Dziecko wybrało: Kot ✗'));
    });
  });
}
