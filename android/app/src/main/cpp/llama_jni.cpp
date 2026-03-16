#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>

/// Konwertuje standardowy UTF-8 (z llama.cpp) na UTF-16 (jchar[]) wymagany przez
/// env->NewString(). NewStringUTF() oczekuje Modified UTF-8 i nie obsługuje
/// 4-bajtowych sekwencji (emoji, znaki CJK powyżej BMP) — stąd "śmieci" na ekranie.
static std::u16string utf8ToUtf16(const char* utf8, int len) {
    std::u16string result;
    result.reserve(len);
    const uint8_t* p = reinterpret_cast<const uint8_t*>(utf8);
    const uint8_t* end = p + len;
    while (p < end) {
        uint32_t cp;
        uint8_t c = *p;
        if (c < 0x80) {
            cp = c; p += 1;
        } else if ((c & 0xE0) == 0xC0 && p + 1 < end) {
            cp = (c & 0x1F) << 6 | (p[1] & 0x3F); p += 2;
        } else if ((c & 0xF0) == 0xE0 && p + 2 < end) {
            cp = (c & 0x0F) << 12 | (p[1] & 0x3F) << 6 | (p[2] & 0x3F); p += 3;
        } else if ((c & 0xF8) == 0xF0 && p + 3 < end) {
            cp = (c & 0x07) << 18 | (p[1] & 0x3F) << 12 | (p[2] & 0x3F) << 6 | (p[3] & 0x3F);
            p += 4;
        } else {
            p += 1; continue;  // nieprawidłowy bajt
        }
        if (cp < 0x10000) {
            result.push_back(static_cast<char16_t>(cp));
        } else {
            // surrogate pair dla U+10000 i wyżej
            cp -= 0x10000;
            result.push_back(static_cast<char16_t>(0xD800 | (cp >> 10)));
            result.push_back(static_cast<char16_t>(0xDC00 | (cp & 0x3FF)));
        }
    }
    return result;
}

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

static void llama_log_callback(ggml_log_level level, const char* text, void*) {
    int prio = (level == GGML_LOG_LEVEL_ERROR) ? ANDROID_LOG_ERROR :
               (level == GGML_LOG_LEVEL_WARN)  ? ANDROID_LOG_WARN  : ANDROID_LOG_DEBUG;
    __android_log_print(prio, "llama.cpp", "%s", text);
}

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

    // Przekieruj logi llama.cpp do Android logcat
    llama_log_set(llama_log_callback, nullptr);

    // Inicjalizacja llama backend
    llama_backend_init();

    // Parametry modelu
    llama_model_params model_params = llama_model_default_params();
    // Vulkan/Adreno 830: n_gpu_layers > 0 powoduje błędy (DEVICE_LOST lub garbage output).
    // Znany problem sterownika Qualcomm Vulkan z ggml. Zostawić 0 do czasu naprawy w llama.cpp.

    llama_model* model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(modelPath, path);

    if (!model) {
        LOGE("Nie udało się załadować modelu");
        return 0;
    }

    // Parametry kontekstu
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 8192;
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

    // Repetition penalty — zapobiega zapętlaniu się modelu
    // Musi być pierwszym w łańcuchu, żeby działał na pełnych logitach.
    llama_sampler_chain_add(wrapper->sampler,
        llama_sampler_init_penalties(/*last_n=*/64, /*repeat=*/1.2f, /*freq=*/0.0f, /*present=*/0.0f));

    // Grammar-constrained decoding: zabrania tylko dwukropka,
    // co eliminuje meta-prefiksy w stylu "Jasne, tu odpowiedź: ...".
    // Nowe linie są dozwolone — model kończy odpowiedź przez \n + EOG (tak był trenowany).
    const char* grammar_str = "root ::= [^:]+";
    llama_sampler_chain_add(wrapper->sampler,
        llama_sampler_init_grammar(llama_model_get_vocab(wrapper->model), grammar_str, "root"));

    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(wrapper->sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    // Budujemy pełny prompt używając szablonu chatu z metadanych modelu.
    // llama_model_chat_template() odczytuje szablon Jinja zapisany w pliku GGUF,
    // co zapewnia poprawny format dla każdego modelu (Bielik, Qwen, Llama itp.).
    llama_chat_message messages[2];
    messages[0] = {"system", systemPrompt};
    messages[1] = {"user",   prompt};

    const char* tmpl = llama_model_chat_template(wrapper->model, nullptr);

    // Pierwsze wywołanie z buf=nullptr zwraca wymaganą długość bufora.
    int32_t needed = llama_chat_apply_template(tmpl, messages, 2, /*add_ass=*/true, nullptr, 0);

    std::string fullPrompt;
    if (needed > 0) {
        std::vector<char> buf(needed + 1, '\0');
        llama_chat_apply_template(tmpl, messages, 2, true, buf.data(), needed + 1);
        fullPrompt = std::string(buf.data(), needed);
        LOGI("Chat template zastosowany (%d znaków)", needed);
    } else {
        // Fallback do ChatML gdy model nie ma szablonu lub jest nieobsługiwany.
        LOGE("Nie udało się zastosować szablonu chatu (kod=%d), fallback do ChatML", needed);
        fullPrompt =
            "<|im_start|>system\n" + std::string(systemPrompt) + "<|im_end|>\n"
            "<|im_start|>user\n" + std::string(prompt) + "<|im_end|>\n"
            "<|im_start|>assistant\n";
    }

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
    llama_memory_clear(llama_get_memory(wrapper->ctx), false);

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

        // Bielik kończy odpowiedź przez \n + EOG — stop przy pierwszym \n
        // (bez tego model może wygenerować losowe słowo po \n, przed EOG).
        std::string tokenStr(tokenBuf, n);
        bool endsWithNewline = (tokenStr.find('\n') != std::string::npos);
        if (endsWithNewline) {
            // Wyślij tylko część przed \n (jeśli jest)
            auto nl = tokenStr.find('\n');
            tokenStr = tokenStr.substr(0, nl);
        }

        std::u16string utf16 = utf8ToUtf16(tokenStr.c_str(), tokenStr.size());
        jstring jToken = env->NewString(reinterpret_cast<const jchar*>(utf16.data()), utf16.size());

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

        if (endsWithNewline) {
            LOGI("Newline po %d tokenach — koniec odpowiedzi", i);
            break;
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
