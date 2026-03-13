# Notatnik Projektu — Zagadkobot - 2026-03-13

## 🎯 Cel dnia

Próba włączenia akceleracji GPU (Vulkan) dla llama.cpp na Samsung S25+ (Snapdragon 8 Elite / Adreno 830) w celu skrócenia TTFT z ~7 s do ~1–2 s.

---

## 📅 Dziennik

### 13.03.2026 — Próba Vulkan GPU offloading

**Co robiłem:**

1. **Włączono `n_gpu_layers = 99`** w `llama_jni.cpp` — parametr kierujący wszystkie warstwy modelu na GPU przez backend Vulkan.

2. **Włączono backend Vulkan w CMake** (`GGML_VULKAN ON`) i podłączono bibliotekę `vulkan` w `target_link_libraries`.

3. **Testy na urządzeniu — Qwen3.5-4B (model docelowy, fine-tuned):**
   - Vulkan inicjalizuje się poprawnie, wszystkie 32 warstwy przypisane do Vulkan0
   - Model generuje chiński tekst zamiast polskich komentarzy

4. **Testy na urządzeniu — Qwen2.5-3B (czysty transformer, bez fine-tune):**
   - Architektura `qwen2` — czysty transformer, bez SSM ✓
   - `n_gpu_layers = 99` → crash: `vk::DeviceLostError: vk::Queue::submit: ErrorDeviceLost` podczas pierwszego `llama_decode()`
   - `n_gpu_layers = 20` (częściowy offload) → brak crashu, ale model produkuje zapętlone odpowiedzi („gó gó gó gó…")

**Wyniki:**

| Konfiguracja | Wynik |
|---|---|
| CPU only, Qwen3.5-4B, n_threads=4 | Działa poprawnie, TTFT ~7 s |
| Vulkan, Qwen3.5-4B, n_gpu_layers=99 | Chiński tekst (błędy SSM shaderów) |
| Vulkan, Qwen2.5-3B, n_gpu_layers=99 | Crash `VK_ERROR_DEVICE_LOST` |
| Vulkan, Qwen2.5-3B, n_gpu_layers=20 | Zapętlone odpowiedzi (garbage) |

**Wniosek:** Sterownik Vulkan Qualcomm (Adreno 830) ma fundamentalne błędy z backendem ggml-vulkan. Problem dotyczy zarówno:
- Shaderów SSM (architektura Qwen3.5)
- Shaderów matmul Q4_K dla czystych transformerów (Qwen2.5)

---

## 🏁 Stan na koniec dnia

- ✅ Build z Vulkanem kompiluje się
- ✅ Vulkan SDK zainstalowany i skonfigurowany w cmake
- ❌ GPU offloading nie działa na Adreno 830 z żadną testowaną konfiguracją