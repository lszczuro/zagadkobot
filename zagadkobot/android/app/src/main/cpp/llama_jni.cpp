#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>

#include "llama.h"

#define TAG "llama_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// Struktura przechowująca kontekst llama
struct LlamaContext {
    llama_model* model;
    llama_context* ctx;
    llama_sampler* sampler;
    int n_threads;
};

extern "C" {

/**
 * Ładuje model GGUF i tworzy kontekst.
 * Zwraca pointer do LlamaContext (jako jlong) lub 0 przy błędzie.
 */
JNIEXPORT jlong JNICALL
Java_com_example_zagadkobot_llama_LlamaCpp_nativeLoadModel(
    JNIEnv* env,
    jobject /* this */,
    jstring modelPath,
    jint nThreads
) {
    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    if (!path) {
        LOGE("Nie udało się pobrać ścieżki modelu");
        return 0;
    }

    LOGI("Ładowanie modelu: %s (threads=%d)", path, nThreads);

    // Inicjalizacja llama backend
    llama_backend_init();

    // Parametry modelu
    llama_model_params model_params = llama_model_default_params();

    llama_model* model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(modelPath, path);

    if (!model) {
        LOGE("Nie udało się załadować modelu");
        return 0;
    }

    // Parametry kontekstu
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 256;
    ctx_params.n_threads = nThreads;
    ctx_params.n_threads_batch = nThreads;

    llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        LOGE("Nie udało się utworzyć kontekstu");
        llama_model_free(model);
        return 0;
    }

    // Sampler
    llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    auto* wrapper = new(std::nothrow) LlamaContext{model, ctx, sampler, nThreads};
    if (!wrapper) {
        LOGE("OOM: nie udało się zaalokować LlamaContext");
        llama_sampler_free(sampler);
        llama_free(ctx);
        llama_model_free(model);
        return 0;
    }

    LOGI("Model załadowany pomyślnie");
    return reinterpret_cast<jlong>(wrapper);
}

/**
 * Generuje tokeny i wywołuje callback Kotlin dla każdego tokenu.
 * onToken(String) -> Boolean: false = przerwij generowanie.
 */
