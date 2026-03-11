package com.example.zagadkobot.llama

import android.util.Log

/**
 * JNI wrapper wokół llama.cpp.
 *
 * Ładuje natywną bibliotekę `libllama_jni.so` i udostępnia metody
 * do inicjalizacji modelu, generowania tokenów i zwalniania zasobów.
 *
 * Wszystkie metody natywne obsługują OOM po stronie C++ —
 * zamiast crashować, zwracają kod błędu lub rzucają wyjątek Java.
 */
class LlamaCpp {
    companion object {
        private const val TAG = "LlamaCpp"

        init {
            try {
                System.loadLibrary("llama_jni")
                Log.i(TAG, "libllama_jni.so załadowane pomyślnie")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Nie udało się załadować libllama_jni.so", e)
            }
        }
    }

    /**
     * Wskaźnik na natywny kontekst llama (llama_context*).
     * 0 oznacza brak zainicjalizowanego kontekstu.
     */
    private var nativeContextPtr: Long = 0

    val isLoaded: Boolean get() = nativeContextPtr != 0L

    /**
     * Ładuje model GGUF i inicjalizuje kontekst z podanymi parametrami.
     *
     * @param modelPath ścieżka do pliku .gguf
     * @param nThreads liczba wątków inference
     * @return true jeśli sukces, false przy błędzie (np. OOM, plik nie istnieje)
     */
    fun loadModel(modelPath: String, nThreads: Int): Boolean {
        if (isLoaded) {
            Log.w(TAG, "Model jest już załadowany, najpierw wywołaj unloadModel()")
            return false
        }
        return try {
            nativeContextPtr = nativeLoadModel(modelPath, nThreads)
            if (nativeContextPtr == 0L) {
                Log.e(TAG, "nativeLoadModel zwrócił null pointer")
                false
            } else {
                true
            }
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "OOM podczas ładowania modelu", e)
            nativeContextPtr = 0
            false
        } catch (e: Exception) {
            Log.e(TAG, "Błąd ładowania modelu", e)
            nativeContextPtr = 0
            false
        }
    }

    /**
     * Generuje tokeny na podstawie promptu.
     * Wywołuje [onToken] dla każdego wygenerowanego tokenu.
     *
     * @param prompt tekst wejściowy
     * @param systemPrompt system prompt (prepended do kontekstu)
     * @param maxTokens maks. liczba tokenów do wygenerowania
     * @param temperature temperatura samplowania
     * @param topP top-p (nucleus sampling)
     * @param onToken callback wywoływany dla każdego tokenu; zwróć false aby przerwać
     * @return true jeśli generowanie zakończyło się poprawnie
     */
    fun generate(
        prompt: String,
        systemPrompt: String,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        onToken: (String) -> Boolean,
    ): Boolean {
        if (!isLoaded) {
            Log.e(TAG, "Model nie jest załadowany")
            return false
        }
        return try {
            nativeGenerate(
                nativeContextPtr,
                prompt,
                systemPrompt,
                maxTokens,
                temperature,
                topP,
                onToken,
            )
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "OOM podczas generowania", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Błąd generowania", e)
            false
        }
    }

    /**
     * Zwalnia natywne zasoby (kontekst + model).
     */
    fun unloadModel() {
        if (isLoaded) {
            nativeFreeModel(nativeContextPtr)
            nativeContextPtr = 0
        }
    }

    // --- Metody JNI ---

    private external fun nativeLoadModel(modelPath: String, nThreads: Int): Long
    private external fun nativeGenerate(
        contextPtr: Long,
        prompt: String,
        systemPrompt: String,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        onToken: (String) -> Boolean,
    ): Boolean
    private external fun nativeFreeModel(contextPtr: Long)
}
