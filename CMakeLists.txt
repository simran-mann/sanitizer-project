cmake_minimum_required(VERSION 3.16)
project(SanitizerPlugin VERSION 1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ── Locate LLVM ───────────────────────────────────────────────────────────────
# Override the search path if needed:
#   cmake -DLLVM_DIR=/usr/lib/llvm-17/lib/cmake/llvm ..
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "LLVM CMake dir : ${LLVM_CMAKE_DIR}")
message(STATUS "LLVM include   : ${LLVM_INCLUDE_DIRS}")
message(STATUS "LLVM lib dir   : ${LLVM_LIBRARY_DIRS}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFS NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFS})

# ── Pass Plugin  (SanitizerPlugin.so / .dylib) ────────────────────────────────
add_library(SanitizerPlugin MODULE
    llvm-pass/InstrumentationPass.cpp
    llvm-pass/RedundantCheckPass.cpp
    llvm-pass/PassPlugin.cpp
)

# Expose local headers (Counters.h, etc.) to the plugin sources.
target_include_directories(SanitizerPlugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/llvm-pass
)

# Match LLVM's RTTI setting; mixing causes linker errors.
if(NOT LLVM_ENABLE_RTTI)
    target_compile_options(SanitizerPlugin PRIVATE -fno-rtti)
endif()

target_compile_options(SanitizerPlugin PRIVATE
    -Wall -Wextra -Wno-unused-parameter
)

# Strip the default "lib" prefix; the plugin name must match what opt expects.
set_target_properties(SanitizerPlugin PROPERTIES PREFIX "")

# macOS uses .dylib for loadable modules.
if(APPLE)
    set_target_properties(SanitizerPlugin PROPERTIES SUFFIX ".dylib")
else()
    set_target_properties(SanitizerPlugin PROPERTIES SUFFIX ".so")
endif()

# ── Runtime library  (linked into every instrumented binary) ──────────────────
add_library(check_access_rt STATIC runtime/check_access.c)

# ── Reference (un-instrumented) benchmark executables ─────────────────────────
set(BENCHMARKS
    matrix_mult
    array_sum
    quicksort
    binary_search
    convolution
    knapsack
)

foreach(bench ${BENCHMARKS})
    add_executable(${bench}_ref benchmarks/${bench}.c)
    # Link math library for convolution (uses sqrtf / powf in some variants).
    target_link_libraries(${bench}_ref PRIVATE m)
endforeach()

# ── Installation layout (optional) ────────────────────────────────────────────
install(TARGETS SanitizerPlugin
    LIBRARY DESTINATION lib
)
install(TARGETS check_access_rt
    ARCHIVE DESTINATION lib
)
install(DIRECTORY benchmarks/ DESTINATION benchmarks)
install(DIRECTORY scripts/    DESTINATION scripts)