JNIEXPORT jboolean JNICALL
Java_com_example_zagadkobot_llama_LlamaCpp_nativeGenerate(
    JNIEnv* env,
    jobject /* this */,
    jlong contextPtr,
    jstring jPrompt,
    jstring jSystemPrompt,
    jint maxTokens,
    jfloat temperature,
    jfloat topP,
    jobject onTokenCallback
) {
    if (contextPtr == 0) {
        LOGE("contextPtr == 0");
        return JNI_FALSE;
    }

    auto* wrapper = reinterpret_cast<LlamaContext*>(contextPtr);

    const char* prompt = env->GetStringUTFChars(jPrompt, nullptr);
    const char* systemPrompt = env->GetStringUTFChars(jSystemPrompt, nullptr);

    if (!prompt || !systemPrompt) {
        LOGE("Nie udało się pobrać stringów");
        if (prompt) env->ReleaseStringUTFChars(jPrompt, prompt);
        if (systemPrompt) env->ReleaseStringUTFChars(jSystemPrompt, systemPrompt);
        return JNI_FALSE;
    }

    // Aktualizacja parametrów samplera
    llama_sampler_free(wrapper->sampler);
    wrapper->sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    // Budujemy pełny prompt w formacie ChatML (Qwen2.5)
    // "RIDDLE:" priming forces the model to start generating the riddle directly
    std::string fullPrompt =
        "<|im_start|>system\n" + std::string(systemPrompt) + "<|im_end|>\n"
        "<|im_start|>user\n" + std::string(prompt) + "<|im_end|>\n"
        "<|im_start|>assistant\n";

    env->ReleaseStringUTFChars(jPrompt, prompt);
    env->ReleaseStringUTFChars(jSystemPrompt, systemPrompt);

    // Tokenizacja
    const llama_vocab* vocab = llama_model_get_vocab(wrapper->model);
    const int n_prompt_max = fullPrompt.length() + 128;
    std::vector<llama_token> tokens(n_prompt_max);
    const int n_tokens = llama_tokenize(
        vocab,
        fullPrompt.c_str(),
        fullPrompt.length(),
        tokens.data(),
        n_prompt_max,
        true,  // add_special
        true   // parse_special
    );

    if (n_tokens < 0) {
        LOGE("Tokenizacja nie powiodła się: %d", n_tokens);
        return JNI_FALSE;
    }
    tokens.resize(n_tokens);

    // Reset KV cache
    llama_kv_cache_clear(wrapper->ctx);

    // Przetwarzanie promptu (prefill)
    llama_batch batch = llama_batch_get_one(tokens.data(), n_tokens);
    if (llama_decode(wrapper->ctx, batch) != 0) {
        LOGE("Nie udało się zdekodować promptu");
        return JNI_FALSE;
    }

    // Pobranie klasy callback
    jclass callbackClass = env->GetObjectClass(onTokenCallback);
    jmethodID invokeMethod = env->GetMethodID(
        callbackClass, "invoke", "(Ljava/lang/Object;)Ljava/lang/Object;"
    );

    if (!invokeMethod) {
        LOGE("Nie znaleziono metody invoke na callbacku");
        return JNI_FALSE;
    }

    // Generowanie tokenów
    char tokenBuf[128];
    for (int i = 0; i < maxTokens; i++) {
        llama_token newToken = llama_sampler_sample(wrapper->sampler, wrapper->ctx, -1);

        // Sprawdź czy to token końca
        if (llama_vocab_is_eog(vocab, newToken)) {
            LOGI("EOG po %d tokenach", i);
            break;
        }

        // Konwersja tokenu na tekst
        int n = llama_token_to_piece(vocab, newToken, tokenBuf, sizeof(tokenBuf), 0, true);
        if (n < 0) {
            LOGE("Konwersja tokenu %d nie powiodła się", newToken);
            continue;
        }

        std::string tokenStr(tokenBuf, n);
        jstring jToken = env->NewStringUTF(tokenStr.c_str());

        // Wywołaj callback: onToken(token) -> Boolean
        jobject resultObj = env->CallObjectMethod(onTokenCallback, invokeMethod, jToken);
        env->DeleteLocalRef(jToken);

        if (env->ExceptionCheck()) {
            LOGE("Wyjątek w callbacku");
            env->ExceptionClear();
            return JNI_FALSE;
        }

        // Sprawdź czy callback zwrócił false (przerwij)
        if (resultObj != nullptr) {
            jclass boolClass = env->FindClass("java/lang/Boolean");
            jmethodID boolValue = env->GetMethodID(boolClass, "booleanValue", "()Z");
            jboolean shouldContinue = env->CallBooleanMethod(resultObj, boolValue);
            env->DeleteLocalRef(resultObj);
            env->DeleteLocalRef(boolClass);

            if (!shouldContinue) {
                LOGI("Generowanie przerwane przez callback po %d tokenach", i);
                return JNI_TRUE;
            }
        }

        // Dekoduj nowy token
        llama_batch singleBatch = llama_batch_get_one(&newToken, 1);
        if (llama_decode(wrapper->ctx, singleBatch) != 0) {
            LOGE("Błąd dekodowania tokenu %d", i);
            return JNI_FALSE;
        }

        llama_sampler_accept(wrapper->sampler, newToken);
    }

    return JNI_TRUE;
}

/**
 * Zwalnia model i kontekst.
 */
JNIEXPORT void JNICALL
Java_com_example_zagadkobot_llama_LlamaCpp_nativeFreeModel(
    JNIEnv* /* env */,
    jobject /* this */,
    jlong contextPtr
) {
    if (contextPtr == 0) return;

    auto* wrapper = reinterpret_cast<LlamaContext*>(contextPtr);
    LOGI("Zwalnianie modelu");

    if (wrapper->sampler) llama_sampler_free(wrapper->sampler);
    if (wrapper->ctx) llama_free(wrapper->ctx);
    if (wrapper->model) llama_model_free(wrapper->model);

    delete wrapper;
    llama_backend_free();
}

} // extern "C"
