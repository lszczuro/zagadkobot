# llama.cpp JNI bridge — nie obfuskuj klas natywnych
-keep class com.example.zagadkobot.llama.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# JNA — brakujące klasy AWT (niedostępne na Androidzie)
-dontwarn java.awt.Component
-dontwarn java.awt.GraphicsEnvironment
-dontwarn java.awt.HeadlessException
-dontwarn java.awt.Window
