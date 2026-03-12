import 'package:flutter/material.dart';
import 'package:zagadkobot/features/home/widgets/llm_demo_panel.dart';
import 'package:zagadkobot/features/home/widgets/tts_demo_panel.dart';
import 'package:zagadkobot/services/llm/llm_service_llama_cpp.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ttsService = TtsServiceFlutterTts();
  final _llmService = LlmServiceLlamaCpp();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zagadkobot')),
      body: ListView(
        children: [
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 24, bottom: 8),
            child: Text('Wybierz temat zagadki'),
          )),
          ...[
            LlmDemoPanel(
              llmService: _llmService,
              outputController: _sharedController,
            ),
            const SizedBox(height: 8),
            TtsDemoPanel(
              ttsService: _ttsService,
              controller: _sharedController,
            ),
          ],
        ],
      ),
    );
  }

  final _sharedController = TextEditingController(
    text: 'Witaj! Jestem zagadkobot. '
        'Zgadnij: chodzi na czterech łapach i miauczy. Co to jest?',
  );

  @override
  void dispose() {
    _sharedController.dispose();
    super.dispose();
  }
}
