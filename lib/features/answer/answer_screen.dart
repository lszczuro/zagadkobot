import 'package:flutter/material.dart';
import 'package:zagadkobot/features/riddle/riddle_screen.dart';
import 'package:zagadkobot/models/llm_stats.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/settings_service.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';
import 'package:zagadkobot/widgets/answer_button.dart';
import 'package:zagadkobot/widgets/robot_widget.dart';

class AnswerScreen extends StatelessWidget {
  const AnswerScreen({
    super.key,
    required this.llm,
    required this.tts,
    required this.repo,
    required this.riddle,
    required this.selectedIndex,
    required this.comment,
    this.modelName,
    this.stats,
  });

  final LlmServiceLlamaCpp llm;
  final TtsServiceFlutterTts tts;
  final RiddleRepository repo;
  final Riddle riddle;
  final int selectedIndex;
  final String comment;
  final String? modelName;
  final LlmStats? stats;

  bool get _isCorrect => selectedIndex == riddle.correctIndex;

  void _nextRiddle(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => RiddleScreen(
          llm: llm,
          tts: tts,
          repo: repo,
          modelName: modelName,
          excludeId: riddle.id,
          lastStats: stats,
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
                      category: riddle.category,
                      difficulty: riddle.difficulty,
                    ),
                    _ResultChip(isCorrect: _isCorrect),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Color(0xFF5C3D91),
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _SettingsDialog(
                          modelName: modelName,
                          lastStats: stats,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 110, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question card
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: const Color(0xFF7C4DBC),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 100, 24, 20),
                              child: Column(
                                children: [
                                  Text(
                                    riddle.question,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: -90,
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: RobotWidget(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Answer buttons (answered state)
                      for (int i = 0; i < riddle.answers.length; i++) ...[
                        AnswerButton(
                          label: riddle.answers[i],
                          index: i,
                          selectedIndex: selectedIndex,
                          correctIndex: riddle.correctIndex,
                          answered: true,
                          onTap: () {},
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Comment card
                      const SizedBox(height: 8),
                      _CommentCard(comment: comment, isCorrect: _isCorrect),

                      // Next button
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _nextRiddle(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5C3D91),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Następna zagadka',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
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

// ─── Result chip ──────────────────────────────────────────────────────────────

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final color =
        isCorrect ? const Color(0xFF28A745) : const Color(0xFFDC3545);
    final label = isCorrect ? 'Brawo!' : 'Nie tym razem';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Comment card ─────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.isCorrect});

  final String comment;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final color =
        isCorrect ? const Color(0xFF28A745) : const Color(0xFFE67E22);
    final bgColor =
        isCorrect ? const Color(0xFFD4EDDA) : const Color(0xFFFFF3CD);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '🎉' : '🤔',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
                height: 1.4,
              ),
            ),
          ),
        ],
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
