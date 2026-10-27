# shellcheck disable=SC2034
# sourced by other scripts; do not execute.
QROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK="${NDK:-${ANDROID_NDK:-}}"
PYTHON="${PYTHON:-python3}"
LLAMA="${LLAMA:-$QROOT/third_party/llama.cpp}"
MODEL_Q4="$QROOT/models/Qwen3-0.6B-Q4_0.gguf"
MODEL_Q41="$QROOT/models/Qwen3-0.6B-Q4_1.gguf"
LLAMA_COMMIT="d77256999f211f8c0a5b12d13564f48d685b59e7"
ANDROID_ABI="${ANDROID_ABI:-armeabi-v7a}"
ANDROID_API="${ANDROID_API:-24}"
REMOTE_DIR="/data/local/tmp/qwen"
