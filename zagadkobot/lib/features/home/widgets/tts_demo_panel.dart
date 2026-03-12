import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zagadkobot/services/tts/tts_service.dart';

/// Dev-only panel do testowania TTS na żywo.
class TtsDemoPanel extends StatefulWidget {
  const TtsDemoPanel({super.key, required this.ttsService, this.controller});

  final TtsService ttsService;
  final TextEditingController? controller;

  @override
  State<TtsDemoPanel> createState() => _TtsDemoPanelState();
}

class _TtsDemoPanelState extends State<TtsDemoPanel> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  _Status _status = _Status.loading;
  String? _error;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = TextEditingController(
        text:
            'Witaj! Jestem zagadkobot. '
            'Zgadnij: chodzi na czterech łapach i miauczy. Co to jest?',
      );
      _ownsController = true;
    }
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await widget.ttsService.initialize();
      if (mounted) setState(() => _status = _Status.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _Status.error;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _speak() async {
    if (_speaking) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _speaking = true;
    setState(() {
      _status = _Status.playing;
      _error = null;
    });
    try {
      await widget.ttsService.speak(text);
      if (mounted) setState(() => _status = _Status.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _Status.error;
          _error = e.toString();
        });
      }
    } finally {
      _speaking = false;
    }
  }

  Future<void> _stop() async {
    await widget.ttsService.stop();
    if (mounted) setState(() => _status = _Status.ready);
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    unawaited(widget.ttsService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over, size: 18),
                const SizedBox(width: 8),
                Text('TTS Demo', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                _StatusChip(status: _status),
              ],
            ),

            if (_status != _Status.loading) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 10,
                minLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Wpisz tekst do syntezy…',
                  isDense: true,
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _status == _Status.ready ? _speak : null,
                    icon: _status == _Status.playing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(switch (_status) {
                      _Status.loading => 'Inicjalizacja…',
                      _Status.playing => 'Odtwarza…',
                      _Status.error => 'Błąd',
                      _Status.ready => 'Odtwórz',
                    }),
                  ),
                ),
                if (_status == _Status.playing) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Zatrzymaj',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Status { loading, ready, playing, error }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _Status.loading => ('ładowanie', Colors.orange),
      _Status.ready => ('gotowy', Colors.green),
      _Status.playing => ('odtwarza…', Colors.blue),
      _Status.error => ('błąd', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
