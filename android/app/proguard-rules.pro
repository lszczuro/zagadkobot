# llama.cpp JNI bridge — nie obfuskuj klas natywnych
-keep class com.example.zagadkobot.llama.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }
