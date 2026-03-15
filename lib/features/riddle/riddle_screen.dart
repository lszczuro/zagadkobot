import 'package:flutter/material.dart';
import 'package:zagadkobot/features/generating/generating_screen.dart';
import 'package:zagadkobot/models/llm_stats.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/settings_service.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';
import 'package:zagadkobot/widgets/answer_button.dart';
import 'package:zagadkobot/widgets/robot_widget.dart';

class RiddleScreen extends StatefulWidget {
  const RiddleScreen({
    super.key,
    required this.llm,
    required this.tts,
    required this.repo,
    this.modelName,
    this.excludeId,
    this.lastStats,
  });

  final LlmServiceLlamaCpp llm;
  final TtsServiceFlutterTts tts;
  final RiddleRepository repo;
  final String? modelName;
  final String? excludeId;
  final LlmStats? lastStats;

  @override
  State<RiddleScreen> createState() => _RiddleScreenState();
}

class _RiddleScreenState extends State<RiddleScreen> {
  late final Riddle _riddle;

  @override
  void initState() {
    super.initState();
    _riddle = widget.excludeId != null
        ? widget.repo.randomExcluding(widget.excludeId!)
        : widget.repo.random();
    widget.tts.speak(_buildQuestionSpeech());
  }

  @override
  void dispose() {
    widget.tts.stop();
    super.dispose();
  }

  String _buildQuestionSpeech() {
    final a = _riddle.answers;
    return '${_riddle.question} '
        'Czy to A: ${a[0]}? '
        'Czy B: ${a[1]}? '
        'Czy C: ${a[2]}?';
  }

  void _onAnswer(int index) {
    widget.tts.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => GeneratingScreen(
          llm: widget.llm,
          tts: widget.tts,
          repo: widget.repo,
          modelName: widget.modelName,
          riddle: _riddle,
          selectedIndex: index,
          lastStats: widget.lastStats,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEBE4FF), Color(0xFFF6F3FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Zgaduś',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5C3D91),
                      ),
                    ),
                    const Spacer(),
                    _CategoryChip(
                      category: _riddle.category,
                      difficulty: _riddle.difficulty,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Color(0xFF5C3D91),
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _SettingsDialog(
                          modelName: widget.modelName,
                          lastStats: widget.lastStats,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Question + answers ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: const Color(0xFF7C4DBC),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 130,
                                height: 110,
                                child: RobotWidget(),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _riddle.question,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_riddle.question.length}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.white54,
                                    ),
                                    tooltip: 'Powtórz pytanie',
                                    onPressed: () {
                                      widget.tts.stop();
                                      widget.tts.speak(_buildQuestionSpeech());
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Answer buttons
                      for (int i = 0; i < _riddle.answers.length; i++) ...[
                        AnswerButton(
                          label: _riddle.answers[i],
                          index: i,
                          selectedIndex: null,
                          correctIndex: _riddle.correctIndex,
                          answered: false,
                          onTap: () => _onAnswer(i),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.difficulty});

  final String category;
  final String difficulty;

  static const _difficultyColor = {
    'łatwa': Color(0xFF28A745),
    'średnia': Color(0xFFE67E22),
    'trudna': Color(0xFFDC3545),
  };

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor[difficulty] ?? const Color(0xFF888888);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        '$category · $difficulty',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Settings dialog ──────────────────────────────────────────────────────────

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({this.modelName, this.lastStats});

  final String? modelName;
  final LlmStats? lastStats;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final _llm = LlmServiceLlamaCpp();
  List<Map<String, String>> _models = [];
  Map<String, String>? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SettingsService.getModelPath(),
      _llm.listModels(),
    ]);
    final savedPath = results[0] as String?;
    final models = results[1] as List<Map<String, String>>;
    Map<String, String>? selected;
    if (savedPath != null) {
      try {
        selected = models.firstWhere((m) => m['path'] == savedPath);
      } catch (_) {
        selected = models.isNotEmpty ? models.first : null;
      }
    } else {
      selected = models.isNotEmpty ? models.first : null;
    }
    if (mounted) {
      setState(() {
        _models = models;
        _selected = selected;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selected?['path'] != null) {
      await SettingsService.saveModelPath(_selected!['path']!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ustawienia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Model:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              widget.modelName ?? 'brak modelu',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Model przy następnym uruchomieniu:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_models.isEmpty)
              const Text('Nie znaleziono modeli')
            else
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            const SizedBox(height: 16),
            const Text(
              'Parametry:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _InfoTable(
              rows: [
                ('temperature', '${LlmServiceLlamaCpp.temperature}'),
                ('top_p', '${LlmServiceLlamaCpp.topP}'),
                ('max_tokens', '${LlmServiceLlamaCpp.maxTokens}'),
                ('n_threads', '${LlmServiceLlamaCpp.nThreads}'),
              ],
            ),
            if (widget.lastStats != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Ostatnia generacja:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _InfoTable(
                rows: [
                  ('TTFT', '${widget.lastStats!.ttft.inMilliseconds} ms'),
                  ('tokeny', '${widget.lastStats!.tokenCount}'),
                  (
                    'czas',
                    '${(widget.lastStats!.totalTime.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  ),
                  ('tok/s', widget.lastStats!.tokensPerSecond.toStringAsFixed(1)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zamknij'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

// ─── Info table ───────────────────────────────────────────────────────────────

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final valueStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
    );
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final (label, value) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 2),
                child: Text(label, style: labelStyle),
              ),
              Text(value, style: valueStyle),
            ],
          ),
      ],
    );
  }
}

