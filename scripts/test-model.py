"""
Skrypt testowy: porównuje odpowiedzi modelu Bielik z oczekiwanymi odpowiedziami z datasetu.
Użycie: python scripts/test-model.py [--model PATH] [--samples N] [--seed S]
"""
import json
import random
import argparse
import re
import time
from pathlib import Path

try:
    from llama_cpp import Llama
except ImportError:
    print("Brak llama-cpp-python. Zainstaluj: pip install llama-cpp-python")
    exit(1)

# --- Konfiguracja ---
DEFAULT_MODEL = "assets/models/llm/Bielik-1.5B-v3.0-Instruct.Q4_K_M.gguf"
DATASET_FILE  = "bielik_dataset.json"
DEFAULT_N     = 20  # liczba losowych próbek

# --- Metryki ---

def tokenize_pl(text: str) -> set[str]:
    """Prosta tokenizacja: małe litery, tylko słowa."""
    return set(re.findall(r'\b\w+\b', text.lower()))

def word_overlap(expected: str, actual: str) -> float:
    """Jaccard similarity słów kluczowych."""
    a, b = tokenize_pl(expected), tokenize_pl(actual)
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)

def recall(expected: str, actual: str) -> float:
    """Ile słów z expected pojawia się w actual."""
    a, b = tokenize_pl(expected), tokenize_pl(actual)
    if not a:
        return 1.0
    return len(a & b) / len(a)

SENTIMENT_WORDS = {
    "positive": {"brawo", "super", "świetnie", "doskonale", "tak", "hurra", "udało", "gratulacje", "wspaniale"},
    "hint":     {"pomyśl", "spróbuj", "może", "zastanów", "wskazówka", "jeszcze"},
    "negative": {"nie", "błąd", "źle", "niepoprawnie"},
}

def sentiment_match(expected: str, actual: str) -> bool:
    """Sprawdza czy actual ma zbliżony 'wydźwięk' co expected."""
    def classify(text):
        words = tokenize_pl(text)
        for label, vocab in SENTIMENT_WORDS.items():
            if words & vocab:
                return label
        return "neutral"
    return classify(expected) == classify(actual)

def emoji_count(text: str) -> int:
    # Prosta heurystyka: znaki spoza ASCII z zakresu emoji
    return sum(1 for c in text if ord(c) > 0x1F300)

# --- Formatowanie promptu (ChatML — jak w llama_jni.cpp) ---

def build_prompt(system: str, user: str) -> list[dict]:
    return [
        {"role": "system", "content": system},
        {"role": "user",   "content": user},
    ]

# --- Główna logika ---

def run_tests(model_path: str, n_samples: int, seed: int):
    print(f"Model:   {model_path}")
    print(f"Dataset: {DATASET_FILE}")
    print(f"Próbki:  {n_samples} (seed={seed})\n")

    with open(DATASET_FILE, encoding="utf-8") as f:
        dataset = json.load(f)

    random.seed(seed)
    samples = random.sample(dataset, min(n_samples, len(dataset)))

    print("Ładowanie modelu...", flush=True)
    llm = Llama(
        model_path=model_path,
        n_ctx=512,
        n_threads=4,
        verbose=False,
    )
    print("Model załadowany.\n")
    print("=" * 70)

    results = []

    for i, entry in enumerate(samples, 1):
        msgs = entry["messages"]
        system_msg   = next(m["content"] for m in msgs if m["role"] == "system")
        user_msg     = next(m["content"] for m in msgs if m["role"] == "user")
        expected_out = next(m["content"] for m in msgs if m["role"] == "assistant")

        t0 = time.time()
        response = llm.create_chat_completion(
            messages=build_prompt(system_msg, user_msg),
            max_tokens=128,
            temperature=0.7,
            top_p=0.9,
            stop=["<|im_end|>", "<|im_start|>"],
        )
        elapsed = time.time() - t0
        actual_out = response["choices"][0]["message"]["content"].strip()

        overlap  = word_overlap(expected_out, actual_out)
        rec      = recall(expected_out, actual_out)
        sent_ok  = sentiment_match(expected_out, actual_out)
        e_emojis = emoji_count(expected_out)
        a_emojis = emoji_count(actual_out)
        e_len    = len(expected_out.split())
        a_len    = len(actual_out.split())

        results.append({
            "overlap":  overlap,
            "recall":   rec,
            "sent_ok":  sent_ok,
            "e_emojis": e_emojis,
            "a_emojis": a_emojis,
            "elapsed":  elapsed,
        })

        print(f"[{i:2}/{n_samples}] USER:     {user_msg[:80]}")
        print(f"         EXPECTED: {expected_out}")
        print(f"         ACTUAL:   {actual_out}")
        print(f"         overlap={overlap:.2f}  recall={rec:.2f}  "
              f"sent={'✓' if sent_ok else '✗'}  "
              f"emoji(e={e_emojis}/a={a_emojis})  "
              f"słowa(e={e_len}/a={a_len})  "
              f"czas={elapsed:.1f}s")
        print()

    # Podsumowanie
    print("=" * 70)
    print("PODSUMOWANIE")
    print(f"  Śr. Jaccard overlap:  {sum(r['overlap'] for r in results)/len(results):.3f}")
    print(f"  Śr. recall:           {sum(r['recall']  for r in results)/len(results):.3f}")
    print(f"  Trafny wydźwięk:      {sum(r['sent_ok'] for r in results)}/{len(results)}")
    print(f"  Śr. emoji expected:   {sum(r['e_emojis'] for r in results)/len(results):.1f}")
    print(f"  Śr. emoji actual:     {sum(r['a_emojis'] for r in results)/len(results):.1f}")
    print(f"  Śr. czas odpowiedzi:  {sum(r['elapsed'] for r in results)/len(results):.1f}s")

    # Zapis wyników do pliku
    out_file = Path("scripts/test-results.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump({
            "model": model_path,
            "n_samples": n_samples,
            "seed": seed,
            "summary": {
                "avg_overlap": sum(r['overlap'] for r in results)/len(results),
                "avg_recall":  sum(r['recall']  for r in results)/len(results),
                "sentiment_ok": sum(r['sent_ok'] for r in results),
                "avg_time":    sum(r['elapsed']  for r in results)/len(results),
            },
            "results": results,
        }, f, ensure_ascii=False, indent=2)
    print(f"\nWyniki zapisane → {out_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test modelu Bielik vs dataset")
    parser.add_argument("--model",   default=DEFAULT_MODEL, help="Ścieżka do pliku .gguf")
    parser.add_argument("--samples", type=int, default=DEFAULT_N, help="Liczba próbek")
    parser.add_argument("--seed",    type=int, default=42,        help="Seed losowości")
    args = parser.parse_args()

    run_tests(args.model, args.samples, args.seed)
