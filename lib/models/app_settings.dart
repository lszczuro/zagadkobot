import 'package:json_annotation/json_annotation.dart';

part 'app_settings.g.dart';

/// Model reprezentujący ustawienia aplikacji.
@JsonSerializable(explicitToJson: true)
class AppSettings {
  /// Głośność odtwarzania (od 0.0 do 1.0)
  final double volume;

  /// Identyfikator wybranego głosu TTS
  final String voiceId;

  /// Czy modele (LLM, TTS) zostały pobrane
  final bool modelsDownloaded;

  /// Konstruktor ustawień
  const AppSettings({
    required this.volume,
    required this.voiceId,
    required this.modelsDownloaded,
  });

  /// Domyślne ustawienia aplikacji
  const AppSettings.defaults()
      : volume = 0.5,
        voiceId = '',
        modelsDownloaded = false;

  /// Factory do deserializacji JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  /// Metoda do serializacji do JSON
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  /// Zwraca kopię z podmienionymi polami
  AppSettings copyWith({
    double? volume,
    String? voiceId,
    bool? modelsDownloaded,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      voiceId: voiceId ?? this.voiceId,
      modelsDownloaded: modelsDownloaded ?? this.modelsDownloaded,
    );
  }
}
