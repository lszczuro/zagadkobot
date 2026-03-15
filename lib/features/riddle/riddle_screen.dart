import 'package:flutter/material.dart';
import 'package:zagadkobot/features/answer/answer_screen.dart';
import 'package:zagadkobot/models/llm_stats.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/settings_service.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';
import 'package:zagadkobot/widgets/answer_button.dart';

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
        pageBuilder: (_, _, _) => AnswerScreen(
          llm: widget.llm,
          tts: widget.tts,
          repo: widget.repo,
          modelName: widget.modelName,
          riddle: _riddle,
          selectedIndex: index,
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
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CustomPaint(painter: _RobotPainter()),
                    ),
                    const SizedBox(width: 8),
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
                                child: CustomPaint(painter: _RobotPainter()),
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

// ─── Robot painter ────────────────────────────────────────────────────────────

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const bodyColor = Color(0xFFFFFFFF);
    const shadowColor = Color(0xFFD0C8F0);
    const faceColor = Color(0xFFF8F6FF);
    const accentColor = Color(0xFF9B85D0);
    const eyeColor = Color(0xFF5B3D9B);
    const cheekColor = Color(0xFFE8DCFF);

    final paint = Paint()..isAntiAlias = true;

    // ── Body ──────────────────────────────────────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.68),
        width: w * 0.52,
        height: h * 0.44,
      ),
      const Radius.circular(48),
    );
    paint
      ..color = shadowColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bodyRect.shift(const Offset(0, 4)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(bodyRect, paint);

    // ── Arms ──────────────────────────────────────────────────────────────
    _drawArm(canvas, paint, bodyColor, shadowColor,
        center: Offset(w * 0.18, h * 0.65), angle: -0.3);
    _drawArm(canvas, paint, bodyColor, shadowColor,
        center: Offset(w * 0.82, h * 0.65), angle: 0.3);

    // ── Chest panel ───────────────────────────────────────────────────────
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.70),
        width: w * 0.28,
        height: h * 0.18,
      ),
      const Radius.circular(12),
    );
    paint.color = cheekColor;
    canvas.drawRRect(panelRect, paint);

    for (int i = 0; i < 3; i++) {
      paint.color = accentColor.withValues(alpha: 0.6);
      canvas.drawCircle(
        Offset(w * 0.38 + i * w * 0.12, h * 0.70),
        3.5,
        paint,
      );
    }

    // ── Head ──────────────────────────────────────────────────────────────
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.36),
        width: w * 0.46,
        height: h * 0.38,
      ),
      const Radius.circular(40),
    );
    paint.color = shadowColor;
    canvas.drawRRect(headRect.shift(const Offset(0, 3)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(headRect, paint);

    // Face plate
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.36),
        width: w * 0.36,
        height: h * 0.28,
      ),
      const Radius.circular(28),
    );
    paint.color = faceColor;
    canvas.drawRRect(faceRect, paint);

    // Eyes
    paint.color = eyeColor;
    canvas.drawCircle(Offset(w * 0.40, h * 0.33), 6, paint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.33), 6, paint);

    // Eye shine
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.42, h * 0.315), 2, paint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.315), 2, paint);

    // Smile
    final smilePath = Path();
    smilePath.moveTo(w * 0.40, h * 0.40);
    smilePath.quadraticBezierTo(w * 0.50, h * 0.455, w * 0.60, h * 0.40);
    paint
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(smilePath, paint);
    paint.style = PaintingStyle.fill;

    // Cheeks
    paint.color = cheekColor;
    canvas.drawCircle(Offset(w * 0.335, h * 0.39), 8, paint);
    canvas.drawCircle(Offset(w * 0.665, h * 0.39), 8, paint);

    // ── Antenna ───────────────────────────────────────────────────────────
    paint
      ..color = accentColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.175),
      Offset(w * 0.5, h * 0.10),
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF7B5EA7);
    canvas.drawCircle(Offset(w * 0.5, h * 0.085), 7, paint);
    paint.color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(w * 0.495, h * 0.080), 2.5, paint);
  }

  void _drawArm(
    Canvas canvas,
    Paint paint,
    Color bodyColor,
    Color shadowColor, {
    required Offset center,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final armRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 22, height: 46),
      const Radius.circular(11),
    );
    paint.color = shadowColor;
    canvas.drawRRect(armRect.shift(const Offset(0, 3)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(armRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
