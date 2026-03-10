import 'package:json_annotation/json_annotation.dart';

/// Enum reprezentujący tematy zagadek.
@JsonEnum()
enum Topic {
  /// Zwierzęta
  @JsonValue('animals')
  animals('Zwierzęta', '🐾'),

  /// Rośliny
  @JsonValue('plants')
  plants('Rośliny', '🌱'),

  /// Kosmos
  @JsonValue('space')
  space('Kosmos', '🚀'),

  /// Pojazdy
  @JsonValue('vehicles')
  vehicles('Pojazdy', '🚗');

  /// Nazwa tematu do wyświetlenia w UI
  final String displayName;

  /// Emoji reprezentujące temat
  final String emoji;

  /// Konstruktor tematu
  const Topic(this.displayName, this.emoji);
}
