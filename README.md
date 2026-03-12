# Zagadkobot 🤖

Aplikacja mobilna (Android) z zagadkami dla dzieci w wieku 5–8 lat. Działa **w pełni offline** — lokalna baza zagadek + lokalny model językowy (LLM) generujący komentarze po odpowiedzi dziecka.

> Głównym celem projektu było sprawdzenie, czy uruchomienie LLM bezpośrednio na urządzeniu mobilnym jest możliwe i użyteczne — oraz nauka całego pipeline'u: od doboru modelu, przez fine-tuning, po integrację z aplikacją Flutter. Projekt był eksperymentem — architektura ewoluowała w trakcie prac, a szczegółowe notatki, decyzje techniczne i historia zmian opisane są w [/docs](./docs/).

---

## Jak działa

```
riddles_db.json ──► losuj zagadkę ──► wyświetl pytanie + 3 opcje
                                              │
                              dziecko wybiera odpowiedź
                                              │
                              LLM (Zgaduś) generuje komentarz
                                              │
                              TTS odczytuje komentarz na głos
```

Zagadki są predefiniowane (baza JSON), a LLM zajmuje się jedynie sformułowaniem krótkiego, przyjaznego komentarza po odpowiedzi dziecka. Dzięki temu nawet mały, fine-tunowany model radzi sobie z tym zadaniem na urządzeniu mobilnym.

---

## Stack technologiczny

| Warstwa | Technologia | Uwagi |
|--------|-------------|-------|
| Framework | Flutter | Jeden codebase, natywne Platform Channel do C++ |
| LLM runtime | llama.cpp (via Kotlin Platform Channel) | Inference GGUF na ARM, streaming tokenów |
| LLM model | Qwen3.5-4B (fine-tuned) | ~2.5 GB po kwantyzacji Q4_K_M |
| Min Android | API 26 (Android 8.0) | ~95% urządzeń |

---

## Baza zagadek (`riddles_db.json`)

Każda zagadka ma strukturę:

```json
{
  "id": "zwierzęta_0000",
  "category": "zwierzęta",
  "difficulty": "łatwa",
  "question": "Mam długą szyję i jem listki z wysokich drzew...",
  "answers": ["Żyrafa", "Słoń", "Zebra"],
  "correct_index": 0,
  "zgadus_correct": "Brawo! 🎉 To była żyrafka!",
  "zgadus_incorrect": "Ojej, to nie to zwierzątko...",
  "zgadus_hint": "Pamiętaj, że to zwierzątko ma bardzo długą szyję..."
}
```

Pola `zgadus_*` służą jako dane treningowe i jako fallback gdy LLM nie jest dostępny.

---

## Fine-tuning modelu

Model Zgadusia jest fine-tunowany na zadanie generowania komentarza po odpowiedzi dziecka.

### Generowanie danych treningowych

```bash
python scripts/chat-ml-conversion.py
# Wejście:  riddles_db.json
# Wyjście:  training_chatml.json  (3 przykłady na zagadkę: ✓, ✗, podpowiedź)
```

### Format danych (ShareGPT / ChatML)

```json
{
  "conversations": [
    { "from": "system", "value": "Jesteś Zgadusiem — wesołą maskotką..." },
    { "from": "human",  "value": "Zagadka: ...\nPrawidłowa odpowiedź: Żyrafa\nDziecko wybrało: Żyrafa ✓" },
    { "from": "gpt",    "value": "Brawo! 🎉 To była żyrafka!" }
  ]
}
```

### Trening (Unsloth + Google Colab T4)

- Model bazowy: `unsloth/Qwen3.5-4B-Instruct`
- Framework: [Unsloth](https://github.com/unslothai/unsloth) z LoRA (r=32)
- Sprzęt: Google Colab T4 (10 GB VRAM)
- Eksport: `model.save_pretrained_gguf()` z kwantyzacją `q4_k_m`

---

## Uruchomienie (deweloperskie)

```bash
flutter pub get
flutter run
```

Aplikacja wymaga załadowanego modelu GGUF w ścieżce oczekiwanej przez `LlmServiceLlamaCpp`. Szczegóły konfiguracji natywnego bridge'u w `android/app/src/main/kotlin/`.

---

## Stan projektu

| Funkcja | Status |
|--------|--------|
| Baza zagadek (`riddles_db.json`) | ✅ gotowe |
| Dane treningowe (`training_chatml.json`) | ✅ gotowe |
| UI quizu (pytanie + przyciski + komentarz LLM) | ✅ gotowe |
| LLM runtime (llama.cpp via Platform Channel) | ✅ działa |
| TTS (flutter_tts — placeholder) | ✅ działa |
| Fine-tuning Qwen3.5-4B | ⏳ w toku |
| Testy fine-tunowanego modelu na urządzeniu | ⏳ do zrobienia |
