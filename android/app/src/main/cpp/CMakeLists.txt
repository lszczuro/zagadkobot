cmake_minimum_required(VERSION 3.22)
project(llama_jni)

# llama.cpp — ścieżka do submodule lub prebuilt
# Ustaw LLAMA_CPP_DIR na katalog z kodem źródłowym llama.cpp
set(LLAMA_CPP_DIR "${CMAKE_SOURCE_DIR}/llama.cpp" CACHE PATH "Ścieżka do llama.cpp")

# Konfiguracja llama.cpp
set(LLAMA_STATIC ON CACHE BOOL "" FORCE)
set(LLAMA_NATIVE OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_CPP_DIR} llama.cpp)

# Nasza biblioteka JNI
add_library(llama_jni SHARED llama_jni.cpp)

target_include_directories(llama_jni PRIVATE
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
)

target_link_libraries(llama_jni
    llama
    ggml
    android
    log
)
