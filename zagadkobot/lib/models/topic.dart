import 'package:json_annotation/json_annotation.dart';

/// Enum reprezentujący tematy zagadek.
@JsonEnum()
enum Topic {
  /// Zwierzęta
  @JsonValue('animals')
  animals('Zwierzęta', '🐾', 'Animals'),

  /// Rośliny
  @JsonValue('plants')
  plants('Rośliny', '🌱', 'Plants'),

  /// Kosmos
  @JsonValue('space')
  space('Kosmos', '🚀', 'Space'),

  /// Pojazdy
  @JsonValue('vehicles')
  vehicles('Pojazdy', '🚗', 'Vehicles');

  /// Nazwa tematu do wyświetlenia w UI
  final String displayName;

  /// Emoji reprezentujące temat
  final String emoji;

  /// Angielska nazwa tematu (do promptu LLM)
  final String promptName;

  /// Konstruktor tematu
  const Topic(this.displayName, this.emoji, this.promptName);
}
