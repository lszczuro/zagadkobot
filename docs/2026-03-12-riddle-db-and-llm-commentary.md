# 📓 Notatnik Projektu — Zagadkobot - 2026-03-12

## 🎯 Cel dnia

Zmiana podejścia do generowania zagadek. Po wczorajszych testach okazało się, że małe modele (<3B) są zbyt słabe, żeby samodzielnie wymyślać zagadki — halucynują, nie trzymają formatu, mają słabą wiedzę o świecie. Postanowiłem rozdzielić odpowiedzialności: **zagadki z bazy danych, LLM tylko do komentarza po odpowiedzi dziecka.**

---

## 🛠️ Zmiany Architektoniczne

### Poprzednie podejście

```
Kliknięcie kafelka → LLM generuje zagadkę (stream) → wyświetlenie → TTS
```

### Nowe podejście

```
Baza zagadek (JSON) → losowanie → wyświetlenie pytania + 3 opcje → odpowiedź dziecka
                                                                          ↓
                                                  LLM generuje komentarz (Zgadus) → TTS
```

---

## 📅 Dziennik

### 12.03.2026

**Co robiłem:**

1. **Wygenerowano bazę zagadek** `riddles_db.json` — zagadki wielokrotnego wyboru (3 opcje, wskazany `correct_index`) dla dzieci 5–8 lat, z kategoriami (zwierzęta, rośliny, kosmos itd.) i poziomami trudności. Każda zagadka ma predefiniowane komentarze Zgadusia (`zgadus_correct`, `zgadus_incorrect`, `zgadus_hint`).

2. **Przygotowano dane treningowe** `training_chatml.json` — zbiór par prompt/odpowiedź w formacie ChatML do fine-tuningu modelu Qwen2.5-4B na zadanie generowania komentarza po odpowiedzi. Format promptu:
   ```
   Zagadka: [treść]
   Prawidłowa odpowiedź: [odpowiedź]
   Dziecko wybrało: [odpowiedź] ✓/✗
   ```

3. **Przepisano UI aplikacji** — nowy ekran quizu zastąpił panele demo (LlmDemoPanel, TtsDemoPanel):
   - Karta z treścią zagadki
   - 3 przyciski odpowiedzi (A/B/C) z animowanym podświetleniem po odpowiedzi (zielony/czerwony)
   - Panel komentarza Zgadusia ze streamowaną odpowiedzią LLM
   - Przycisk "Następna zagadka"
   - TTS czyta pytanie przy ładowaniu i komentarz po odpowiedzi

4. **Zaktualizowano model i serwisy:**
   - `Riddle` — przepisany na nową strukturę z bazy (usunięto `fromLLMResponse`, dodano pola `zgadus_*`)
   - `RiddleRepository` — nowy serwis ładujący JSON z assets Flutter
   - `llm_prompt.dart` — nowy system prompt Zgadusia + `buildCommentaryPrompt()`

**Co zauważyłem:** Rozdzielenie odpowiedzialności znacznie obniża wymagania co do modelu — zamiast generować całą zagadkę ze strukturą i poprawnym formatem, model musi tylko sformułować jedno zdanie komentarza. Model potrafi generować zdania po polsku (choć czasami zmienia język na chiński / angielski).

**Wniosek:** Architektura bardziej odporna na słabości małych modeli. Zmiana modelu na Qwen3.5-4B oraz fine-tuning na `training_chatml.json` powinien dać lepsze wyniki przy ograniczeniach sprzętowych.

**Następny krok:** Fine-tuning Qwen3.5-4B → testy na urządzeniu → ocena jakości komentarzy.

---

### 12.03.2026 — Fine-tuning Qwen3.5-4B

**Co robiłem:**

1. **Wybór modelu** — zdecydowałem się na `unsloth/Qwen3.5-4B` jako kompromis między jakością a rozmiarem dla urządzeń mobilnych. Model waży ~2.5GB po kwantyzacji Q4_K_M, mieści się na flagowych telefonach i trenuje na darmowym T4 w Google Colab (10GB VRAM).

2. **Przygotowanie pipeline'u fine-tuningu** — użyto frameworka Unsloth z notebookiem `Qwen3_(4B)-Instruct.ipynb`.

3. **Format danych treningowych** — dane w formacie ChatML z kluczami `role`/`content` (standard OpenAI). `standardize_data_formats` z Unsloth konwertuje automatycznie format ShareGPT (`from`/`value`) → ChatML.

4. **Trening** — 1 epoka, Batch size 2, gradient accumulation 4, learning rate 2e-4.

5. **Eksport** — `model.save_pretrained_gguf()` z kwantyzacją `q4_k_m`

---

## 🔥 Problemy i Rozwiązania

### 12.03.2026 — Modele <3B generują słabej jakości zagadki

**Problem:** Qwen2.5-0.5B, 1.5B, 3B (i Bielik 1.5B) nie są w stanie samodzielnie wymyślić zagadki spełniającej wymagania: poprawna wiedza o świecie, poprawny format (3 opcje + wskazanie poprawnej), język polski, odpowiedni poziom dla dziecka.

**Rozwiązanie:** Zagadki wygenerowane offline i zapisane jako `riddles_db.json` (asset). LLM odpowiada tylko za 1–2 zdania komentarza — zadanie znacznie prostsze, dostępne dla mniejszych modeli po fine-tuningu.

**Wniosek:** Fine-tuning małego modelu na wąskie zadanie (komentarz) > prompt engineering ogólnego modelu na szerokie zadanie (generowanie zagadki).

---

## 📊 Zmiany w Kodzie

| Plik | Zmiana |
|---|---|
| `pubspec.yaml` | Dodano `riddles_db.json` jako asset |
| `lib/models/riddle.dart` | Nowa struktura pól zgodna z DB, ręczny `fromJson` (usunięto code generation) |
| `lib/services/riddle_repository.dart` | Nowy serwis — ładowanie JSON z assets, `random()`, `randomExcluding()` |
| `lib/services/llm/llm_prompt.dart` | Nowy system prompt Zgadusia + `buildCommentaryPrompt()` |
| `lib/features/home/home_screen.dart` | Całkowity rewrite — ekran quizu z maszyną stanów (`loading → question → commenting → done`) |

---

## 🏁 Stan na koniec dnia

- ✅ Baza zagadek gotowa (`riddles_db.json`)
- ✅ Dane treningowe gotowe (`training_chatml.json`)
- ✅ Nowe UI quizu zaimplementowane
- ✅ Model wybrany: `unsloth/Qwen3.5-4B`, kwantyzacja `q4_k_m`
- ✅ Pipeline fine-tuningu skonfigurowany (Unsloth + Colab T4, LoRA r=32)
- ✅ Format danych treningowych zweryfikowany (ChatML, tokeny `<|im_start|>`/`<|im_end|>`)
- ⏳ Fine-tuning Qwen3.5-4B — trening w toku (blokada: problemy środowiskowe Colab rozwiązane)
- ⏳ Eksport GGUF i testy modelu po fine-tuningu na urządzeniu — do zrobienia
