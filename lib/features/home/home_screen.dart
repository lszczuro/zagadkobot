import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/services/llm/llm_prompt.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';

enum _Phase { loading, error, question, commenting, done }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.modelPath});

  final String? modelPath;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _llm = LlmServiceLlamaCpp();
  final _tts = TtsServiceFlutterTts();
  final _repo = RiddleRepository();

  _Phase _phase = _Phase.loading;
  String? _errorMsg;
  Riddle? _riddle;
  int? _selectedIndex;
  String _comment = '';
  String? _modelName;
  StreamSubscription<String>? _sub;
  _LlmStats? _lastStats;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Future.wait([
        _llm.initialize(modelPath: widget.modelPath),
        _tts.initialize(),
        _repo.load(),
      ]);
      _modelName = _llm.modelName;
      _nextRiddle(first: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  String _buildQuestionSpeech(Riddle riddle) {
    final answers = riddle.answers;
    return '${riddle.question} '
        'Czy to A: ${answers[0]}? '
        'Czy B: ${answers[1]}? '
        'Czy C: ${answers[2]}?';
  }

  void _nextRiddle({bool first = false}) {
    _sub?.cancel();
    _sub = null;
    final riddle = first ? _repo.random() : _repo.randomExcluding(_riddle!.id);
    setState(() {
      _riddle = riddle;
      _selectedIndex = null;
      _comment = '';
      _phase = _Phase.question;
    });
    _tts.speak(_buildQuestionSpeech(riddle));
  }

  void _speakQuestion() {
    _tts.stop();
    _tts.speak(_buildQuestionSpeech(_riddle!));
  }

  Future<void> _onAnswer(int index) async {
    if (_phase != _Phase.question) return;
    final riddle = _riddle!;
    final isCorrect = index == riddle.correctIndex;

    await _tts.stop();
    setState(() {
      _selectedIndex = index;
      _comment = '';
      _phase = _Phase.commenting;
    });

    final prompt = buildCommentaryPrompt(
      question: riddle.question,
      correctAnswer: riddle.answers[riddle.correctIndex],
      chosenAnswer: riddle.answers[index],
      isCorrect: isCorrect,
    );

    final stream = _llm.generateStream(prompt);
    final sw = Stopwatch()..start();
    Duration? ttft;
    int tokenCount = 0;

    _sub = stream.listen(
      (token) {
        if (tokenCount == 0) ttft = sw.elapsed;
        tokenCount++;
        if (mounted) setState(() => _comment += token);
      },
      onDone: () {
        sw.stop();
        if (mounted) {
          setState(() {
            _phase = _Phase.done;
            _lastStats = _LlmStats(
              ttft: ttft ?? Duration.zero,
              totalTime: sw.elapsed,
              tokenCount: tokenCount,
            );
          });
          _tts.speak('Poprawna odpowiedź: ${riddle.answers[riddle.correctIndex]}. $_comment');
        }
      },
      onError: (_) {
        sw.stop();
        // Fallback do predefiniowanego komentarza z bazy
        final fallback = isCorrect ? riddle.zgadusCorrect : riddle.zgadusIncorrect;
        if (mounted) {
          setState(() {
            _comment = fallback;
            _phase = _Phase.done;
          });
          _tts.speak('Poprawna odpowiedź: ${riddle.answers[riddle.correctIndex]}. $fallback');
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _llm.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const _LoadingView(),
          _Phase.error => _ErrorView(message: _errorMsg ?? 'Nieznany błąd'),
          _ => _QuizView(
              riddle: _riddle!,
              selectedIndex: _selectedIndex,
              comment: _comment,
              phase: _phase,
              modelName: _modelName,
              lastStats: _lastStats,
              onAnswer: _onAnswer,
              onNext: () => _nextRiddle(),
              onRepeatQuestion: _speakQuestion,
            ),
        },
      ),
    );
  }
}

