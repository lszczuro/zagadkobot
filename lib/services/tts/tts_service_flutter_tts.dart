import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Implementacja [TtsService] oparta na flutter_tts (systemowy silnik TTS).
///
/// Na Androidzie używa Google TTS / silnika OEM — obsługuje język polski
class TtsServiceFlutterTts implements TtsService {
  final _tts = FlutterTts();
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('pl-PL');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    assert(isInitialized, 'Wywołaj initialize() przed speak()');
    await _tts.speak(_removeEmoji(text));
  }

  /// Usuwa znaki emoji z tekstu przed syntezą mowy.
  static String _removeEmoji(String text) {
    return text.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}]|'   // główny blok emoji (1F...)
        r'[\u{2600}-\u{27FF}]|'      // symbole, strzałki, Dingbats
        r'[\u{FE00}-\u{FE0F}]',      // variation selectors
        unicode: true,
      ),
      '',
    );
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    _initialized = false;
  }
}
