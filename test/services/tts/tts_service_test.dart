import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zagadkobot/services/tts/tts_service.dart';

// ---------------------------------------------------------------------------
// Fake TtsService — do testów (nie wymaga silnika TTS na hoście testowym)
// ---------------------------------------------------------------------------

class _FakeTtsService implements TtsService {
  bool _initialized = false;
  int speakCalls = 0;
  final List<String> spoken = [];

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Future<void> speak(String text) async {
    assert(_initialized);
    speakCalls++;
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _initialized = false;
}

// ---------------------------------------------------------------------------
// Minimalny widget testowy korzystający z TtsService
// ---------------------------------------------------------------------------

class _TtsPlayerWidget extends StatefulWidget {
  const _TtsPlayerWidget({required this.ttsService, required this.text});

  final TtsService ttsService;
  final String text;

  @override
  State<_TtsPlayerWidget> createState() => _TtsPlayerWidgetState();
}

class _TtsPlayerWidgetState extends State<_TtsPlayerWidget> {
  String _status = 'idle';

  Future<void> _play() async {
    setState(() => _status = 'playing');
    try {
      await widget.ttsService.speak(widget.text);
      setState(() => _status = 'done');
    } catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_status, key: const Key('status')),
        ElevatedButton(
          key: const Key('play_btn'),
          onPressed: _play,
          child: const Text('Odtwórz'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Testy
// ---------------------------------------------------------------------------

void main() {
  late _FakeTtsService fakeTts;

  setUp(() async {
    fakeTts = _FakeTtsService();
    await fakeTts.initialize();
  });

  tearDown(() => fakeTts.dispose());

  testWidgets('odtwarza "Witaj!" bez błędów', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TtsPlayerWidget(ttsService: fakeTts, text: 'Witaj!'),
        ),
      ),
    );

    expect(find.text('idle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('play_btn')));
    await tester.pumpAndSettle();

    expect(find.text('done'), findsOneWidget);
    expect(find.textContaining('error'), findsNothing);
    expect(fakeTts.speakCalls, equals(1));
    expect(fakeTts.spoken, equals(['Witaj!']));
  });

  testWidgets('odtwarza wielozdaniowy tekst bez błędów', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TtsPlayerWidget(
            ttsService: fakeTts,
            text: 'Mam cztery łapy. Co to jest?',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('play_btn')));
    await tester.pumpAndSettle();

    expect(find.text('done'), findsOneWidget);
    expect(find.textContaining('error'), findsNothing);
  });

  test('dispose resetuje isInitialized', () async {
    expect(fakeTts.isInitialized, isTrue);
    await fakeTts.dispose();
    expect(fakeTts.isInitialized, isFalse);
  });
}
