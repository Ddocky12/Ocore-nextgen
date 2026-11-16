#!/usr/bin/env bash
# ==============================================================================
# Ocore Next-Gen Zygisk Native Build Script (zygisk/src/build_zygisk.sh)
# Requires Android NDK r25+ (ANDROID_NDK_HOME or NDK_ROOT)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NDK_DIR="${ANDROID_NDK_HOME:-${NDK_ROOT:-}}"

if [ -z "$NDK_DIR" ] || [ ! -d "$NDK_DIR" ]; then
  echo "[ERROR] ANDROID_NDK_HOME is not set or directory does not exist."
  echo "Usage: ANDROID_NDK_HOME=/path/to/android-ndk ./build_zygisk.sh"
  exit 1
fi

CLANGXX="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang++"
if [ ! -x "$CLANGXX" ]; then
  CLANGXX="$(find "$NDK_DIR/toolchains/llvm/prebuilt" -name "aarch64-linux-android29-clang++" | head -n 1)"
fi

if [ -z "$CLANGXX" ] || [ ! -x "$CLANGXX" ]; then
  echo "[ERROR] Could not locate aarch64-linux-android29-clang++ in $NDK_DIR"
  exit 1
fi

OUT_SO="$SCRIPT_DIR/../arm64-v8a.so"
echo "[INFO] Compiling ocore_zygisk.cpp -> $OUT_SO ..."
"$CLANGXX" -shared -fPIC -std=c++17 -O2 -fvisibility=hidden   -Wall -Wextra "$SCRIPT_DIR/ocore_zygisk.cpp"   -llog -static-libstdc++ -o "$OUT_SO"

echo "[OK] Successfully built $OUT_SO"
