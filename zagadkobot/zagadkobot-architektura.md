# Architektura Aplikacji „zagadkobot" — Zagadki dla Dzieci

## 1. Podsumowanie Decyzji Technicznych

| Decyzja | Wybór | Uzasadnienie |
|---------|-------|-------------|
| **Framework** | **Flutter** | Natywny FFI do C/C++ (sherpa-onnx, llama.cpp), jeden codebase, wydajny rendering UI, dojrzały pakiet `sherpa_onnx` na pub.dev |
| **State management** | **Riverpod 2** | Compile-safe, testable, autodispose — idealny do zarządzania ciężkimi zasobami AI |
| **TTS engine** | **Piper via sherpa-onnx** | Model VITS/ONNX, polski głos (~30–60 MB), latencja <200 ms na midrange |
| **LLM on-device** | **Bielik v3 (SpeakLeash)** — 1.5B (MVP) / 4.5B (premium) | Polski LLM! Trenowany na 292 mld tokenów PL, własny tokenizer APT4, GGUF via llama.cpp. Bije modele 2-3× większe na polskich benchmarkach |
| **LLM runtime** | **llama.cpp** (via platform channel Kotlin) | Najszybszy inference na ARM, obsługa GGUF, GPU delegate Vulkan |
| **STT (przyszłość)** | **sherpa-onnx** (Whisper Small / Zipformer) | Ten sam runtime co TTS, jeden natywny bridge |
| **Min Android** | API 26 (Android 8.0) | Pokrycie ~95% urządzeń, wymagane dla NNAPI |

---

## 2. Diagram Architektury Warstwowej

```mermaid
graph TB
    subgraph "WARSTWA UI — Flutter/Dart"
        A[Ekran Główny<br/>4 kafelki tematów] --> B[Ekran Zagadki<br/>animacja + audio player]
        B --> C[Ekran Odpowiedzi<br/>feedback wizualny]
        A --> D[Ekran Ustawień<br/>głośność, głos, pobieranie modeli]
    end

    subgraph "WARSTWA LOGIKI — Riverpod Providers"
        E[RiddleSessionNotifier<br/>stan gry] --> F[AIServiceProvider<br/>orkiestracja pipeline]
        F --> G[TTSProvider<br/>synteza mowy]
        F --> H[LLMProvider<br/>generowanie zagadek]
        F --> I["STTProvider (stub)<br/>przyszły input głosowy"]
        J[ModelManagerProvider<br/>ładowanie / ciepły cache]
    end

    subgraph "WARSTWA AI — Native (C/C++ via FFI/Platform Channel)"
        K["sherpa-onnx (FFI)<br/>Piper TTS polski"] 
        L["llama.cpp (Platform Channel)<br/>Bielik v3 1.5B / 4.5B"]
        M["sherpa-onnx (FFI)<br/>Whisper STT (przyszłość)"]
    end

    subgraph "WARSTWA DANYCH"
        N[assets/models/<br/>TTS model ~50 MB]
        O[assets/models/<br/>Bielik 1.5B GGUF ~1 GB]
        P[SharedPreferences<br/>postęp, ustawienia]
        Q[SQLite<br/>cache zagadek]
    end

    B --> E
    G --> K
    H --> L
    I --> M
    K --> N
    L --> O
    E --> P
    E --> Q
    J --> N
    J --> O

    style A fill:#4CAF50,color:#fff
    style B fill:#4CAF50,color:#fff
    style C fill:#4CAF50,color:#fff
    style D fill:#4CAF50,color:#fff
    style E fill:#2196F3,color:#fff
    style F fill:#2196F3,color:#fff
    style G fill:#2196F3,color:#fff
    style H fill:#2196F3,color:#fff
    style I fill:#2196F3,color:#fff,stroke-dasharray: 5 5
    style J fill:#2196F3,color:#fff
    style K fill:#FF9800,color:#fff
    style L fill:#FF9800,color:#fff
    style M fill:#FF9800,color:#fff,stroke-dasharray: 5 5
```

---

## 3. Sekwencja Główna — Od Kliknięcia Kafelka do Odtworzenia Głosu

