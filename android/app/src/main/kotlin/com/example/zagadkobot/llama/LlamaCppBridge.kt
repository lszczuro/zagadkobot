package com.example.zagadkobot.llama

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Flutter Platform Channel bridge do llama.cpp.
 *
 * MethodChannel `com.zagadkownik/llama`:
 *   - `initialize` — ładuje model i ustawia parametry
 *   - `startGeneration` — rozpoczyna generowanie tokenów
 *   - `stopGeneration` — przerywa generowanie
 *   - `dispose` — zwalnia zasoby
 *
 * EventChannel `com.zagadkownik/llama_stream`:
 *   - strumieniuje tokeny do Darta
 */
class LlamaCppBridge : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LlamaCppBridge"
        private const val METHOD_CHANNEL = "com.zagadkownik/llama"
        private const val EVENT_CHANNEL = "com.zagadkownik/llama_stream"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private val llamaCpp = LlamaCpp()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var generationJob: Job? = null
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    // Parametry przechowywane po initialize
    private var systemPrompt: String = ""
    private var maxTokens: Int = 150
    private var temperature: Float = 0.8f
    private var topP: Float = 0.9f
    private var loadedModelName: String = ""

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "EventChannel onListen, sink=${events != null}")
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "EventChannel onCancel")
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
        llamaCpp.unloadModel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "startGeneration" -> handleStartGeneration(call, result)
            "stopGeneration" -> handleStopGeneration(result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val nThreads = call.argument<Int>("n_threads") ?: 4
        temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.8f
        topP = call.argument<Double>("top_p")?.toFloat() ?: 0.9f
        maxTokens = call.argument<Int>("max_tokens") ?: 150
        systemPrompt = call.argument<String>("system_prompt") ?: ""

        scope.launch {
            try {
                val modelPath = resolveModelPath()
                val success = llamaCpp.loadModel(modelPath, nThreads)
                withContext(Dispatchers.Main) {
                    if (success) {
                        loadedModelName = java.io.File(modelPath).name
                        result.success(loadedModelName)
                    } else {
                        result.error(
                            "INIT_FAILED",
                            "Nie udało się załadować modelu LLM",
                            null,
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Błąd inicjalizacji", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleStartGeneration(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt")
        if (prompt == null) {
            result.error("INVALID_ARGS", "Brak argumentu 'prompt'", null)
            return
        }

        if (!llamaCpp.isLoaded) {
            result.error("NOT_INITIALIZED", "Model nie jest załadowany", null)
            return
        }

        // Anuluj poprzednie generowanie jeśli trwa
        generationJob?.cancel()

        Log.d(TAG, "startGeneration: prompt='$prompt', sink=${eventSink != null}")

        // Natychmiast potwierdzamy odebranie komendy
        result.success(null)

        generationJob = scope.launch {
            // Czekamy aż EventSink będzie gotowy (max 2s)
            var sink = eventSink
            var waited = 0
            while (sink == null && waited < 2000) {
                delay(50)
                waited += 50
                sink = eventSink
            }

            if (sink == null) {
                Log.e(TAG, "EventSink nadal null po ${waited}ms — przerywam")
                return@launch
            }

            Log.d(TAG, "EventSink gotowy po ${waited}ms, rozpoczynam generowanie")

            try {
                val success = llamaCpp.generate(
                    prompt = prompt,
                    systemPrompt = systemPrompt,
                    maxTokens = maxTokens,
                    temperature = temperature,
                    topP = topP,
                ) { token ->
                    if (!isActive) return@generate false

                    // Wysyłamy token na main thread (wymagane przez EventSink)
                    runBlocking(Dispatchers.Main) {
                        sink.success(token)
                    }
                    isActive
                }

                Log.d(TAG, "Generowanie zakończone, success=$success")
                withContext(Dispatchers.Main) {
                    if (success) {
                        sink.endOfStream()
                    } else {
                        sink.error(
                            "GENERATION_FAILED",
                            "Generowanie nie powiodło się",
                            null,
                        )
                    }
                }
            } catch (e: CancellationException) {
                Log.d(TAG, "Generowanie anulowane")
            } catch (e: Exception) {
                Log.e(TAG, "Błąd generowania", e)
                withContext(Dispatchers.Main) {
                    sink.error("GENERATION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleStopGeneration(result: MethodChannel.Result) {
        generationJob?.cancel()
        generationJob = null
        result.success(null)
    }

    private fun handleDispose(result: MethodChannel.Result) {
        generationJob?.cancel()
        generationJob = null
        llamaCpp.unloadModel()
        result.success(null)
    }

    /**
     * Rozwiązuje ścieżkę do pliku modelu GGUF.
     * Szuka kolejno w:
     *   1. files/models/llm (app internal)
     *   2. /sdcard/Download/zagadkobot (przetrwa reinstall)
     */
    private fun resolveModelPath(): String {
        val searchDirs = listOf(
            context.filesDir.resolve("models/llm"),
            java.io.File("/data/local/tmp/zagadkobot"),
        )
        for (dir in searchDirs) {
            val ggufFiles = dir.listFiles { file -> file.extension == "gguf" } ?: continue
            // Preferuj Qwen3.5, potem dowolny Qwen, potem pierwszy z brzegu
            val preferred = ggufFiles.firstOrNull {
                it.name.contains("Qwen3.5", ignoreCase = true)
            } ?: ggufFiles.firstOrNull {
                it.name.contains("qwen", ignoreCase = true)
            } ?: ggufFiles.firstOrNull()
            if (preferred != null) {
                Log.d(TAG, "Znaleziono model: ${preferred.absolutePath}")
                return preferred.absolutePath
            }
        }
        throw IllegalStateException(
            "Nie znaleziono pliku .gguf w: ${searchDirs.joinToString { it.absolutePath }}"
        )
    }
}
