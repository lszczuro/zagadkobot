import 'package:flutter/material.dart';
import 'package:zagadkobot/features/riddle/riddle_screen.dart';
import 'package:zagadkobot/widgets/robot_widget.dart';
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
          child: RobotWidget(),
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