```mermaid
sequenceDiagram
    participant U as Dziecko (UI)
    participant R as RiddleSessionNotifier
    participant LLM as LLMProvider (llama.cpp)
    participant TTS as TTSProvider (Piper)
    participant AP as AudioPlayer

    U->>R: Kliknięcie kafelka "Zwierzęta 🐾"
    R->>R: setState(loading), pokaż animację
    R->>LLM: generateRiddle(topic: "zwierzęta", lang: "pl")
    
    Note over LLM: System prompt:<br/>"Jesteś zabawnym prowadzącym zagadki<br/>dla dzieci 5-10 lat. Odpowiedz jednym<br/>zdaniem zagadką po polsku o: {temat}.<br/>Podaj 3 możliwe odpowiedzi, jedna poprawna."

    LLM-->>R: Stream tokenów (pierwsze tokeny ~300ms)
    
    Note over R: Po otrzymaniu pełnego zdania<br/>zagadki — natychmiast wyślij do TTS<br/>(nie czekaj na opcje odpowiedzi)

    R->>TTS: synthesize(firstSentence)
    TTS-->>AP: PCM audio chunks (streaming)
    AP->>U: ▶️ Odtwarzanie głosu zagadki

    Note over U: Time-to-first-audio: ~800ms–1.2s<br/>(LLM prefill + TTS pierwszego zdania)

    LLM-->>R: Reszta odpowiedzi (opcje A/B/C)
    R->>R: setState(riddleReady), pokaż opcje
    U->>R: Kliknięcie odpowiedzi "B) Kot"
    R->>R: Sprawdź odpowiedź → feedback
    R->>TTS: synthesize("Brawo! To kot!")
    TTS-->>AP: Audio feedback
    AP->>U: 🎉 Dźwięk + animacja
```

---

## 4. Struktura Projektu

```
zagadkobot/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/.../
│   │   │   │   ├── MainActivity.kt
│   │   │   │   ├── LlamaCppBridge.kt        # Platform channel → llama.cpp
│   │   │   │   └── ModelDownloadService.kt   # Background download
│   │   │   ├── jniLibs/                      # llama.cpp .so per ABI
│   │   │   └── AndroidManifest.xml
│   │   └── build.gradle.kts
│   └── build.gradle.kts
│
├── lib/
│   ├── main.dart
│   ├── app.dart                              # MaterialApp, routing
│   │
│   ├── core/
│   │   ├── constants.dart                    # Prompts, limity, ścieżki modeli
│   │   ├── theme.dart                        # Kolory, typo (duże, czytelne)
│   │   └── logger.dart
│   │
│   ├── features/
│   │   ├── home/
│   │   │   ├── home_screen.dart              # 4 kafelki tematów
│   │   │   └── widgets/
│   │   │       └── topic_tile.dart           # Kafelek z emoji + nazwa
│   │   │
│   │   ├── riddle/
│   │   │   ├── riddle_screen.dart            # Wyświetlanie zagadki + opcje
│   │   │   ├── riddle_controller.g.dart      # Riverpod codegen
│   │   │   └── widgets/
│   │   │       ├── answer_button.dart
│   │   │       ├── riddle_animation.dart
│   │   │       └── audio_wave_indicator.dart
│   │   │
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── model_download_screen.dart    # Postęp pobierania modeli
│   │
│   ├── services/
│   │   ├── ai/
│   │   │   ├── llm_service.dart              # Abstrakcja LLM
│   │   │   ├── llm_service_llamacpp.dart     # Impl. via platform channel
│   │   │   ├── tts_service.dart              # Abstrakcja TTS
│   │   │   ├── tts_service_sherpa.dart       # Impl. via sherpa_onnx FFI
│   │   │   ├── stt_service.dart              # Abstrakcja STT (interface)
│   │   │   └── ai_pipeline.dart              # Orkiestracja: LLM → TTS → Audio
│   │   │
│   │   ├── audio/
│   │   │   ├── audio_player_service.dart     # Odtwarzanie PCM/WAV
│   │   │   └── audio_recorder_service.dart   # Przyszłość: STT input
│   │   │
│   │   └── storage/
│   │       ├── model_manager.dart            # Pobieranie, cache, wersje modeli
│   │       ├── riddle_cache.dart             # SQLite cache zagadek
│   │       └── preferences_service.dart
│   │
│   ├── providers/
│   │   ├── ai_providers.dart                 # Riverpod: LLM, TTS, pipeline
│   │   ├── session_providers.dart            # Stan gry, historia
│   │   └── settings_providers.dart
│   │
│   └── models/
│       ├── riddle.dart                       # Zagadka + opcje + odpowiedź
│       ├── topic.dart                        # Enum tematów z emoji
│       └── app_settings.dart
│
├── assets/
│   ├── models/                               # Gitignore! Pobierane po instalacji
│   │   ├── tts/                              # piper-pl-gosia-medium.onnx (~50 MB)
│   │   └── llm/                              # Bielik-1.5B-v3.0-Instruct.Q4_K_M.gguf (~1 GB)
│   ├── sounds/                               # Efekty dźwiękowe (brawo, próbuj dalej)
│   └── images/                               # Emoji/ikony tematów
│
├── test/
│   ├── services/ai/                          # Testy pipeline
│   ├── features/riddle/                      # Widget testy
│   └── integration/                          # Integration testy
│
└── pubspec.yaml
```

