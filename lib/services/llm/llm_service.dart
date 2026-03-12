/// Abstrakcja silnika LLM do generowania zagadek.
abstract interface class LlmService {
  bool get isInitialized;
  String? get modelName;

  /// Inicjalizuje silnik (ładuje model, ustawia parametry).
  Future<void> initialize();

  /// Generuje odpowiedź strumieniowo token po tokenie.
  Stream<String> generateStream(String prompt);

  /// Zwalnia zasoby (model, pamięć).
  Future<void> dispose();
}
