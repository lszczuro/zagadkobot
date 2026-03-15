# 📓 Notatnik Projektu — Zagadkobot — 2026-03-15

## 🎯 Cel dnia

Ocena jakości modelu `Bielik-1.5B-v3.0-Instruct` po fine-tuningu na zadanie generowania komentarzy Zgadusia. Porównanie z modelami bazowymi (bez fine-tuningu) różnych rozmiarów: Bielik Q8_0, Qwen2.5 1.5B i Qwen2.5 3B. Ustalenie, czy fine-tuning faktycznie przekłada się na mierzalną poprawę jakości.

---

## 🛠️ Metodologia testów

Napisano skrypt `scripts/test-model.py` oparty na `llama-cpp-python`. Każdy model testowano na **20 losowych próbkach** z datasetu `bielik_dataset.json` (1218 wpisów, seed=42 — identyczne próbki dla wszystkich modeli).

**Metryki:**

| Metryka | Opis |
|---|---|
| **Jaccard overlap** | Podobieństwo zbioru słów między oczekiwaną a wygenerowaną odpowiedzią |
| **Recall** | Ile słów z oczekiwanej odpowiedzi pojawia się w wygenerowanej |
| **Trafny wydźwięk** | Czy model rozróżnia pochwalę (poprawna odpowiedź) od naprowadzania (błędna) |
| **Emoji** | Średnia liczba emoji w odpowiedzi |
| **Czas odpowiedzi** | Śr. czas generowania jednej odpowiedzi (CPU, n_threads=4) |

**Uwaga:** Overlap i recall są celowo niskie dla modeli generatywnych — nie kopiują tekstu ze zbioru treningowego. Kluczową metryką jest **trafny wydźwięk** — czy model rozumie kontekst (pochwała vs. naprowadzenie).

**Parametry inference:** temperature=0.7, top_p=0.9, max_tokens=128, n_ctx=512

---

## 📅 Dziennik

### 15.03.2026 — Wyniki porównania modeli

#### Weryfikacja formatu chat template

Przed testami sprawdzono metadane GGUF modelu Bielik (`scripts/check-format.py`). Okazało się, że **Bielik-1.5B-v3.0 używa identycznego formatu ChatML** (`<|im_start|>`/`<|im_end|>`) co Qwen2.5 — kod w `llama_jni.cpp` jest w pełni kompatybilny bez żadnych zmian.

#### Wyniki

| Model | Overlap | Recall | Wydźwięk | Emoji (oczek./gen.) | Śr. czas |
|---|---|---|---|---|---|
| **Bielik 1.5B Q4_K_M (fine-tuned)** | **0.282** | **0.418** | **18/20 (90%)** | 0.5 / 1.2 | **0.95s** |
| Bielik 1.5B Q8_0 (bazowy) | 0.080 | 0.197 | 11/20 (55%) | 0.5 / 1.9 | 2.9s |
| Qwen2.5 1.5B Q4_K_M (bazowy) | 0.038 | 0.112 | 6/20 (30%) | 0.5 / 0.0 | 2.0s |
| Qwen2.5 3B Q4_K_M (bazowy) | 0.085 | 0.194 | 9/20 (45%) | 0.5 / 0.0 | 3.9s |
| Qwen3.5 4B Q4_K_M (fine-tuned) | — | — | — | — | — |

> Qwen3.5 4B — nie przetestowany. To model multimodalny (VLM) z projektorem wizyjnym (`F16-mmproj.gguf`). Standardowe `llama-cpp-python` nie może go załadować. Wymaga `llama-mtmd-cli` lub dedykowanego backendu.

#### Obserwacje

**Bielik fine-tuned dominuje we wszystkich metrykach:**
- Trafny wydźwięk **90%** vs. 55% dla bazowego Bielika Q8_0 — fine-tuning daje skok o 35 p.p.
- Fine-tuned Q4_K_M **bije bazowy Q8_0** mimo niższej precyzji kwantyzacji — architektura i wagi mają większy wpływ niż kwantyzacja
- Czas odpowiedzi 0.95s to **3× szybciej** niż bazowy Bielik Q8_0 (2.9s) i 4× szybciej niż Qwen2.5 3B (3.9s)

**Modele bazowe (bez fine-tuningu) są nieprzydatne:**
- Qwen2.5 1.5B — odpowiedzi chaotyczne, zbyt długie, zły ton (np. *"Twoje zrozumienie i interpretacja jest wspaniale! To oznacza, że masz bardzo wysokie poziom poznawczy!"* zamiast krótkiej pochwały)
- Qwen2.5 3B — podobny problem pomimo 2× większego modelu; nie kompensuje braku fine-tuningu
- Bazowy Bielik Q8_0 — zna polski, ale nie rozumie roli Zgadusia; przesadza z emoji (śr. 1.9 vs. oczekiwane 0.5)

**Drobny problem z emoji u fine-tuned Bielika:**
- Model generuje emoji nawet gdy dataset ich nie ma (e=0 → a=1 w kilku próbkach)
- W 2 przypadkach przesadził (3–4 emoji). Można złagodzić przez dodanie do system promptu: `"Używaj max 1 emoji na odpowiedź."`

---

## 🔥 Problemy i Rozwiązania

### Moduł `gguf` niedostępny w domyślnym środowisku

**Problem:** `ModuleNotFoundError: No module named 'gguf'` przy uruchomieniu `check-format.py`.

**Rozwiązanie:** `python -m pip install gguf` (instalacja do user site-packages, nie do venv).

### Błąd kodowania emoji na Windows

**Problem:** `UnicodeEncodeError: 'charmap' codec can't encode character '\U0001f389'` — terminal Windows używa domyślnie cp1250.

**Rozwiązanie:** Dodano na początku skryptu:
```python
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
```

### Qwen3.5 4B — model multimodalny (VLM)

**Problem:** `ValueError: Failed to load model from file` — `llama-cpp-python` nie obsługuje modeli z projektorem wizyjnym.

**Rozwiązanie:** Pomięto w testach. Wymaga osobnego podejścia (`llama-mtmd-cli`). Nie wpływa na główny wniosek — Bielik fine-tuned jest i tak lepszy.

---

## 📊 Zmiany w Kodzie

| Plik | Zmiana |
|---|---|
| `scripts/check-format.py` | Skrypt do odczytu chat template z metadanych GGUF |
| `scripts/test-model.py` | Skrypt porównawczy modeli: metryki overlap/recall/wydźwięk/emoji/czas |
| `scripts/test-results.json` | Wyniki ostatniego uruchomienia (nadpisywane przy każdym teście) |

---

## 🏁 Stan na koniec dnia

- ✅ Zweryfikowano kompatybilność formatu chat template Bielika z kodem JNI (ChatML = bez zmian)
- ✅ Napisano powtarzalny skrypt testowy (`test-model.py`) z metrykami ilościowymi
- ✅ Fine-tuned Bielik 1.5B Q4_K_M — **potwierdzono jako najlepszy model** spośród dostępnych
- ✅ Fine-tuning przekłada się na realną poprawę: trafny wydźwięk 55% → 90%, czas 2.9s → 0.95s
- ⏳ Podłączenie Bielika do aplikacji Android (zastąpienie obecnego modelu)
- ⏳ Ewentualne złagodzenie nadużywania emoji w odpowiedziach modelu
