import 'dart:math';

/// Model reprezentujący pojedynczą zagadkę z riddles_db.json.
class Riddle {
  final String id;
  final String category;
  final String difficulty;

  /// Treść zagadki
  final String question;

  /// Lista 3 możliwych odpowiedzi
  final List<String> answers;

  /// Indeks poprawnej odpowiedzi (0, 1 lub 2)
  final int correctIndex;

  /// Komentarz Zgadusia po poprawnej odpowiedzi
  final String zgadusCorrect;

  /// Komentarz Zgadusia po błędnej odpowiedzi
  final String zgadusIncorrect;

  /// Podpowiedź Zgadusia
  final String zgadusHint;

  const Riddle({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.answers,
    required this.correctIndex,
    required this.zgadusCorrect,
    required this.zgadusIncorrect,
    required this.zgadusHint,
  });

  factory Riddle.fromJson(Map<String, dynamic> json) => Riddle(
    id: json['id'] as String,
    category: json['category'] as String,
    difficulty: json['difficulty'] as String,
    question: json['question'] as String,
    answers: (json['answers'] as List<dynamic>).cast<String>(),
    correctIndex: (json['correct_index'] as num).toInt(),
    zgadusCorrect: json['zgadus_correct'] as String,
    zgadusIncorrect: json['zgadus_incorrect'] as String,
    zgadusHint: json['zgadus_hint'] as String,
  );

  /// Zwraca zagadkę z odpowiedziami w losowej kolejności i zaktualizowanym [correctIndex].
  Riddle shuffled([Random? rng]) {
    final r = rng ?? Random();
    final indices = [0, 1, 2]..shuffle(r);
    return Riddle(
      id: id,
      category: category,
      difficulty: difficulty,
      question: question,
      answers: indices.map((i) => answers[i]).toList(),
      correctIndex: indices.indexOf(correctIndex),
      zgadusCorrect: zgadusCorrect,
      zgadusIncorrect: zgadusIncorrect,
      zgadusHint: zgadusHint,
    );
  }
}