---

## 5. Zarządzanie Stanem — Riverpod 2

### Dlaczego Riverpod (nie Bloc, nie Provider)?

| Kryterium | Provider | Bloc | **Riverpod** |
|-----------|----------|------|-------------|
| Zarządzanie ciężkimi zasobami (modele AI) | Słabe (brak autodispose) | Manualne | **autodispose + keepAlive** |
| Testabilność | Wymaga widget tree | Dobra | **Najlepsza (ProviderContainer)** |
| Compile-time safety | Brak | Brak | **Tak (codegen)** |
| Stream + async | Ograniczone | Event-driven | **Natywne AsyncNotifier** |
| Kombajnowanie providerów | Trudne | Trudne | **ref.watch / ref.listen** |

### Kluczowe Providery

```dart
// === Model Lifecycle Provider ===
// Modele trzymane w pamięci dopóki aplikacja żyje
@Riverpod(keepAlive: true)
class ModelManager extends _$ModelManager {
  @override
  Future<ModelState> build() async {
    // Cold start: załaduj TTS (~200ms), LLM warm-up (~1-2s)
    final tts = await ref.read(ttsServiceProvider).initialize();
    final llm = await ref.read(llmServiceProvider).initialize();
    return ModelState(ttsReady: tts, llmReady: llm);
  }
}

// === Riddle Session — autodispose per ekran ===
@riverpod
class RiddleSession extends _$RiddleSession {
  @override
  RiddleState build(Topic topic) => RiddleState.initial(topic);

  Future<void> generateRiddle() async {
    state = state.copyWith(status: RiddleStatus.loading);
    final pipeline = ref.read(aiPipelineProvider);
    
    await pipeline.generateAndSpeak(
      topic: state.topic,
      onRiddleReady: (riddle) {
        state = state.copyWith(riddle: riddle, status: RiddleStatus.ready);
      },
      onAudioStart: () {
        state = state.copyWith(isPlaying: true);
      },
    );
  }

  void submitAnswer(int index) {
    final correct = index == state.riddle!.correctIndex;
    state = state.copyWith(
      selectedAnswer: index,
      status: correct ? RiddleStatus.correct : RiddleStatus.wrong,
    );
    // Odtwórz feedback audio
    ref.read(aiPipelineProvider).speakFeedback(correct);
  }
}
```

---

## 6. AI Pipeline — Szczegóły Implementacji

### 6.1 LLM: Bielik v3 (SpeakLeash) via llama.cpp Platform Channel

#### Dlaczego Bielik, a nie Gemma / Qwen / SmolLM?

| Kryterium | Gemma 3n 2B | Qwen 2.5 1.5B | **Bielik v3 1.5B** | **Bielik v3 4.5B** |
|-----------|-------------|---------------|--------------------|--------------------|
| Trening na polskim | Multilingual (PL marginalny) | Multilingual | **292 mld tokenów PL** | **292 mld tokenów PL** |
| Tokenizer PL | Generyczny (3-4 tokeny/słowo PL) | Generyczny | **APT4 — dedykowany PL** (~1.5 tok/słowo) | **APT4** |
| Open PL LLM Leaderboard | Nie testowany | Baseline | **Bije modele 2-3× większe** | **SOTA w swojej klasie** |
| Polski MT-Bench | Słaby | Średni | **Dobry (reasoning 6+)** | **Bardzo dobry** |
| Kulturowy kontekst PL | Brak | Minimalny | **Tak (PLCC benchmark)** | **Tak** |
| Rozmiar GGUF Q4_K_M | ~1.5 GB | ~1.0 GB | **~1.0 GB** | **~2.8 GB** |
| RAM (mmap) | ~1.8 GB | ~1.5 GB | **~1.2 GB** | **~3.5 GB** |
| Licencja | Gemma License | Apache 2.0 | **Apache 2.0** | **Apache 2.0** |

