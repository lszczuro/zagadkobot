import 'package:flutter/material.dart';
import 'package:zagadkobot/core/theme.dart';
import 'package:zagadkobot/features/home/home_screen.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/settings_service.dart';

class ZagadkobotApp extends StatelessWidget {
  const ZagadkobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zagadkobot',
      theme: AppTheme.lightTheme,
      home: const _StartupRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _StartupRouter extends StatelessWidget {
  const _StartupRouter();

  Future<String?> _resolveModelPath() async {
    final saved = await SettingsService.getModelPath();
    if (saved != null && saved.isNotEmpty) return saved;
    final models = await LlmServiceLlamaCpp().listModels();
    if (models.isEmpty) return null;
    models.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    final path = models.first['path'];
    if (path != null) await SettingsService.saveModelPath(path);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveModelPath(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(modelPath: snapshot.data);
      },
    );
  }
}
