/// Abstrakcja silnika TTS.
abstract interface class TtsService {
  bool get isInitialized;

  /// Inicjalizuje silnik (język, tempo itp.).
  Future<void> initialize();

  /// Syntezuje i odtwarza [text]. Kończy się po zakończeniu odtwarzania.
  Future<void> speak(String text);

  /// Zatrzymuje bieżące odtwarzanie.
  Future<void> stop();

  /// Zwalnia zasoby.
  Future<void> dispose();
}
