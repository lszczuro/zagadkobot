import 'package:flutter/material.dart';
import 'package:zagadkobot/features/home/home_screen.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final _llm = LlmServiceLlamaCpp();

  List<Map<String, String>> _models = [];
  Map<String, String>? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await _llm.listModels();
      setState(() {
        _models = models;
        _selected = models.isNotEmpty ? models.first : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(modelPath: _selected?['path']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Zagadkobot',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Wybierz model językowy',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _loadModels)
              else if (_models.isEmpty)
                _NoModelsCard()
              else ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButton<Map<String, String>>(
                    value: _selected,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _models
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selected = val),
                  ),
                ),
                const SizedBox(height: 8),
                if (_selected != null)
                  Text(
                    _selected!['path'] ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _selected != null ? _start : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Uruchom'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Błąd: $message',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Spróbuj ponownie')),
      ],
    );
  }
}

class _NoModelsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Nie znaleziono żadnych modeli.\n\nSkopiuj plik .gguf do:\n/data/local/tmp/zagadkobot/',
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.outline),
    );
  }
}
