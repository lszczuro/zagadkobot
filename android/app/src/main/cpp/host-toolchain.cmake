# Host toolchain for building vulkan-shaders-gen on Windows.
# Uses system LLVM (not NDK clang which targets Android, not Windows).
set(CMAKE_C_COMPILER   "C:/Program Files/LLVM/bin/clang.exe")
set(CMAKE_CXX_COMPILER "C:/Program Files/LLVM/bin/clang++.exe")
set(CMAKE_BUILD_TYPE   Release)
set(CMAKE_C_FLAGS      "-O2")
set(CMAKE_CXX_FLAGS    "-O2")
set(CMAKE_RC_COMPILER   "C:/Program Files/LLVM/bin/llvm-rc.exe")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)
