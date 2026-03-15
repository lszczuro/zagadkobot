import 'package:flutter/material.dart';
import 'package:zagadkobot/features/riddle/riddle_screen.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/riddle_repository.dart';
import 'package:zagadkobot/services/settings_service.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _llm = LlmServiceLlamaCpp();
  final _tts = TtsServiceFlutterTts();
  final _repo = RiddleRepository();

  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final modelPath = await _resolveModelPath();
      await Future.wait([
        _llm.initialize(modelPath: modelPath),
        _tts.initialize(),
        _repo.load(),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => RiddleScreen(
            llm: _llm,
            tts: _tts,
            repo: _repo,
            modelName: _llm.modelName,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
    }
  }

  Future<String?> _resolveModelPath() async {
    final saved = await SettingsService.getModelPath();
    if (saved != null && saved.isNotEmpty) return saved;
    final models = await _llm.listModels();
    if (models.isEmpty) return null;
    models.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    final path = models.first['path'];
    if (path != null) await SettingsService.saveModelPath(path);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: SafeArea(
        child: Center(
          child: _errorMsg != null
              ? _ErrorView(
                  message: _errorMsg!,
                  onRetry: () {
                    setState(() => _errorMsg = null);
                    _init();
                  },
                )
              : const _LoadingView(),
        ),
      ),
    );
  }
}

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _progress = Tween<double>(begin: 0.1, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Zagadkobot',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5B3D9B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(painter: _RobotPainter()),
        ),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _progress,
          builder: (_, _) => _ProgressBar(value: _progress.value),
        ),
        const SizedBox(height: 12),
        const Text(
          'Budzę Zgadusia…',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF5B3D9B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: const Color(0xFFD9D0F0),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B5EA7)),
        ),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyColor = const Color(0xFFFFFFFF);
    final shadowColor = const Color(0xFFD0C8F0);
    final faceColor = const Color(0xFFF8F6FF);
    final accentColor = const Color(0xFF9B85D0);
    final eyeColor = const Color(0xFF5B3D9B);
    final cheekColor = const Color(0xFFE8DCFF);

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
    canvas.drawRRect(
      bodyRect.shift(const Offset(0, 4)),
      paint,
    );
    paint.color = bodyColor;
    canvas.drawRRect(bodyRect, paint);

    // ── Arms ──────────────────────────────────────────────────────────────
    // Left arm
    _drawArm(canvas, paint, bodyColor, shadowColor,
        center: Offset(w * 0.18, h * 0.65), angle: -0.3);
    // Right arm
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

    // Dot indicators on chest
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}
