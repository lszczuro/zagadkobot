import 'package:json_annotation/json_annotation.dart';
import 'topic.dart';

part 'riddle.g.dart';

/// Model reprezentujący pojedynczą zagadkę.
@JsonSerializable(explicitToJson: true)
class Riddle {
  /// Treść zagadki
  final String text;

  /// Lista 3 możliwych odpowiedzi
  final List<String> options;

  /// Indeks poprawnej odpowiedzi (0, 1 lub 2)
  final int correctIndex;

  /// Temat zagadki
  final Topic topic;

  /// Konstruktor zagadki
  Riddle({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.topic,
  })  : assert(options.length == 3, 'Riddle must have exactly 3 options'),
        assert(
          correctIndex >= 0 && correctIndex <= 2,
          'correctIndex must be 0, 1 or 2',
        );

  /// Factory do deserializacji JSON
  factory Riddle.fromJson(Map<String, dynamic> json) => _$RiddleFromJson(json);

  /// Metoda do serializacji do JSON
  Map<String, dynamic> toJson() => _$RiddleToJson(this);

  /// Parsuje odpowiedź tekstową z LLM.
  ///
  /// Oczekiwany format:
  /// ZAGADKA / A) / B) / C) / POPRAWNA
  factory Riddle.fromLLMResponse({
    required String response,
    required Topic topic,
  }) {
    final explicitZagadka = RegExp(
      r'ZAGADKA[:\s]*(.*?)(?=\bA\s*\)|\bB\s*\)|\bC\s*\)|POPRAWNA|$)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(response);

    String textStr = '';
    if (explicitZagadka != null &&
        explicitZagadka.group(1)!.trim().isNotEmpty) {
      textStr = explicitZagadka.group(1)!.trim();
    } else {
      final implicitZagadka = RegExp(
        r'^[:\s]*(.*?)(?=\bA\s*\)|\bB\s*\)|\bC\s*\)|POPRAWNA|$)',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(response);
      textStr = (implicitZagadka?.group(1) ?? '').trim();
    }

    final aMatch = RegExp(
      r'\bA\s*\)\s*(.*?)(?=\bB\s*\)|\bC\s*\)|POPRAWNA|ZAGADKA|$)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(response);
    final bMatch = RegExp(
      r'\bB\s*\)\s*(.*?)(?=\bA\s*\)|\bC\s*\)|POPRAWNA|ZAGADKA|$)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(response);
    final cMatch = RegExp(
      r'\bC\s*\)\s*(.*?)(?=\bA\s*\)|\bB\s*\)|POPRAWNA|ZAGADKA|$)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(response);
    final poprawnaMatch = RegExp(
      r'POPRAWNA[:\s]*([A-C])',
      caseSensitive: false,
    ).firstMatch(response);

    final optionAStr = (aMatch?.group(1) ?? '').trim();
    final optionBStr = (bMatch?.group(1) ?? '').trim();
    final optionCStr = (cMatch?.group(1) ?? '').trim();
    final poprawnaStr = (poprawnaMatch?.group(1) ?? '').trim().toUpperCase();

    if (textStr.isEmpty ||
        optionAStr.isEmpty ||
        optionBStr.isEmpty ||
        optionCStr.isEmpty ||
        poprawnaStr.isEmpty) {
      throw const FormatException('Nie udało się przeparsować odpowiedzi LLM.');
    }

    int parsedCorrectIndex = -1;
    if (poprawnaStr.startsWith('A')) {
      parsedCorrectIndex = 0;
    } else if (poprawnaStr.startsWith('B')) {
      parsedCorrectIndex = 1;
    } else if (poprawnaStr.startsWith('C')) {
      parsedCorrectIndex = 2;
    }

    if (parsedCorrectIndex == -1) {
      throw const FormatException('Nieznana poprawna odpowiedź.');
    }

    return Riddle(
      text: textStr,
      options: [optionAStr, optionBStr, optionCStr],
      correctIndex: parsedCorrectIndex,
      topic: topic,
    );
  }
}
