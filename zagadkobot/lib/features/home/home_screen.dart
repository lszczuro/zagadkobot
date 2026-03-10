import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zagadkobot/features/home/widgets/tts_demo_panel.dart';
import 'package:zagadkobot/services/tts/tts_service_flutter_tts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ttsService = TtsServiceFlutterTts();

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
          if (kDebugMode)
            TtsDemoPanel(ttsService: _ttsService),
        ],
      ),
    );
  }
}