**Kluczowe przewagi Bielika:**
1. **Dedykowany tokenizer APT4** — polskie słowa zajmują ~40% mniej tokenów niż w modelu multilingual → szybszy inference, krótszy prompt, mniej RAM na KV-cache
2. **Trening na polskich korpusach** — rozumie polskie idiomy, kulturę, gramatykę (7 przypadków!) znacznie lepiej
3. **Zagadki wymagają kreatywnego polskiego** — Bielik generuje naturalny, poprawny gramatycznie tekst, a nie "tłumaczeniowe" frazy
4. **Projekt SpeakLeash + ACK Cyfronet AGH** — aktywny rozwój, społeczność, support

#### Strategia dwóch modeli

```
┌─────────────────────────────────────────────────────────────┐
│  BIELIK 1.5B v3 (Q4_K_M) — MODEL DOMYŚLNY (MVP)          │
│  Rozmiar: ~1.0 GB | RAM: ~1.2 GB | Speed: ~25-40 tok/s    │
│  Dla: urządzenia z 4 GB+ RAM (80% Android)                 │
│  Jakość: dobra na proste zagadki (1-2 zdania + 3 opcje)    │
├─────────────────────────────────────────────────────────────┤
│  BIELIK 4.5B v3 (Q4_K_M) — MODEL PREMIUM (opcjonalny)     │
│  Rozmiar: ~2.8 GB | RAM: ~3.5 GB | Speed: ~10-20 tok/s    │
│  Dla: urządzenia z 8 GB+ RAM (flagowce)                    │
│  Jakość: znacznie lepsza kreatywność i poprawność           │
│  Pobierany opcjonalnie w ustawieniach                       │
└─────────────────────────────────────────────────────────────┘
```

**Dlaczego Platform Channel zamiast FFI?**  
llama.cpp wymaga zarządzania wątkami i pamięcią po stronie natywnej. Kotlin/JNI pozwala na bezpieczniejszą integrację z Android lifecycle i lepszą kontrolę nad GPU delegate (Vulkan).

```
┌─────────────────────────────────────────────────┐
│  Dart (Flutter)                                 │
│  llm_service_llamacpp.dart                      │
│  MethodChannel('com.zagadkobot/llama')          │
│    → invokeMethod('generate', {prompt, params})  │
│    ← EventChannel stream tokenów                 │
└──────────────────────┬──────────────────────────┘
                       │ Platform Channel
┌──────────────────────▼──────────────────────────┐
│  Kotlin (Android)                               │
│  LlamaCppBridge.kt                              │
│    → JNI → libllama.so                           │
│    → Osobny wątek (Coroutine)                    │
│    → Token callback → EventChannel sink          │
└─────────────────────────────────────────────────┘
```

**System Prompt (Bielik ChatML format):**

```
<|start_header_id|>system<|end_header_id|>
Jesteś wesołym prowadzącym zagadki dla dzieci w wieku 5-10 lat.
Zasady:
1. Wymyśl krótką zagadkę (1-2 zdania) na temat: {TEMAT}
2. Podaj dokładnie 3 odpowiedzi oznaczone A), B), C)
3. Dokładnie jedna odpowiedź jest poprawna
4. Odpowiedz TYLKO w formacie:
   ZAGADKA: [treść zagadki]
   A) [opcja]
   B) [opcja]  
   C) [opcja]
   POPRAWNA: [A/B/C]
5. Użyj prostego języka polskiego, bądź zabawny
<|eot_id|>
<|start_header_id|>user<|end_header_id|>
Zagadka o temacie: {TEMAT}
<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
```

> **Uwaga:** Bielik v3 używa tokenów specjalnych `<|start_header_id|>`, `<|end_header_id|>`, `<|eot_id|>`.
> llama.cpp poprawnie je parsuje z GGUF metadata. Dzięki tokenizerowi APT4
> ten prompt zużywa ~60 tokenów zamiast ~90 w modelu multilingual.

**Parametry inference:**

```
temperature: 0.7      # Bielik docs sugerują niższą temp dla mniejszych kwantyzacji
top_p: 0.9
top_k: 40
max_tokens: 150        # Zagadka jest krótka; APT4 = mniej tokenów na to samo
repeat_penalty: 1.1    # Unikaj powtórzeń
n_threads: 4           # Midrange ma 4-8 rdzeni big
n_gpu_layers: 0        # MVP: CPU-only, potem Vulkan
# stop_tokens: ["<|eot_id|>", "<|start_header_id|>"]
```

