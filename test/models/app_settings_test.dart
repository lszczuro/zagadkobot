import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('serialize and deserialize to/from JSON correctly', () {
      const settings = AppSettings(
        volume: 0.8,
        voiceId: 'pl-gosia',
        modelsDownloaded: true,
      );

      final json = settings.toJson();
      expect(json, {
        'volume': 0.8,
        'voiceId': 'pl-gosia',
        'modelsDownloaded': true,
      });

      final rebuilt = AppSettings.fromJson(json);
      expect(rebuilt.volume, settings.volume);
      expect(rebuilt.voiceId, settings.voiceId);
      expect(rebuilt.modelsDownloaded, settings.modelsDownloaded);
    });

    test('defaults() tworzy poprawne ustawienia domyślne', () {
      const settings = AppSettings.defaults();
      expect(settings.volume, 0.5);
      expect(settings.voiceId, '');
      expect(settings.modelsDownloaded, false);
    });

    test('copyWith podmienia wskazane pola', () {
      const settings = AppSettings(
        volume: 0.5,
        voiceId: 'pl-gosia',
        modelsDownloaded: false,
      );

      final updated = settings.copyWith(volume: 1.0, modelsDownloaded: true);
      expect(updated.volume, 1.0);
      expect(updated.voiceId, 'pl-gosia');
      expect(updated.modelsDownloaded, true);
    });

    test('copyWith bez argumentów zwraca kopię z tymi samymi polami', () {
      const settings = AppSettings(
        volume: 0.3,
        voiceId: 'pl-marek',
        modelsDownloaded: true,
      );

      final copy = settings.copyWith();
      expect(copy.volume, settings.volume);
      expect(copy.voiceId, settings.voiceId);
      expect(copy.modelsDownloaded, settings.modelsDownloaded);
    });
  });
}
