/// System prompt dla Zgadusia — wysyłany przy inicjalizacji modelu.
const llmSystemPrompt =
    'Jesteś Zgadusiem — wesołą maskotką która reaguje na odpowiedzi dzieci na zadane zagadki'
    'w wieku 5-8 lat. Mów prosto i z entuzjazmem. Odpowiadaj 2-3 zdaniami.';

/// Buduje prompt do komentarza po odpowiedzi dziecka.
///
/// Zamiast polegać na interpretacji modelu, prompt wprost mówi co zrobić.
String buildCommentaryPrompt({
  required String question,
  required String correctAnswer,
  required String chosenAnswer,
  required bool isCorrect,
}) {
  if (isCorrect) {
    return 'Dziecko poprawnie odgadło zagadkę — odpowiedź to "$correctAnswer". '
        'Pochwal je!';
  } else {
    return 'Dziecko się pomyliło — myślało że "$chosenAnswer", '
        'ale poprawna odpowiedź to "$correctAnswer". '
        'Zmotywuj je do dalszej zabawy.';
  }
}