### 6.2 TTS: Piper via sherpa-onnx FFI

**Model polski:** `piper-pl-gosia-medium.onnx` (~50 MB, 22.05 kHz)  
Alternatywy: `pl-meski`, `pl-darkman` (głosy z HuggingFace WitoldG)

```dart
// tts_service_sherpa.dart
class TtsServiceSherpa implements TtsService {
  late final sherpa.OfflineTts _tts;

  @override
  Future<void> initialize() async {
    final modelPath = await _modelManager.getModelPath('tts/piper-pl');
    _tts = sherpa.OfflineTts(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: '$modelPath/pl-gosia-medium.onnx',
          tokens: '$modelPath/tokens.txt',
          dataDir: '$modelPath/espeak-ng-data',
        ),
      ),
      numThreads: 2,
      maxNumSentences: 1,  // Streaming: jedno zdanie na raz
    );
  }

  @override
  Stream<Float32List> synthesizeStream(String text) async* {
    // Podziel tekst na zdania dla pseudo-streamingu
    final sentences = _splitIntoSentences(text);
    for (final sentence in sentences) {
      final audio = _tts.generate(text: sentence, sid: 0, speed: 0.9);
      yield audio.samples;  // PCM Float32
    }
  }
}
```

### 6.3 Orkiestracja Pipeline (klucz do <1.5s latencji)

```dart
// ai_pipeline.dart — KLUCZOWA OPTYMALIZACJA
class AIPipeline {
  Future<void> generateAndSpeak({
    required Topic topic,
    required Function(Riddle) onRiddleReady,
    required VoidCallback onAudioStart,
  }) async {
    final buffer = StringBuffer();
    String? firstSentence;

    // 1. Rozpocznij streaming LLM
    await for (final token in _llmService.generateStream(
      prompt: _buildPrompt(topic),
    )) {
      buffer.write(token);

      // 2. PIPELINE OVERLAP: gdy mamy pierwsze pełne zdanie →
      //    natychmiast wyślij do TTS (nie czekaj na resztę!)
      if (firstSentence == null && _hasCompleteSentence(buffer.toString())) {
        firstSentence = _extractFirstSentence(buffer.toString());
        
        // Uruchom TTS RÓWNOLEGLE z dalszym generowaniem LLM
        unawaited(_speakSentence(firstSentence).then((_) {
          onAudioStart();
        }));
      }
    }

    // 3. Parsuj pełną odpowiedź → zagadka + opcje
    final riddle = _parseRiddleResponse(buffer.toString());
    onRiddleReady(riddle);
  }
}
```

**Budżet latencji (target <1.5s time-to-first-audio):**

```
┌─────────────────────────────────────────────────────────────┐
│ Faza                         │ Czas      │ Kumulatywnie     │
├─────────────────────────────────────────────────────────────┤
│ LLM prefill (prompt ~80 tok) │ 200-400ms │ 400ms            │
│ LLM decode do "." (20-30 tok)│ 300-500ms │ 900ms            │
│ TTS synth 1. zdania (~15 sł) │ 150-300ms │ 1200ms           │
│ Audio buffer start            │ 50ms      │ 1250ms           │
│                               │           │                  │
│ BUFOR BEZPIECZEŃSTWA          │ 250ms     │ 1500ms ✅        │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Zarządzanie Modelami — Cold Start vs Warm

### 7.1 Strategia Dystrybucji Modeli

**Problem:** Bielik 1.5B Q4_K_M (~1.0 GB) + TTS (~50 MB) = nie mieści się w APK (limit Play Store ~200 MB).

**Rozwiązanie: Download-on-first-run**

```mermaid
stateDiagram-v2
    [*] --> FirstLaunch: Instalacja z Play Store (~30 MB APK)
    FirstLaunch --> ModelCheck: Sprawdź czy modele istnieją
    ModelCheck --> DownloadScreen: Brak modeli
    ModelCheck --> WarmUp: Modele obecne
    
    DownloadScreen --> Downloading: Pobierz TTS (~50 MB) + Bielik 1.5B (~1.0 GB)
    Downloading --> Verifying: SHA256 checksum
    Verifying --> WarmUp: OK
    Verifying --> DownloadScreen: Błąd → retry

    WarmUp --> AppReady: Załaduj modele do RAM
    AppReady --> [*]
    
    note right of Downloading
        Źródło: HuggingFace
        speakleash/Bielik-1.5B-v3.0-Instruct-GGUF
        Progres bar z estymacją czasu
    end note
