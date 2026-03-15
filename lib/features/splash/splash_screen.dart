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
      backgroundColor: const Color(0xFFF5F0FF),
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

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🤖', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(
          'Zagadkobot',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5C3D91),
          ),
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Budzę Zgadusia…', style: TextStyle(fontSize: 16)),
      ],
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
