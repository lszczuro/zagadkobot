import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/models/topic.dart';
import 'package:zagadkobot/services/llm/llm_service.dart';
import 'package:zagadkobot/services/llm/llm_prompt.dart';

/// Fake LLM service do testów — zwraca zadaną odpowiedź strumieniowo.
class FakeLlmService implements LlmService {
  final String _response;
  final Duration _tokenDelay;
  bool _initialized = false;

  FakeLlmService(
    this._response, {
    Duration tokenDelay = Duration.zero,
  }) : _tokenDelay = tokenDelay;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    // Emituje odpowiedź token po tokenie (po słowach).
    final tokens = _response.split(' ');
    for (var i = 0; i < tokens.length; i++) {
      if (_tokenDelay > Duration.zero) {
        await Future<void>.delayed(_tokenDelay);
      }
      yield i == 0 ? tokens[i] : ' ${tokens[i]}';
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

/// Fake LLM, który generuje błąd w środku streama.
class ErrorLlmService implements LlmService {
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    yield 'ZAGADKA: Część';
    throw Exception('Połączenie przerwane');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

void main() {
  group('LlmService mock + Riddle.fromLLMResponse', () {
    final testCases = <(String name, String response, Topic topic, String expectedText, List<String> expectedOptions, int expectedIndex)>[
      (
        'zwierzęta — pies',
        'ZAGADKA: Jakie zwierzę szczeka? A) Kot B) Pies C) Ryba POPRAWNA: B',
        Topic.animals,
        'Jakie zwierzę szczeka?',
        ['Kot', 'Pies', 'Ryba'],
        1,
      ),
      (
        'rośliny — drzewo',
        'ZAGADKA: Co rośnie w lesie i ma liście? A) Samochód B) Komputer C) Drzewo POPRAWNA: C',
        Topic.plants,
        'Co rośnie w lesie i ma liście?',
        ['Samochód', 'Komputer', 'Drzewo'],
        2,
      ),
      (
        'kosmos — słońce',
        'ZAGADKA: Co świeci na niebie w dzień? A) Słońce B) Księżyc C) Gwiazda POPRAWNA: A',
        Topic.space,
        'Co świeci na niebie w dzień?',
        ['Słońce', 'Księżyc', 'Gwiazda'],
        0,
      ),
      (
        'pojazdy — rower',
        'ZAGADKA: Czym jeździsz na dwóch kółkach? A) Samolotem B) Rowerem C) Statkiem POPRAWNA: B',
        Topic.vehicles,
        'Czym jeździsz na dwóch kółkach?',
        ['Samolotem', 'Rowerem', 'Statkiem'],
        1,
      ),
      (
        'zwierzęta — mrówka',
        'ZAGADKA: Kto nosi rzeczy większe od siebie? A) Słoń B) Mrówka C) Wieloryb POPRAWNA: B',
        Topic.animals,
        'Kto nosi rzeczy większe od siebie?',
        ['Słoń', 'Mrówka', 'Wieloryb'],
        1,
      ),
      (
        'rośliny — kaktus',
        'ZAGADKA: Jaka roślina ma kolce i nie potrzebuje dużo wody? A) Róża B) Tulipan C) Kaktus POPRAWNA: C',
        Topic.plants,
        'Jaka roślina ma kolce i nie potrzebuje dużo wody?',
        ['Róża', 'Tulipan', 'Kaktus'],
        2,
      ),
      (
        'kosmos — księżyc',
        'ZAGADKA: Co widać na niebie w nocy i zmienia kształt? A) Samolot B) Księżyc C) Balon POPRAWNA: B',
        Topic.space,
        'Co widać na niebie w nocy i zmienia kształt?',
        ['Samolot', 'Księżyc', 'Balon'],
        1,
      ),
      (
        'pojazdy — samolot',
        'ZAGADKA: Czym lecisz na wakacje? A) Rowerem B) Pociągiem C) Samolotem POPRAWNA: C',
        Topic.vehicles,
        'Czym lecisz na wakacje?',
        ['Rowerem', 'Pociągiem', 'Samolotem'],
        2,
      ),
      (
        'zwierzęta — format z newline',
        'ZAGADKA: Kto żyje w wodzie i ma płetwy?\nA) Ptak\nB) Ryba\nC) Pies\nPOPRAWNA: B',
        Topic.animals,
        'Kto żyje w wodzie i ma płetwy?',
        ['Ptak', 'Ryba', 'Pies'],
        1,
      ),
      (
        'rośliny — format ze spacjami',
        'ZAGADKA:  Jaka roślina daje owoce?   A)  Trawa   B)  Jabłoń   C)  Mech   POPRAWNA:  B',
        Topic.plants,
        'Jaka roślina daje owoce?',
        ['Trawa', 'Jabłoń', 'Mech'],
        1,
      ),
    ];

    for (final (name, response, topic, expectedText, expectedOptions, expectedIndex) in testCases) {
      test('parsuje poprawnie: $name', () async {
        final service = FakeLlmService(response);
        await service.initialize();
        expect(service.isInitialized, isTrue);

        final buffer = StringBuffer();
        await for (final token in service.generateStream('test')) {
          buffer.write(token);
        }

        final riddle = Riddle.fromLLMResponse(
          response: buffer.toString(),
          topic: topic,
        );

        expect(riddle.text, expectedText);
        expect(riddle.options, expectedOptions);
        expect(riddle.correctIndex, expectedIndex);
        expect(riddle.topic, topic);
      });
    }
  });

  group('Edge cases', () {
    test('niepełna odpowiedź LLM nie crashuje — rzuca FormatException', () async {
      final service = FakeLlmService('ZAGADKA: Niedokończona A) Opcja 1');
      await service.initialize();

      final buffer = StringBuffer();
      await for (final token in service.generateStream('test')) {
        buffer.write(token);
      }

      expect(
        () => Riddle.fromLLMResponse(
          response: buffer.toString(),
          topic: Topic.animals,
        ),
        throwsFormatException,
      );
    });

    test('urwana odpowiedź w środku streama — zbiera częściowe dane', () async {
      final service = ErrorLlmService();
      await service.initialize();

      final buffer = StringBuffer();
      Object? caughtError;

      try {
        await for (final token in service.generateStream('test')) {
          buffer.write(token);
        }
      } catch (e) {
        caughtError = e;
      }

      // Stream rzucił błąd, ale nie crashuje
      expect(caughtError, isA<Exception>());
      // Częściowe dane zostały zebrane przed błędem
      expect(buffer.toString(), contains('ZAGADKA'));
    });

    test('pusty response rzuca FormatException', () {
      expect(
        () => Riddle.fromLLMResponse(response: '', topic: Topic.animals),
        throwsFormatException,
      );
    });

    test('brak POPRAWNA rzuca FormatException', () async {
      final service = FakeLlmService(
        'ZAGADKA: Pytanie? A) Opcja 1 B) Opcja 2 C) Opcja 3',
      );
      await service.initialize();

      final buffer = StringBuffer();
      await for (final token in service.generateStream('test')) {
        buffer.write(token);
      }

      expect(
        () => Riddle.fromLLMResponse(
          response: buffer.toString(),
          topic: Topic.animals,
        ),
        throwsFormatException,
      );
    });

    test('dispose resetuje isInitialized', () async {
      final service = FakeLlmService('test');
      await service.initialize();
      expect(service.isInitialized, isTrue);
      await service.dispose();
      expect(service.isInitialized, isFalse);
    });
  });

  group('llmSystemPrompt', () {
    test('zawiera wymagane sekcje formatu', () {
      expect(llmSystemPrompt, contains('ZAGADKA:'));
      expect(llmSystemPrompt, contains('A)'));
      expect(llmSystemPrompt, contains('B)'));
      expect(llmSystemPrompt, contains('C)'));
      expect(llmSystemPrompt, contains('POPRAWNA:'));
    });

    test('jest po polsku i wspomina dzieci', () {
      expect(llmSystemPrompt, contains('dzieci'));
      expect(llmSystemPrompt, contains('polsku'));
    });
  });

  group('buildRiddlePrompt', () {
    test('buduje prompt z nazwą tematu', () {
      expect(buildRiddlePrompt('Zwierzęta'), 'Wymyśl zagadkę na temat: Zwierzęta');
    });
  });
}