```

### 7.2 Lifecycle Modeli w Pamięci

```
┌────────────────────────────────────────────────────────────┐
│                    COLD START (~2-4s)                       │
│                                                            │
│  App Launch → Splash Screen                                │
│    ├── TTS model load: mmap ONNX → ONNX Runtime (~300ms)  │
│    ├── Bielik 1.5B load: mmap GGUF → llama.cpp (~1-2s)    │
│    │   └── First-time: optimize weight layout + cache      │
│    └── → Home Screen gotowy                                │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                    WARM STATE                               │
│                                                            │
│  Modele trzymane w pamięci (Riverpod keepAlive: true)      │
│  ├── TTS: ~100 MB RAM (ONNX Runtime session)              │
│  ├── Bielik 1.5B: ~1.2 GB RAM (mmap, OS evict pages)     │
│  └── Total: ~1.5 GB → OK na urządzeniach 4 GB+ ✅        │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                    BACKGROUND / LOW MEMORY                  │
│                                                            │
│  Android LowMemory callback:                               │
│    ├── Priorytet 1: Zwolnij LLM (największy)              │
│    ├── Priorytet 2: TTS zostaje (mały, szybki reload)     │
│    └── Przy powrocie: re-load Bielik (~1-2s, spinner)     │
└────────────────────────────────────────────────────────────┘
```

---

## 8. Streaming Audio — TTS do Głośnika

```dart
// audio_player_service.dart
class AudioPlayerService {
  late final AudioTrack _track;  // Android AudioTrack via platform channel
  
  // Alternatywa: flutter_sound lub just_audio z custom source
  
  Future<void> playPCMStream(Stream<Float32List> audioStream) async {
    // Inicjalizuj AudioTrack: 22050 Hz, mono, Float32
    await _initTrack(sampleRate: 22050, channels: 1);
    
    await for (final chunk in audioStream) {
      // Konwersja Float32 → Int16 PCM dla AudioTrack
      final int16Data = _float32ToInt16(chunk);
      await _track.write(int16Data);
      
      // AudioTrack automatycznie buforuje i odtwarza
      // Minimalny latency: ~50ms z AUDIO_MODE_LOW_LATENCY
    }
    
    await _track.flush();
  }
  
  Int16List _float32ToInt16(Float32List float32) {
    final int16 = Int16List(float32.length);
    for (var i = 0; i < float32.length; i++) {
      int16[i] = (float32[i] * 32767).round().clamp(-32768, 32767);
    }
    return int16;
  }
}
```

**Strategia buforowania:**
- Piper generuje audio per zdanie (~0.5-2s audio na zdanie)
- Każde zdanie to jeden chunk PCM
- AudioTrack z trybem `PERFORMANCE_MODE_LOW_LATENCY`
- Double-buffering: podczas odtwarzania chunk N, TTS generuje chunk N+1

---

## 9. Przygotowanie pod STT (Rozszerzalność)

### Wzorzec Interface Segregation

```dart
// === Obecny kontrakt (MVP) ===
abstract class InputService {
  Stream<Topic> get topicSelections;  // MVP: z kafelków UI
}

// === Przyszły kontrakt (v2 ze STT) ===
abstract class VoiceInputService extends InputService {
  Future<void> startListening();
  Future<void> stopListening();
  Stream<String> get transcription;   // "Chcę zagadkę o kotach"
  Stream<Topic> get topicSelections;  // Mapowanie: NLU → Topic
}

// === Implementacja stub (MVP) ===
class TapInputService implements InputService {
  final _controller = StreamController<Topic>();
  
  void selectTopic(Topic topic) => _controller.add(topic);
  
  @override
  Stream<Topic> get topicSelections => _controller.stream;
}

