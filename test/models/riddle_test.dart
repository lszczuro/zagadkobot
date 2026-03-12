import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/models/topic.dart';

void main() {
  group('Riddle JSON target round-trip', () {
    test('serialize to JSON and deserialize back', () {
      final riddle = Riddle(
        text: 'Co to za zwierzę, które szczeka?',
        options: ['Kot', 'Pies', 'Słoń'],
        correctIndex: 1,
        topic: Topic.animals,
      );

      final json = riddle.toJson();
      expect(json, {
        'text': 'Co to za zwierzę, które szczeka?',
        'options': ['Kot', 'Pies', 'Słoń'],
        'correctIndex': 1,
        'topic': 'animals',
      });

      final rebuilt = Riddle.fromJson(json);
      expect(rebuilt.text, riddle.text);
      expect(rebuilt.options, riddle.options);
      expect(rebuilt.correctIndex, riddle.correctIndex);
      expect(rebuilt.topic, riddle.topic);
    });
  });

  group('Riddle.fromLLMResponse', () {
    test('parsuje poprawny format (z przerwami na nowe linie)', () {
      const response = '''
ZAGADKA: Co to za zwierzę?
A) Opcja 1
B) Opcja 2
C) Opcja 3
POPRAWNA: B
''';
      final riddle = Riddle.fromLLMResponse(
        response: response,
        topic: Topic.animals,
      );
      expect(riddle.text, 'Co to za zwierzę?');
      expect(riddle.options, ['Opcja 1', 'Opcja 2', 'Opcja 3']);
      expect(riddle.correctIndex, 1);
    });

    test('obsługuje brak newline', () {
      const response =
          'ZAGADKA: Dlaczego tak? A) Nie B) Tak C) Może POPRAWNA: C';
      final riddle = Riddle.fromLLMResponse(
        response: response,
        topic: Topic.plants,
      );
      expect(riddle.text, 'Dlaczego tak?');
      expect(riddle.options, ['Nie', 'Tak', 'Może']);
      expect(riddle.correctIndex, 2);
    });

    test('obsługuje inną kolejność sekcji i białe znaki', () {
      const response =
          ' A) Opcja 1 C)  Opcja 3  POPRAWNA:\t\tA  ZAGADKA:    Pytanie  \n B)Opcja 2 \n\n ';
      final riddle = Riddle.fromLLMResponse(
        response: response,
        topic: Topic.space,
      );
      expect(riddle.text, 'Pytanie');
      expect(riddle.options, ['Opcja 1', 'Opcja 2', 'Opcja 3']);
      expect(riddle.correctIndex, 0);
    });

    test('obsługuje brak słowa ZAGADKA, gdy tekst pojawia się na początku', () {
      const response =
          'Pytanie bez nagłówka? A) Opcja 1 B) Opcja 2 C) Opcja 3 POPRAWNA: A';
      final riddle = Riddle.fromLLMResponse(
        response: response,
        topic: Topic.animals,
      );
      expect(riddle.text, 'Pytanie bez nagłówka?');
      expect(riddle.options, ['Opcja 1', 'Opcja 2', 'Opcja 3']);
      expect(riddle.correctIndex, 0);
    });

    test(
      'rzuca FormatException przy niepełnych danych (brak C i POPRAWNA)',
      () {
        const response = 'ZAGADKA: Niepelne A) 1 B) 2';
        expect(
          () =>
              Riddle.fromLLMResponse(response: response, topic: Topic.vehicles),
          throwsFormatException,
        );
      },
    );

    test(
      'rzuca FormatException dla nieznanej poprawnej odpowiedzi (np. D)',
      () {
        const response = 'ZAGADKA: Z? A) 1 B) 2 C) 3 POPRAWNA: D';
        expect(
          () =>
              Riddle.fromLLMResponse(response: response, topic: Topic.vehicles),
          throwsFormatException,
        );
      },
    );
  });

  group('Riddle assert', () {
    test('rzuca AssertionError gdy options.length != 3', () {
      expect(
        () => Riddle(
          text: 'Pytanie',
          options: ['A', 'B'],
          correctIndex: 0,
          topic: Topic.animals,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rzuca AssertionError gdy correctIndex poza zakresem 0-2', () {
      expect(
        () => Riddle(
          text: 'Pytanie',
          options: ['A', 'B', 'C'],
          correctIndex: 3,
          topic: Topic.animals,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
