#!/usr/bin/env bash
# CPU-only llama-bench for review remeasure (no OpenCL init).
#   ./scripts/build_android_cpu.sh v7
#   ./scripts/build_android_cpu.sh a53
#   ./scripts/build_android_cpu.sh a53nofma   # A53 ISA + -ffp-contract=off
#   ./scripts/build_android_cpu.sh both
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

if [[ ! -d "$NDK" ]]; then
  echo "ERROR: NDK not found: $NDK" >&2
  exit 1
fi

VARIANT="${1:-both}"
NDK_CLANG="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
NDK_CLANGXX="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
STRIP="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
TARGET="armv7-none-linux-androideabi${ANDROID_API}"

# unicode-data.cpp at -O3+A53 or even -O3 armv7 can take >10 min; -O0 is ~5s.
compile_unicode_o0() {
  local BUILD="$1"
  local OBJ="$BUILD/src/CMakeFiles/llama.dir/unicode-data.cpp.o"
  mkdir -p "$(dirname "$OBJ")"
  echo "precompile unicode-data.cpp -O0 -> $OBJ"
  "$NDK_CLANGXX" --target="$TARGET" --sysroot="$SYSROOT" \
    -DGGML_USE_CPU \
    -I"$LLAMA/src/." -I"$BUILD/src" -I"$LLAMA/include" -I"$LLAMA/ggml/include" \
    -DANDROID -fdata-sections -ffunction-sections -funwind-tables \
    -no-canonical-prefixes -march=armv7-a -mthumb -O0 -DNDEBUG -fPIC \
    -o "$OBJ" -c "$LLAMA/src/unicode-data.cpp"
}

build_one() {
  local name="$1"
  local BUILD="$QROOT/build-android-cpu-$name"
  mkdir -p "$BUILD"

  local extra=()
  case "$name" in
    a53)
      extra+=(-DGGML_CPU_ARM_ARCH=armv8-a)
      ;;
    a53nofma)
      extra+=(-DGGML_CPU_ARM_ARCH=armv8-a -DGGML_CPU_FP_CONTRACT_OFF=ON)
      ;;
  esac

  cmake -S "$LLAMA" -B "$BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="android-$ANDROID_API" \
    -DANDROID_ARM_NEON=ON \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DPython3_EXECUTABLE="$PYTHON" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_CURL=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_LLAMAFILE=OFF \
    -DGGML_OPENCL=OFF \
    -DCMAKE_UNITY_BUILD=OFF \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_CXX_FLAGS="-Wno-c++11-narrowing" \
    "${extra[@]}"

  compile_unicode_o0 "$BUILD"
  cmake --build "$BUILD" -j"$(nproc)" --target llama-bench

  mkdir -p "$QROOT/out" "$QROOT/board_payload/bin"
  local dest="$QROOT/out/llama-bench-$name"
  cp -f "$BUILD/bin/llama-bench" "$dest"
  if [[ -x "$STRIP" ]]; then
    "$STRIP" "$dest"
  fi
  cp -f "$dest" "$QROOT/board_payload/bin/llama-bench-$name"
  echo "OK: $dest"
  file "$dest"
  readelf -A "$dest" | grep -E "Tag_CPU|NEON|FP_arch" || true
}

case "$VARIANT" in
  v7) build_one v7 ;;
  a53) build_one a53 ;;
  a53nofma) build_one a53nofma ;;
  both) build_one v7; build_one a53 ;;
  *) echo "usage: $0 [v7|a53|a53nofma|both]"; exit 1 ;;
esac