// === Przyszła implementacja (v2) ===
class SherpaSTTInputService implements VoiceInputService {
  // sherpa-onnx Whisper Small PL (~200 MB)
  // + prosty NLU: keyword matching "kot" → Topic.animals
  // Sherpa ma już Flutter examples dla streaming ASR
}
```

### Co trzeba przygotować w MVP:

1. **`RECORD_AUDIO` permission** — dodaj do Manifestu już teraz (nie pytaj o nią, ale zadeklaruj)
2. **Abstrakcja `InputService`** — kafelki to jedna implementacja, STT to druga
3. **Routing** — ekran główny powinien mieć slot na przycisk mikrofonu (ukryty w MVP)
4. **sherpa-onnx dependency** — jest już w projekcie dla TTS, STT to dodanie modelu Whisper

---

## 10. Publikacja w Google Play

### 10.1 Checklist Techniczny

```
PRE-RELEASE:
├── Signing
│   ├── Generuj upload key: keytool -genkey -v -keystore upload.jks
│   ├── Skonfiguruj key.properties (NIE commituj do repo!)
│   ├── Włącz Play App Signing (Google zarządza release key)
│   └── build.gradle: signingConfigs → release
│
├── Build
│   ├── flutter build appbundle --release
│   ├── AAB (nie APK!) — wymagane przez Play Store
│   ├── Proguard / R8: zachowaj JNI klasy llama.cpp
│   │   └── -keep class com.zagadkobot.llama.** { *; }
│   ├── Split APKs per ABI: arm64-v8a (priorytet), armeabi-v7a
│   └── Asset Delivery: Large models via Play Asset Delivery (PAD)
│       ├── install-time: TTS model (~50 MB)
│       └── on-demand: LLM model (~1.5 GB) — Fast-follow delivery
│
├── Permissions (AndroidManifest.xml)
│   ├── INTERNET — pobieranie modeli (jeśli nie PAD)
│   ├── RECORD_AUDIO — zadeklaruj dla przyszłego STT
│   │   └── W MVP: nie pytaj runtime, tylko deklaracja w manifeście
│   ├── FOREGROUND_SERVICE — pobieranie w tle
│   └── NIE potrzebujesz: WRITE_EXTERNAL_STORAGE (scoped storage)
│
├── Play Asset Delivery (kluczowe!)
│   ├── base APK: <150 MB (Flutter app + TTS model)
│   ├── on-demand pack: Bielik 1.5B GGUF ~1.0 GB
│   │   └── Pobierane po instalacji, z progress barem
│   │   └── Źródło: speakleash/Bielik-1.5B-v3.0-Instruct-GGUF
│   └── Konfiguracja w build.gradle → assetPacks
│
└── Store Listing
    ├── Target audience: dzieci → WYMAGA Family Policy compliance
    ├── Content rating: IARC → Everyone
    ├── Privacy policy: WYMAGANA (brak zbierania danych)
    ├── Data safety form: "No data collected"
    ├── Teacher Approved badge: opcjonalne, ale wartościowe
    └── Designed for Families: tak → dodatkowe wymagania UI
```

### 10.2 Families Policy — Krytyczne Wymagania

Aplikacja kierowana do dzieci musi spełniać rygorystyczne wymagania Google:

- **Brak reklam** z sieci reklamowych niecertyfikowanych przez Google
- **Brak zbierania danych** (PII) bez zgody rodzica (COPPA)
- **Login**: jeśli wymagany → weryfikacja wieku
- **Content**: brak przemocy, treści nieodpowiednich
- **Privacy Policy**: musi jasno określać brak zbierania danych
- **Offline-first**: nasz model spełnia to idealnie (brak transmisji danych)

---

## 11. Wąskie Gardła i Mitygacja

### 11.1 Tabela Ryzyk

| # | Ryzyko | Prawdopodobieństwo | Wpływ | Mitygacja |
|---|--------|-------------------|-------|-----------|
| 1 | **LLM zbyt wolny na low-end** | Średnie | Krytyczny | Bielik 1.5B jest mniejszy niż Gemma 2B → szybszy; cache zagadek w SQLite; fallback na preset |
| 2 | **Za mało RAM** (urządzenia <4GB) | Średnie | Krytyczny | Bielik 1.5B Q4 = ~1.2 GB RAM (mniej niż multilingual 2B); graceful degradation na preset zagadki |
| 3 | **Jakość polskiego w LLM** | **Niskie** | Wysoki | **Bielik trenowany na 292 mld tokenów PL — ryzyko znacznie niższe niż z modelem multilingual** |
| 4 | **TTS brzmi nienaturalnie** | Niskie | Średni | Testuj głosy Piper PL; dopasuj speed=0.9 dla dzieci; dodaj pauzy |
| 5 | **Model download failure** | Średnie | Wysoki | Resume downloads; chunk downloading; SHA256 verify; retry z exponential backoff |
| 6 | **APK za duży** | Niskie | Średni | Play Asset Delivery; modele on-demand; split per ABI |
| 7 | **LLM generuje nieodpowiednie treści** | Niskie | Krytyczny | Ścisły system prompt; whitelist tematów; filtr output (regex na wulgaryzmy) |
| 8 | **Cold start >5s** | Średnie | Średni | Splash screen z animacją; ładuj TTS najpierw (mały, szybki); lazy load LLM |
| 9 | **Battery drain** | Średnie | Średni | Inference tylko na żądanie; zwalniaj LLM po 5 min nieaktywności |
| 10 | **Google Play rejection (Family Policy)** | Średnie | Krytyczny | Audyt przed submitem; brak internetu w trakcie gry; privacy policy |

### 11.2 Strategia Fallback — Zagadki Offline (bez LLM)

Na wypadek urządzeń, które nie obsłużą LLM, przygotuj ~200 zagadek wbudowanych w aplikację:

```dart
// riddle_cache.dart
class RiddleCache {
  // Priorytet źródeł zagadek:
  // 1. LLM on-device (jeśli model załadowany)
  // 2. Wcześniej wygenerowane zagadki (SQLite cache)
  // 3. Predefiniowane zagadki (assets/riddles_pl.json)
  
