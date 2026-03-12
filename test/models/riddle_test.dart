import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/models/riddle.dart';

void main() {
  // Przykładowy rekord zgodny z riddles_db.json
  const sampleJson = {
    'id': 'zwierzęta_0000',
    'category': 'zwierzęta',
    'difficulty': 'łatwa',
    'question': 'Mam długą szyję i jem listki z wysokich drzew.',
    'answers': ['Żyrafa', 'Słoń', 'Zebra'],
    'correct_index': 0,
    'zgadus_correct': 'Brawo! 🎉 To była żyrafka!',
    'zgadus_incorrect': 'Ojej, to nie to zwierzątko.',
    'zgadus_hint': 'Pamiętaj, że to zwierzątko ma bardzo długą szyję!',
  };

  group('Riddle.fromJson', () {
    test('deserializuje poprawny rekord z bazy', () {
      final riddle = Riddle.fromJson(sampleJson);

      expect(riddle.id, 'zwierzęta_0000');
      expect(riddle.category, 'zwierzęta');
      expect(riddle.difficulty, 'łatwa');
      expect(riddle.question, 'Mam długą szyję i jem listki z wysokich drzew.');
      expect(riddle.answers, ['Żyrafa', 'Słoń', 'Zebra']);
      expect(riddle.correctIndex, 0);
      expect(riddle.zgadusCorrect, 'Brawo! 🎉 To była żyrafka!');
      expect(riddle.zgadusIncorrect, 'Ojej, to nie to zwierzątko.');
      expect(riddle.zgadusHint, 'Pamiętaj, że to zwierzątko ma bardzo długą szyję!');
    });

    test('poprawnie mapuje correct_index jako int', () {
      final riddle = Riddle.fromJson({...sampleJson, 'correct_index': 2});
      expect(riddle.correctIndex, 2);
    });

    test('poprawnie mapuje correct_index podany jako num (double)', () {
      final riddle = Riddle.fromJson({...sampleJson, 'correct_index': 1.0});
      expect(riddle.correctIndex, 1);
    });

    test('answers to lista 3 stringów', () {
      final riddle = Riddle.fromJson(sampleJson);
      expect(riddle.answers.length, 3);
      expect(riddle.answers, everyElement(isA<String>()));
    });

    test('correctIndex wskazuje na poprawną odpowiedź na liście', () {
      final riddle = Riddle.fromJson(sampleJson);
      expect(riddle.answers[riddle.correctIndex], 'Żyrafa');
    });
  });

  group('Riddle constructor', () {
    test('tworzy obiekt z wymaganymi polami', () {
      const riddle = Riddle(
        id: 'test_0',
        category: 'kosmos',
        difficulty: 'trudna',
        question: 'Co to?',
        answers: ['A', 'B', 'C'],
        correctIndex: 1,
        zgadusCorrect: 'Super!',
        zgadusIncorrect: 'Nie tym razem.',
        zgadusHint: 'Pomyśl jeszcze raz.',
      );

      expect(riddle.id, 'test_0');
      expect(riddle.answers[riddle.correctIndex], 'B');
    });
  });
}
