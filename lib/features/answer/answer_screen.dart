import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zagadkobot/features/riddle/riddle_screen.dart';
import 'package:zagadkobot/models/llm_stats.dart';
import 'package:zagadkobot/models/riddle.dart';
import 'package:zagadkobot/services/llm/llm_prompt.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';
import 'package:zagadkobot/widgets/answer_button.dart';

class AnswerScreen extends StatefulWidget {
  const AnswerScreen({
    super.key,
    required this.llm,
    required this.tts,
    required this.repo,
    required this.riddle,
    required this.selectedIndex,
    this.modelName,
  });

  final LlmServiceLlamaCpp llm;
  final TtsServiceFlutterTts tts;
  final RiddleRepository repo;
  final Riddle riddle;
  final int selectedIndex;
  final String? modelName;

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  String _comment = '';
  bool _generating = true;
  LlmStats? _stats;
  StreamSubscription<String>? _sub;

  bool get _isCorrect =>
      widget.selectedIndex == widget.riddle.correctIndex;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final riddle = widget.riddle;
    final prompt = buildCommentaryPrompt(
      question: riddle.question,
      correctAnswer: riddle.answers[riddle.correctIndex],
      chosenAnswer: riddle.answers[widget.selectedIndex],
      isCorrect: _isCorrect,
    );

    final stream = widget.llm.generateStream(prompt);
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
            _generating = false;
            _stats = LlmStats(
              ttft: ttft ?? Duration.zero,
              totalTime: sw.elapsed,
              tokenCount: tokenCount,
            );
          });
          widget.tts.speak(
            'Poprawna odpowiedź: ${riddle.answers[riddle.correctIndex]}. $_comment',
          );
        }
      },
      onError: (_) {
        sw.stop();
        final fallback =
            _isCorrect ? riddle.zgadusCorrect : riddle.zgadusIncorrect;
        if (mounted) {
          setState(() {
            _comment = fallback;
            _generating = false;
          });
          widget.tts.speak(
            'Poprawna odpowiedź: ${riddle.answers[riddle.correctIndex]}. $fallback',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.tts.stop();
    super.dispose();
  }

  void _nextRiddle() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => RiddleScreen(
          llm: widget.llm,
          tts: widget.tts,
          repo: widget.repo,
          modelName: widget.modelName,
          excludeId: widget.riddle.id,
          lastStats: _stats,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riddle = widget.riddle;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
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
                  _ResultChip(isCorrect: _isCorrect),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question card (read-only)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: const Color(0xFF7C4DBC),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          riddle.question,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Answer buttons (answered state)
                    for (int i = 0; i < riddle.answers.length; i++) ...[
                      AnswerButton(
                        label: riddle.answers[i],
                        index: i,
                        selectedIndex: widget.selectedIndex,
                        correctIndex: riddle.correctIndex,
                        answered: true,
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Comment card
                    const SizedBox(height: 8),
                    _CommentCard(
                      comment: _comment,
                      isGenerating: _generating,
                      isCorrect: _isCorrect,
                    ),

                    // Next button
                    if (!_generating) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _nextRiddle,
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
    final color =
        isCorrect ? const Color(0xFF28A745) : const Color(0xFFE67E22);
    final bgColor =
        isCorrect ? const Color(0xFFD4EDDA) : const Color(0xFFFFF3CD);

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
                        'Zgaduś myśli…',
                        style: TextStyle(color: color, fontSize: 14),
                      ),
                    ],
                  )
                : Text(
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