  Future<Riddle> getRiddle(Topic topic) async {
    if (await _llmAvailable()) {
      return _generateFresh(topic);
    }
    
    final cached = await _db.getUnusedRiddle(topic);
    if (cached != null) return cached;
    
    return _getPresetRiddle(topic);  // Zawsze działa, brak AI
  }
}
```

---

## 12. Budżet Pamięci i Wymagania Sprzętowe

```
┌──────────────────────────────────────────────────────────────────┐
│           BUDŻET RAM — BIELIK 1.5B (MVP, midrange 4-6 GB RAM)  │
├──────────────────────────────────────────────────────────────────┤
│ Komponent                        │ RAM          │ Dysk           │
├──────────────────────────────────┼──────────────┼────────────────┤
│ Flutter engine + UI              │ ~80 MB       │ —              │
│ Piper TTS (ONNX Runtime)        │ ~100 MB      │ ~50 MB         │
│ Bielik 1.5B v3 Q4_K_M (mmap)   │ ~1.0-1.2 GB* │ ~1.0 GB       │
│ Audio buffers                    │ ~10 MB       │ —              │
│ SQLite cache                     │ ~5 MB        │ ~10 MB         │
│ System overhead                  │ ~200 MB      │ —              │
├──────────────────────────────────┼──────────────┼────────────────┤
│ RAZEM                            │ ~1.5 GB      │ ~1.1 GB        │
│ * mmap = OS ładuje tylko potrzebne strony                       │
├──────────────────────────────────────────────────────────────────┤
│           BUDŻET RAM — BIELIK 4.5B (premium, flagowce 8+ GB)   │
├──────────────────────────────────┼──────────────┼────────────────┤
│ Bielik 4.5B v3 Q4_K_M (mmap)   │ ~3.0-3.5 GB* │ ~2.8 GB       │
│ RAZEM z TTS + UI                │ ~3.9 GB      │ ~2.9 GB        │
└──────────────────────────────────────────────────────────────────┘

Bielik 1.5B MVP: min 4 GB RAM → ~80% urządzeń Android ✅
Bielik 4.5B premium: min 8 GB RAM → ~40% urządzeń Android
Dysk: ~1.2 GB (MVP) / ~3.0 GB (premium) po instalacji

BONUS tokenizera APT4: polskie słowa = ~40% mniej tokenów
→ mniejszy KV-cache → mniej RAM na inference → szybciej!
```

---

## 13. Roadmap MVP → v2

```
MVP (miesiąc 1-2):
├── 4 tematy zagadek (kafelki)
├── Bielik 1.5B v3 on-device → generowanie zagadek PL
├── TTS Piper → głosowa odpowiedź
├── Fallback: preset zagadki (brak AI na słabych urządzeniach)
├── Download manager modeli (HuggingFace CDN)
└── Publikacja Google Play (Family)

v1.1 (miesiąc 3):
├── Więcej tematów (8-12)
├── System punktów / gwiazdek
├── Animacje i dźwięki nagród
├── Cache inteligentny (prefetch zagadek)
├── Opcjonalny Bielik 4.5B v3 (flagowce 8 GB+ RAM)
└── Optymalizacja: Vulkan GPU dla LLM

v2.0 (miesiąc 4-5):
├── STT: dziecko mówi jaki chce temat
├── Whisper Small PL via sherpa-onnx
├── Prosty NLU: mapowanie mowy → temat
├── Tryb konwersacyjny (follow-up pytania)
└── Personalizacja poziomu trudności
```
