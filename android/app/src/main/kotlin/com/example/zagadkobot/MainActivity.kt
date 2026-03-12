package com.example.zagadkobot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.zagadkobot.llama.LlamaCppBridge

class MainActivity : FlutterActivity() {
    private val llamaBridge = LlamaCppBridge()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(llamaBridge)
    }
}
