import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zagadkobot/models/topic.dart';
import 'package:zagadkobot/services/llm/llm_prompt.dart';
import 'package:zagadkobot/services/llm/llm_service.dart';

/// Dev-only panel do testowania LLM — streamuje zagadkę do zewnętrznego
/// TextEditingController (np. z TtsDemoPanel).
class LlmDemoPanel extends StatefulWidget {
  const LlmDemoPanel({
    super.key,
    required this.llmService,
    required this.outputController,
  });

  final LlmService llmService;
  final TextEditingController outputController;

  @override
  State<LlmDemoPanel> createState() => _LlmDemoPanelState();
}

class _LlmDemoPanelState extends State<LlmDemoPanel> {
  _Status _status = _Status.loading;
  String? _error;
  Topic _selectedTopic = Topic.animals;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _initLlm();
  }

  Future<void> _initLlm() async {
    try {
      await widget.llmService.initialize();
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

  Future<void> _generate() async {
    setState(() {
      _status = _Status.generating;
      _error = null;
    });
    widget.outputController.text = '';

    final prompt = buildRiddlePrompt(_selectedTopic.promptName);
    final stream = widget.llmService.generateStream(prompt);

    _subscription = stream.listen(
      (token) {
        widget.outputController.text += token;
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _status = _Status.error;
            _error = e.toString();
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _status = _Status.ready);
      },
    );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    if (mounted) setState(() => _status = _Status.ready);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 8),
              Text(
                'LLM Demo',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              _StatusChip(status: _status),
            ]),
            if (_status != _Status.loading) ...[
              const SizedBox(height: 12),
              SegmentedButton<Topic>(
                segments: [
                  for (final topic in Topic.values)
                    ButtonSegment(
                      value: topic,
                      label: Text(topic.emoji),
                      tooltip: topic.displayName,
                    ),
                ],
                selected: {_selectedTopic},
                onSelectionChanged: (selected) {
                  setState(() => _selectedTopic = selected.first);
                },
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
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _status == _Status.ready ? _generate : null,
                  icon: _status == _Status.generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(switch (_status) {
                    _Status.loading => 'Ładowanie modelu…',
                    _Status.generating => 'Generuje…',
                    _Status.error => 'Błąd — spróbuj ponownie',
                    _Status.ready => 'Generuj zagadkę',
                  }),
                ),
              ),
              if (_status == _Status.generating) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Przerwij',
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

enum _Status { loading, ready, generating, error }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _Status.loading => ('ładowanie', Colors.orange),
      _Status.ready => ('gotowy', Colors.green),
      _Status.generating => ('generuje…', Colors.blue),
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