// ─── Loading ─────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🤖', style: TextStyle(fontSize: 64)),
          SizedBox(height: 24),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Budzę Zgadusia…', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Coś poszło nie tak…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quiz ─────────────────────────────────────────────────────────────────────

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.riddle,
    required this.selectedIndex,
    required this.comment,
    required this.phase,
    required this.onAnswer,
    required this.onNext,
    required this.onRepeatQuestion,
    this.modelName,
    this.lastStats,
  });

  final Riddle riddle;
  final int? selectedIndex;
  final String comment;
  final _Phase phase;
  final String? modelName;
  final _LlmStats? lastStats;
  final void Function(int) onAnswer;
  final VoidCallback onNext;
  final VoidCallback onRepeatQuestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Text(
                'Zgadus',
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
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Color(0xFF5C3D91)),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Informacje o modelu'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Model LLM:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(modelName ?? 'brak modelu', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                        const SizedBox(height: 12),
                        const Text('Parametry:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        _InfoTable(rows: [
                          ('temperature', '${LlmServiceLlamaCpp.temperature}'),
                          ('top_p', '${LlmServiceLlamaCpp.topP}'),
                          ('max_tokens', '${LlmServiceLlamaCpp.maxTokens}'),
                          ('n_threads', '${LlmServiceLlamaCpp.nThreads}'),
                        ]),
                        if (lastStats != null) ...[
                          const SizedBox(height: 12),
                          const Text('Ostatnia generacja:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _InfoTable(rows: [
                            ('TTFT', '${lastStats!.ttft.inMilliseconds} ms'),
                            ('tokeny', '${lastStats!.tokenCount}'),
                            ('czas', '${(lastStats!.totalTime.inMilliseconds / 1000).toStringAsFixed(1)} s'),
                            ('tok/s', lastStats!.tokensPerSecond.toStringAsFixed(1)),
                          ]),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Zamknij'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Question card ───────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: const Color(0xFF7C4DBC),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: Colors.white54),
                            tooltip: 'Powtórz pytanie',
                            onPressed: onRepeatQuestion,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Answer buttons ─────────────────────────────────────────
                for (int i = 0; i < riddle.answers.length; i++) ...[
                  _AnswerButton(
                    label: riddle.answers[i],
                    index: i,
                    selectedIndex: selectedIndex,
                    correctIndex: riddle.correctIndex,
                    answered: selectedIndex != null,
                    onTap: () => onAnswer(i),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Comment area ───────────────────────────────────────────
                if (selectedIndex != null) ...[
                  const SizedBox(height: 8),
                  _CommentCard(
                    comment: comment,
                    isGenerating: phase == _Phase.commenting,
                    isCorrect: selectedIndex == riddle.correctIndex,
                  ),
                ],

                // ── Next button ────────────────────────────────────────────
                if (phase == _Phase.done) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onNext,
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
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Answer button ────────────────────────────────────────────────────────────

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.answered,
    required this.onTap,
  });

  final String label;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white;
    Color textColor = const Color(0xFF333333);
    Color borderColor = const Color(0xFFDDD6F3);
    IconData? icon;

    if (answered) {
      if (index == correctIndex) {
        bgColor = const Color(0xFFD4EDDA);
        borderColor = const Color(0xFF28A745);
        textColor = const Color(0xFF1B5E20);
        icon = Icons.check_circle_rounded;
      } else if (index == selectedIndex) {
        bgColor = const Color(0xFFF8D7DA);
        borderColor = const Color(0xFFDC3545);
        textColor = const Color(0xFF7B1528);
        icon = Icons.cancel_rounded;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: borderColor.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: textColor, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Comment card ─────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.isGenerating,
    required this.isCorrect,
  });

  final String comment;
  final bool isGenerating;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF28A745) : const Color(0xFFE67E22);
    final bgColor = isCorrect
        ? const Color(0xFFD4EDDA)
        : const Color(0xFFFFF3CD);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
            child: isGenerating && comment.isEmpty
                ? Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zgadus myśli…',
                        style: TextStyle(color: color, fontSize: 14),
                      ),
                    ],
                  )
                : Text(
                    comment,
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF333333),
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── LLM stats ────────────────────────────────────────────────────────────────

class _LlmStats {
  const _LlmStats({
    required this.ttft,
    required this.totalTime,
    required this.tokenCount,
  });

  final Duration ttft;
  final Duration totalTime;
  final int tokenCount;

  double get tokensPerSecond =>
      totalTime.inMilliseconds > 0 ? tokenCount / totalTime.inSeconds : 0;
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
    final valueStyle = labelStyle.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace');
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final (label, value) in rows)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 2),
              child: Text(label, style: labelStyle),
            ),
            Text(value, style: valueStyle),
          ]),
      ],
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
