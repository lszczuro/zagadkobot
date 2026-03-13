/// System prompt dla Zgadusia — wysyłany przy inicjalizacji modelu.
const llmSystemPrompt =
    '/no_think\n'
    'Jesteś Zgadusiem — wesołą maskotką która zadaje zagadki dzieciom '
    'w wieku 5-8 lat. Mów krótko, prosto i przyjaźnie.';

/// Buduje prompt do komentarza po odpowiedzi dziecka.
///
/// Format zgodny z danymi treningowymi (training_chatml.json):
/// ```
///   Zagadka: [treść]
///   Prawidłowa odpowiedź: [odpowiedź]
///   Dziecko wybrało: [odpowiedź] ✓/✗
/// ```
String buildCommentaryPrompt({
  required String question,
  required String correctAnswer,
  required String chosenAnswer,
  required bool isCorrect,
}) {
  final mark = isCorrect ? '✓' : '✗';
  return 'Zagadka: $question\n'
      'Prawidłowa odpowiedź: $correctAnswer\n'
      'Dziecko wybrało: $chosenAnswer $mark';
}
