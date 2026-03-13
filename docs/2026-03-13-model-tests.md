# Testy dostępnych modeli LLM — 2026-03-13

## Podsumowanie

Przeprowadzono testy czterech lokalnych modeli pod kątem przydatności w aplikacji zagadkobot (odpowiedzi po polsku, ocena poprawności odpowiedzi użytkownika).

## Wyniki

| Model | TTFT | Jakość polszczyzny | Zachowanie | Ocena |
|---|---|---|---|---|
| Bielik-1.5B-v3.0 | ~2s | Najlepsza | Niespójne — czasem poprawna ocena, czasem ponawia zagadkę | ⭐ Rekomendowany |
| Qwen2.5-0.5B | ~780ms | — | Czyste halucynacje | ❌ Odrzucony |
| Qwen2.5-3.0B | ~5s | Słaba | — | ❌ Odrzucony |
| Qwen2.5-7B (fine-tuned) | ~7s | Błędy | Dobra technicznie (fine-tuning) | ⚠️ Fallback |

> Uwaga: Model oznaczony jako "Qwen3.5-4.0B" to prawdopodobnie Qwen2.5-7B lub podobny — wymaga weryfikacji.

## Wnioski

**Rekomendowany: Bielik-1.5B-v3.0**
- Najlepsza jakość języka polskiego spośród testowanych modeli
- Akceptowalny czas TTFT (~2s) dla przypadku użycia zagadek
- Niespójność odpowiedzi wynika prawdopodobnie z braku fine-tuningu i może być częściowo skorygowana przez ulepszenie system promptu

**Fallback: Qwen2.5-7B (fine-tuned)**
- Poprawne zachowanie dzięki fine-tuningowi
- Błędy gramatyczne / leksykalne w języku polskim
- TTFT ~7s — na granicy akceptowalności

## Iteracje promptu (2026-03-13)

### Problemy napotkane przy tuningu

**`n_ctx = 256` za małe** — crash przy dłuższym system prompcie. Zwiększono do 512 (`llama_jni.cpp`). KV cache: 8 MiB → 16 MiB, akceptowalne dla 1.5B.

**Few-shot szkodliwe dla Bielika** — model bez fine-tuningu nie uogólnia przykładów, kopiuje je dosłownie (np. "to nie to zwierzątko" przy zagadce o samolocie). Usunięto.

**Symbole ✓/✗ niezawodne** — Bielik nie rozróżniał ich niezawodnie i zawsze generował odpowiedź jak dla poprawnej. Zastąpiono słowami POPRAWNIE/BŁĘDNIE, a finalnie zrezygnowano z warunkowania w ogóle.

### Finalne podejście

Zamiast jednego promptu z warunkiem do interpretacji przez model, użyto **dwóch oddzielnych promptów** — model dostaje wprost rozkaz w trybie rozkazującym:

- Poprawna: `"Dziecko poprawnie odgadło zagadkę — odpowiedź to "X". Pochwal je!"`
- Błędna: `"Dziecko się pomyliło — myślało że "Y", ale poprawna odpowiedź to "X". Zmotywuj je do dalszej zabawy."`

System prompt uproszczono do minimum (~15 tokenów), TTFT wrócił do ~2s.

## Następne kroki

- [x] Poprawić system prompt dla Bielika: zakaz ponawiania zagadki, wyraźna instrukcja oceny odpowiedzi
- [x] Dodać przykłady few-shot do promptu — **odrzucone**, szkodliwe dla Bielika
